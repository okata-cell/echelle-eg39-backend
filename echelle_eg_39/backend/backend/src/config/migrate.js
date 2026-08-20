const pool = require('./database');
const bcrypt = require('bcryptjs');

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
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

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
          CHECK (statut IN ('en_attente', 'approuvee', 'rejetee', 'en_cours', 'termine', 'en_retard')),
        commentaire_admin TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Mise à niveau idempotente des bases déjà existantes.
    await client.query(
      'ALTER TABLE locations ADD COLUMN IF NOT EXISTS commentaire_admin TEXT',
    );
    await client.query('ALTER TABLE locations DROP CONSTRAINT IF EXISTS locations_statut_check');
    await client.query(`
      ALTER TABLE locations ADD CONSTRAINT locations_statut_check
      CHECK (statut IN ('en_attente', 'approuvee', 'rejetee', 'en_cours', 'termine', 'en_retard'))
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

    await client.query('CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)');
    await client.query('CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone)');
    await client.query('CREATE INDEX IF NOT EXISTS idx_appareils_code ON appareils(code)');
    await client.query('CREATE INDEX IF NOT EXISTS idx_appareils_type ON appareils(type)');
    await client.query('CREATE INDEX IF NOT EXISTS idx_demandes_statut ON demandes_achat(statut)');
    await client.query('CREATE INDEX IF NOT EXISTS idx_locations_statut ON locations(statut)');
    await client.query('CREATE INDEX IF NOT EXISTS idx_reset_codes_user ON password_reset_codes(user_id)');
    await client.query('CREATE INDEX IF NOT EXISTS idx_reset_codes_code ON password_reset_codes(code)');
    await client.query('CREATE INDEX IF NOT EXISTS idx_reset_codes_contact ON password_reset_codes(contact)');

    const adminEmail = process.env.ADMIN_EMAIL || 'admin@echelle-eg39.com';
    const adminPassword = process.env.ADMIN_PASSWORD || 'Admin123!';
    const adminPhone = process.env.ADMIN_PHONE || '+22890014329';
    const hashedPassword = await bcrypt.hash(adminPassword, 10);

    await client.query(
      `INSERT INTO users (first_name, last_name, email, phone, password_hash, role)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (email) DO NOTHING`,
      ['Admin', 'ÉCHELLE EG39', adminEmail, adminPhone, hashedPassword, 'admin'],
    );

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
        service_id VARCHAR(50),
        service_name VARCHAR(255),
        description TEXT,
        nom VARCHAR(255) NOT NULL,
        telephone VARCHAR(20),
        email VARCHAR(255),
        statut VARCHAR(20) DEFAULT 'en_attente'
          CHECK (statut IN ('en_attente', 'approuvee', 'rejetee', 'en_cours', 'envoye', 'termine')),
        commentaire_admin TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Mise à niveau idempotente des demandes de devis déjà existantes.
    await client.query(
      'ALTER TABLE devis ADD COLUMN IF NOT EXISTS commentaire_admin TEXT',
    );
    await client.query('ALTER TABLE devis DROP CONSTRAINT IF EXISTS devis_statut_check');
    await client.query(
      "UPDATE devis SET statut = 'en_attente' WHERE statut = 'nouveau'",
    );
    await client.query(`
      ALTER TABLE devis ADD CONSTRAINT devis_statut_check
      CHECK (statut IN ('en_attente', 'approuvee', 'rejetee', 'en_cours', 'envoye', 'termine'))
    `);

    await client.query('CREATE INDEX IF NOT EXISTS idx_devis_statut ON devis(statut)');
    await client.query('CREATE INDEX IF NOT EXISTS idx_devis_created_at ON devis(created_at)');

    await client.query('COMMIT');
    console.log('✅ Migration réussie');
    console.log(`📧 Compte administrateur disponible: ${adminEmail}`);
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
