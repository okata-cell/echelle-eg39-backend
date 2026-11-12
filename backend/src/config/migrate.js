const pool = require('./database');
const { ensureAdminAccount } = require('./admin_account');

async function migrate() {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    await client.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        first_name VARCHAR(100) NOT NULL,
        last_name VARCHAR(100) NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        phone VARCHAR(20) UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        role VARCHAR(20) DEFAULT 'client' CHECK (role IN ('client', 'admin')),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await client.query(
      'ALTER TABLE users ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true',
    );
    await client.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_data BYTEA');
    await client.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_mime_type VARCHAR(30)');

    // Suppression de compte : la ligne est conservée pour les pièces
    // commerciales, mais l'identité est remplacée par des valeurs neutres.
    // `deleted_at` date la suppression, les deux empreintes HMAC permettent de
    // reconnaître la personne si elle se reconnecte avec ses anciennes
    // coordonnées — sans conserver ces coordonnées.
    await client.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP');
    await client.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS deleted_email_hash TEXT');
    await client.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS deleted_phone_hash TEXT');
    await client.query(
      'CREATE INDEX IF NOT EXISTS users_deleted_email_hash_idx ON users (deleted_email_hash)',
    );
    await client.query(
      'CREATE INDEX IF NOT EXISTS users_deleted_phone_hash_idx ON users (deleted_phone_hash)',
    );

    // Mot de passe temporaire de récupération : tant que ce drapeau est vrai,
    // l'application impose de choisir un mot de passe définitif après la
    // connexion.
    await client.query(
      'ALTER TABLE users ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN DEFAULT FALSE',
    );

    // Code de récupération remis à l'inscription : seule son empreinte HMAC est
    // conservée. Il remplace l'envoi du code par e-mail ou SMS.
    await client.query(
      'ALTER TABLE users ADD COLUMN IF NOT EXISTS recovery_code_hash TEXT',
    );

    // Coordonnées chiffrées pour les comptes créés après cette date. Les
    // comptes existants gardent `email` et `phone` en clair : rien n'est migré
    // de force. Une nouvelle ligne laisse ces colonnes vides et s'appuie sur le
    // chiffré (lecture) et l'empreinte HMAC (recherche et unicité).
    await client.query(
      'ALTER TABLE users ADD COLUMN IF NOT EXISTS email_cipher TEXT',
    );
    await client.query(
      'ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_cipher TEXT',
    );
    await client.query(
      'ALTER TABLE users ADD COLUMN IF NOT EXISTS email_bidx TEXT',
    );
    await client.query(
      'ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_bidx TEXT',
    );
    await client.query('ALTER TABLE users ALTER COLUMN email DROP NOT NULL');
    await client.query('ALTER TABLE users ALTER COLUMN phone DROP NOT NULL');
    await client.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS users_email_bidx_idx
        ON users (email_bidx) WHERE email_bidx IS NOT NULL
    `);
    await client.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS users_phone_bidx_idx
        ON users (phone_bidx) WHERE phone_bidx IS NOT NULL
    `);

    // Unicité de l'e-mail insensible à la casse : la contrainte UNIQUE de la
    // colonne, elle, distingue « Client@X.com » de « client@x.com ». Les
    // comptes existants sont conservés tels quels : si des doublons hérités
    // existent déjà, l'index n'est pas créé et un avertissement le signale.
    const emailsEnDouble = await client.query(`
      SELECT LOWER(email) AS email
        FROM users
       GROUP BY LOWER(email)
      HAVING COUNT(*) > 1
       LIMIT 5
    `);

    if (emailsEnDouble.rows.length === 0) {
      await client.query(
        'CREATE UNIQUE INDEX IF NOT EXISTS users_email_lower_idx ON users (LOWER(email))',
      );
    } else {
      console.warn(
        '⚠️ Unicité e-mail insensible à la casse non appliquée : doublons hérités',
        emailsEnDouble.rows.map((ligne) => ligne.email).join(', '),
      );
    }

    await client.query(`
      CREATE TABLE IF NOT EXISTS appareils (
        id SERIAL PRIMARY KEY,
        code VARCHAR(50) UNIQUE NOT NULL,
        nom VARCHAR(255) NOT NULL,
        type VARCHAR(100) NOT NULL,
        image_url TEXT,
        prix_location INTEGER NOT NULL,
        prix_vente INTEGER NOT NULL,
        disponible BOOLEAN DEFAULT true,
        hors_service BOOLEAN DEFAULT false NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Distinguish equipment serviceability from the sales availability flag.
    await client.query('ALTER TABLE appareils ADD COLUMN IF NOT EXISTS hors_service BOOLEAN');

    await client.query(`
      CREATE TABLE IF NOT EXISTS demandes_achat (
        id SERIAL PRIMARY KEY,
        code VARCHAR(50) UNIQUE NOT NULL,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        appareil_id INTEGER REFERENCES appareils(id) ON DELETE SET NULL,
        appareil_nom VARCHAR(255) NOT NULL,
        appareil_prix INTEGER NOT NULL,
        quantite INTEGER DEFAULT 1,
        total INTEGER NOT NULL,
        statut VARCHAR(20) DEFAULT 'en_attente'
          CHECK (statut IN ('en_attente', 'approuvee', 'rejetee', 'livree', 'termine')),
        commentaire_admin TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await client.query(`
      CREATE TABLE IF NOT EXISTS locations (
        id SERIAL PRIMARY KEY,
        code VARCHAR(50) UNIQUE NOT NULL,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        appareil_id INTEGER REFERENCES appareils(id) ON DELETE SET NULL,
        appareil_nom VARCHAR(255) NOT NULL,
        date_debut DATE NOT NULL,
        date_fin DATE NOT NULL,
        prix_journalier INTEGER NOT NULL,
        montant_total INTEGER NOT NULL,
        statut VARCHAR(20) DEFAULT 'en_attente'
          CHECK (statut IN ('en_attente', 'approuvee', 'rejetee', 'en_cours', 'termine', 'en_retard', 'annulee')),
        commentaire_admin TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await client.query(`
      UPDATE appareils AS a
         SET hors_service = CASE
           WHEN a.disponible = false AND EXISTS (
             SELECT 1
               FROM locations AS l
              WHERE l.appareil_id = a.id
                AND l.statut IN ('approuvee', 'en_cours', 'en_retard')
           ) THEN false
           WHEN a.disponible = false THEN true
           ELSE false
         END
       WHERE a.hors_service IS NULL
    `);
    await client.query('ALTER TABLE appareils ALTER COLUMN hors_service SET DEFAULT false');
    await client.query('ALTER TABLE appareils ALTER COLUMN hors_service SET NOT NULL');

    // Mise à niveau idempotente des bases déjà existantes.
    await client.query(
      'ALTER TABLE locations ADD COLUMN IF NOT EXISTS commentaire_admin TEXT',
    );
    await client.query('ALTER TABLE locations DROP CONSTRAINT IF EXISTS locations_statut_check');
    await client.query(`
      ALTER TABLE locations ADD CONSTRAINT locations_statut_check
      CHECK (statut IN ('en_attente', 'approuvee', 'rejetee', 'en_cours', 'termine', 'en_retard', 'annulee'))
    `);
    await client.query('ALTER TABLE demandes_achat DROP CONSTRAINT IF EXISTS demandes_achat_statut_check');
    await client.query(`
      ALTER TABLE demandes_achat ADD CONSTRAINT demandes_achat_statut_check
      CHECK (statut IN ('en_attente', 'approuvee', 'rejetee', 'livree', 'termine'))
    `);

    await client.query(`
      CREATE TABLE IF NOT EXISTS prolongations (
        id SERIAL PRIMARY KEY,
        code VARCHAR(50) UNIQUE NOT NULL,
        location_id INTEGER REFERENCES locations(id) ON DELETE CASCADE,
        ancienne_date_fin DATE NOT NULL,
        nouvelle_date_fin DATE NOT NULL,
        jours_supplementaires INTEGER NOT NULL,
        cout_supplementaire INTEGER NOT NULL,
        facture_numero VARCHAR(100) UNIQUE,
        est_paye BOOLEAN DEFAULT false,
        date_paiement TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await client.query(`
      CREATE TABLE IF NOT EXISTS clients (
        id SERIAL PRIMARY KEY,
        user_id INTEGER UNIQUE REFERENCES users(id) ON DELETE CASCADE,
        entreprise VARCHAR(255),
        adresse TEXT,
        ville VARCHAR(100),
        pays VARCHAR(100) DEFAULT 'Togo',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await client.query(`
      CREATE TABLE IF NOT EXISTS profile_support_messages (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        message TEXT NOT NULL CHECK (char_length(message) BETWEEN 1 AND 5000),
        status VARCHAR(20) NOT NULL DEFAULT 'nouveau'
          CHECK (status IN ('nouveau', 'en_traitement', 'termine', 'ferme')),
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await client.query(`
      CREATE TABLE IF NOT EXISTS support_message_attachments (
        id SERIAL PRIMARY KEY,
        support_message_id INTEGER NOT NULL REFERENCES profile_support_messages(id) ON DELETE CASCADE,
        mime_type VARCHAR(30) NOT NULL CHECK (mime_type IN ('image/jpeg', 'image/png', 'image/webp')),
        image_data BYTEA NOT NULL,
        byte_size INTEGER NOT NULL CHECK (byte_size > 0 AND byte_size <= 2097152),
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await client.query(`
      CREATE TABLE IF NOT EXISTS profile_training_interests (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        training_name VARCHAR(150) NOT NULL,
        message TEXT CHECK (message IS NULL OR char_length(message) <= 2000),
        status VARCHAR(20) NOT NULL DEFAULT 'nouveau'
          CHECK (status IN ('nouveau', 'contacte', 'inscrit', 'termine', 'annule')),
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await client.query(`
      CREATE TABLE IF NOT EXISTS profile_app_ratings (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
        rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
        comment TEXT CHECK (comment IS NULL OR char_length(comment) <= 1000),
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await client.query(`
      CREATE TABLE IF NOT EXISTS password_reset_codes (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        code VARCHAR(6) NOT NULL,
        contact VARCHAR(255) NOT NULL,
        contact_type VARCHAR(10) NOT NULL CHECK (contact_type IN ('email', 'phone')),
        expires_at TIMESTAMP NOT NULL,
        used BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await client.query(`
      CREATE TABLE IF NOT EXISTS promotions (
        id SERIAL PRIMARY KEY,
        titre VARCHAR(255) NOT NULL,
        description TEXT NOT NULL,
        image_url TEXT,
        image_storage_path TEXT,
        date_debut DATE NOT NULL,
        date_fin DATE NOT NULL,
        actif BOOLEAN DEFAULT true,
        frequence VARCHAR(50) DEFAULT 'chaque_ouverture'
          CHECK (frequence IN ('chaque_ouverture', 'une_fois_par_jour', 'une_seule_fois')),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    await client.query(
      'ALTER TABLE promotions ADD COLUMN IF NOT EXISTS image_storage_path TEXT',
    );

    // Actualités de l'accueil : rédigées par l'administrateur, publiées ou non.
    // `corps` est prévu dès maintenant pour permettre un écran de détail futur
    // sans nouvelle migration ; il n'est pas affiché sur la carte d'accueil.
    await client.query(`
      CREATE TABLE IF NOT EXISTS actualites (
        id SERIAL PRIMARY KEY,
        titre VARCHAR(80) NOT NULL,
        description VARCHAR(240) NOT NULL,
        corps TEXT,
        image_url TEXT,
        image_storage_path TEXT,
        date_publication DATE NOT NULL DEFAULT CURRENT_DATE,
        date_fin DATE,
        statut VARCHAR(12) NOT NULL DEFAULT 'brouillon'
          CHECK (statut IN ('brouillon', 'publiee')),
        epingle BOOLEAN NOT NULL DEFAULT FALSE,
        auteur VARCHAR(120),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    await client.query(
      'ALTER TABLE actualites ADD COLUMN IF NOT EXISTS corps TEXT',
    );
    await client.query(
      'ALTER TABLE actualites ADD COLUMN IF NOT EXISTS image_storage_path TEXT',
    );
    // Fin de la fenêtre de publication : l'actualité disparaît de l'accueil
    // le lendemain de cette date, sans intervention de l'administrateur.
    await client.query(
      'ALTER TABLE actualites ADD COLUMN IF NOT EXISTS date_fin DATE',
    );

    await client.query('CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)');
    await client.query('CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone)');
    await client.query('CREATE INDEX IF NOT EXISTS idx_profile_support_status_created ON profile_support_messages(status, created_at DESC)');
    await client.query('CREATE INDEX IF NOT EXISTS idx_profile_training_status_created ON profile_training_interests(status, created_at DESC)');
    await client.query('CREATE INDEX IF NOT EXISTS idx_appareils_code ON appareils(code)');
    await client.query('CREATE INDEX IF NOT EXISTS idx_appareils_type ON appareils(type)');
    await client.query('CREATE INDEX IF NOT EXISTS idx_demandes_statut ON demandes_achat(statut)');
    await client.query('CREATE INDEX IF NOT EXISTS idx_locations_statut ON locations(statut)');
    await client.query(
      'CREATE INDEX IF NOT EXISTS idx_locations_appareil_dates ON locations(appareil_id, statut, date_debut, date_fin)',
    );
    await client.query('CREATE INDEX IF NOT EXISTS idx_reset_codes_user ON password_reset_codes(user_id)');
    await client.query('CREATE INDEX IF NOT EXISTS idx_reset_codes_code ON password_reset_codes(code)');
    await client.query('CREATE INDEX IF NOT EXISTS idx_reset_codes_contact ON password_reset_codes(contact)');
    await client.query('CREATE INDEX IF NOT EXISTS idx_promotions_actif ON promotions(actif)');
    await client.query(
      'CREATE INDEX IF NOT EXISTS idx_promotions_dates ON promotions(date_debut, date_fin)',
    );
    await client.query(
      'CREATE INDEX IF NOT EXISTS idx_actualites_publication ON actualites(statut, epingle DESC, date_publication DESC)',
    );

    // Aucun mot de passe par défaut : le compte administrateur n'est créé que
    // si ADMIN_PASSWORD fournit une valeur propre à l'exploitant.
    const adminAccount = await ensureAdminAccount(client);

    const defaultAppareils = [
      ['APP-001', 'GPS e-survey E600', 'GPS', 'https://images.unsplash.com/photo-1581092334494-8b6a8c3a52f3', 25000, 2500000],
      ['APP-002', 'GPS e-survey E800', 'GPS', 'https://images.unsplash.com/photo-1590650153855-d9e808231d41', 15000, 1200000],
      ['APP-003', 'Niveau Leica', 'Niveau', 'https://images.unsplash.com/photo-1590650153855-d9e808231d41', 15000, 1200000],
      ['APP-004', 'Niveau Auto Leica', 'Niveau', 'https://images.unsplash.com/photo-1506744038136-46273834b3fb', 30000, 3500000],
      ['APP-005', 'Station Totale Leica TS06', 'Station totale', 'https://images.unsplash.com/photo-1506744038136-46273834b3fb', 30000, 3500000],
      ['APP-006', 'Station Totale Sokkia', 'Theodolite', 'https://images.unsplash.com/photo-1506744038136-46273834b3fb', 30000, 3500000],
      ['APP-007', 'GPS e-survey 3600', 'GPS', 'https://images.unsplash.com/photo-1581092334494-8b6a8c3a52f3', 25000, 2500000],
      ['APP-008', 'Trepied Leica', 'Trepied', 'https://images.unsplash.com/photo-1590650153855-d9e808231d41', 15000, 1200000],
      ['APP-009', 'Mire Stadimetrique', 'Mire', 'https://images.unsplash.com/photo-1590650153855-d9e808231d41', 15000, 1200000],
    ];

    for (const appareil of defaultAppareils) {
      await client.query(
        `INSERT INTO appareils (code, nom, type, image_url, prix_location, prix_vente)
         VALUES ($1, $2, $3, $4, $5, $6)
         ON CONFLICT (code) DO NOTHING`,
        appareil,
      );
    }

    await client.query(`
      CREATE TABLE IF NOT EXISTS devis (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
        service_id VARCHAR(50),
        service_name VARCHAR(255),
        description TEXT,
        nom VARCHAR(255) NOT NULL,
        telephone VARCHAR(20),
        email VARCHAR(255),
        statut VARCHAR(20) DEFAULT 'en_attente'
          CHECK (statut IN ('en_attente', 'en_traitement', 'approuvee', 'rejetee', 'en_cours', 'envoye', 'termine')),
        commentaire_admin TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Mise à niveau idempotente des demandes de devis déjà existantes.
    await client.query(
      'ALTER TABLE devis ADD COLUMN IF NOT EXISTS commentaire_admin TEXT',
    );
    await client.query(
      'ALTER TABLE devis ADD COLUMN IF NOT EXISTS user_id INTEGER REFERENCES users(id) ON DELETE SET NULL',
    );
    await client.query('ALTER TABLE devis ADD COLUMN IF NOT EXISTS montant BIGINT');
    await client.query('ALTER TABLE devis ADD COLUMN IF NOT EXISTS date_validite DATE');
    await client.query('ALTER TABLE devis ADD COLUMN IF NOT EXISTS document_url TEXT');
    await client.query('ALTER TABLE devis ADD COLUMN IF NOT EXISTS document_storage_key TEXT');
    await client.query('ALTER TABLE devis ADD COLUMN IF NOT EXISTS offre_emise_at TIMESTAMP');
    await client.query('ALTER TABLE devis ADD COLUMN IF NOT EXISTS client_repondu_at TIMESTAMP');
    // Rattachement rétroactif des devis anonymes à un compte existant (même email).
    await client.query(`
      UPDATE devis d
      SET user_id = u.id
      FROM users u
      WHERE d.user_id IS NULL
        AND d.email IS NOT NULL
        AND LOWER(TRIM(d.email)) = LOWER(TRIM(u.email))
    `);
    await client.query('ALTER TABLE devis DROP CONSTRAINT IF EXISTS devis_statut_check');
    await client.query(
      "UPDATE devis SET statut = 'en_attente' WHERE statut = 'nouveau'",
    );
    await client.query(`
      ALTER TABLE devis ADD CONSTRAINT devis_statut_check
      CHECK (statut IN ('en_attente', 'en_traitement', 'approuvee', 'rejetee', 'en_cours', 'envoye', 'acceptee', 'refusee', 'termine'))
    `);
    await client.query('ALTER TABLE devis DROP CONSTRAINT IF EXISTS devis_montant_check');
    await client.query(`
      ALTER TABLE devis ADD CONSTRAINT devis_montant_check
      CHECK (montant IS NULL OR montant > 0)
    `);

    await client.query('CREATE INDEX IF NOT EXISTS idx_devis_statut ON devis(statut)');
    await client.query('CREATE INDEX IF NOT EXISTS idx_devis_created_at ON devis(created_at)');
    await client.query('CREATE INDEX IF NOT EXISTS idx_devis_user_id ON devis(user_id)');

    // Journal des demandes clientes, lu par l'espace administrateur.
    // `event_key` porte la clé métier (par exemple `location:1421`) : un client
    // qui réessaie après une coupure réseau ne crée pas de seconde alerte.
    await client.query(`
      CREATE TABLE IF NOT EXISTS admin_events (
        id BIGSERIAL PRIMARY KEY,
        event_key VARCHAR(80) UNIQUE NOT NULL,
        kind VARCHAR(20) NOT NULL CHECK (kind IN ('location', 'vente', 'devis')),
        reference VARCHAR(60) NOT NULL,
        titre VARCHAR(200) NOT NULL,
        demandeur VARCHAR(160),
        montant BIGINT,
        metadata JSONB DEFAULT '{}'::jsonb,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        read_at TIMESTAMP,
        read_by INTEGER REFERENCES users(id) ON DELETE SET NULL
      )
    `);

    await client.query(
      `CREATE INDEX IF NOT EXISTS admin_events_unread_idx
         ON admin_events (created_at DESC) WHERE read_at IS NULL`,
    );
    await client.query(
      'CREATE INDEX IF NOT EXISTS admin_events_created_at_idx ON admin_events (created_at DESC)',
    );

    // Les événements acquittés depuis plus d'un mois sont oubliés : le journal
    // n'a pas vocation à conserver indéfiniment un historique de consultation.
    await client.query(
      `DELETE FROM admin_events
        WHERE read_at IS NOT NULL
          AND read_at < NOW() - INTERVAL '30 days'`,
    );

    await client.query('COMMIT');
    console.log('✅ Migration réussie');
    console.log(
      adminAccount.created
        ? `📧 Compte administrateur créé: ${adminAccount.email}`
        : `📧 Compte administrateur existant: ${adminAccount.email}`,
    );
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Erreur de migration:', error);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

migrate().catch((error) => {
  console.error('❌ Migration interrompue:', error.message);
  process.exitCode = 1;
});
