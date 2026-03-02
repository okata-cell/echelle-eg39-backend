const pool = require('./database');
const bcrypt = require('bcryptjs');

async function runMigrations({ closePool = false } = {}) {
  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');

    // Table: users (utilisateurs et admins)
    await client.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        first_name VARCHAR(100) NOT NULL,
        last_name VARCHAR(100) NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        phone VARCHAR(25) UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        role VARCHAR(20) DEFAULT 'client' CHECK (role IN ('client', 'admin')),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Mettre à jour le champ phone s'il existe déjà avec l'ancienne taille
    try {
      await client.query(`
        ALTER TABLE users ALTER COLUMN phone TYPE VARCHAR(25)
      `);
      console.log('✅ Colonne phone mise à jour vers VARCHAR(25)');
    } catch (e) {
      // Ignorer si la colonne a déjà la bonne taille ou n'existe pas
      console.log('ℹ️  Colonne phone déjà à jour ou inexistante');
    }

    // Table: appareils
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

    // Table: demandes_achat
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
        statut VARCHAR(20) DEFAULT 'en_attente' CHECK (statut IN ('en_attente', 'approuvee', 'rejetee', 'livree')),
        commentaire_admin TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Table: locations
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
        statut VARCHAR(20) DEFAULT 'en_cours' CHECK (statut IN ('en_cours', 'termine', 'en_retard')),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Table: prolongations
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

    // Table: clients (données supplémentaires pour clients)
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

    // Index pour améliorer les performances
    await client.query('CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)');
    await client.query('CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone)');
    await client.query('CREATE INDEX IF NOT EXISTS idx_appareils_code ON appareils(code)');
    await client.query('CREATE INDEX IF NOT EXISTS idx_appareils_type ON appareils(type)');
    await client.query('CREATE INDEX IF NOT EXISTS idx_demandes_statut ON demandes_achat(statut)');
    await client.query('CREATE INDEX IF NOT EXISTS idx_locations_statut ON locations(statut)');

    // Créer un admin par défaut (idempotent via ON CONFLICT)
    const adminEmail = process.env.ADMIN_EMAIL || 'admin@echelle-eg39.com';
    const adminPassword = process.env.ADMIN_PASSWORD || 'Admin123!';
    const adminPhone = process.env.ADMIN_PHONE || '+22890014329';
    const hashedPassword = await bcrypt.hash(adminPassword, 10);

    await client.query(`
      INSERT INTO users (first_name, last_name, email, phone, password_hash, role)
      VALUES ($1, $2, $3, $4, $5, $6)
      ON CONFLICT (email) DO NOTHING
    `, ['Admin', 'ÉCHELLE EG39', adminEmail, adminPhone, hashedPassword, 'admin']);

    // Insérer des appareils par défaut
    const defaultAppareils = [
      ['APP-001', 'GPS e-survey E600', 'GPS', 'https://images.unsplash.com/photo-1581092334494-8b6a8c3a52f3', 25000, 2500000],
      ['APP-002', 'GPS e-survey E800', 'GPS', 'https://images.unsplash.com/photo-1590650153855-d9e808231d41', 15000, 1200000],
      ['APP-003', 'Niveau Leica', 'Niveau', 'https://images.unsplash.com/photo-1590650153855-d9e808231d41', 15000, 1200000],
      ['APP-004', 'Niveau Auto Leica', 'Niveau', 'https://images.unsplash.com/photo-1506744038136-46273834b3fb', 30000, 3500000],
      ['APP-005', 'Station Totale Leica TS06', 'Station totale', 'https://images.unsplash.com/photo-1506744038136-46273834b3fb', 30000, 3500000],
      ['APP-006', 'Station Totale Sokkia', 'Theodolite', 'https://images.unsplash.com/photo-1506744038136-46273834b3fb', 30000, 3500000],
      ['APP-007', 'GPS e-survey 3600', 'GPS', 'https://images.unsplash.com/photo-1581092334494-8b6a8c3a52f3', 25000, 2500000],
      ['APP-008', 'Trepied Leica', 'Trepied', 'https://images.unsplash.com/photo-1590650153855-d9e808231d41', 15000, 1200000],
      ['APP-009', 'Mire Stadimetrique', 'Mire', 'https://images.unsplash.com/photo-1590650153855-d9e808231d41', 15000, 1200000]
    ];

    for (const appareil of defaultAppareils) {
      await client.query(`
        INSERT INTO appareils (code, nom, type, image_url, prix_location, prix_vente)
        VALUES ($1, $2, $3, $4, $5, $6)
        ON CONFLICT (code) DO NOTHING
      `, appareil);
    }

    await client.query('COMMIT');
    console.log('✅ Migration réussie !');
    console.log(`📧 Admin créé: ${adminEmail}`);
    console.log(`🔑 Mot de passe: ${adminPassword}`);
    
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Erreur de migration:', error);
    throw error;
  } finally {
    client.release();
    if (closePool) {
      await pool.end();
    }
  }
}

// Exécution directe (CLI) ou export pour utilisation au démarrage du serveur
if (require.main === module) {
  runMigrations({ closePool: true }).catch(console.error);
}

module.exports = { runMigrations };