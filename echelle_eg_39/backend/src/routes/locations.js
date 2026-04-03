const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const pool = require('../config/database');
const { authMiddleware, adminMiddleware } = require('../middleware/auth');
const { sendLocationApprovedEmail, sendLocationRejectedEmail } = require('../services/email_sms_service');

// Liste des locations
router.get('/', authMiddleware, async (req, res) => {
  try {
    const { statut } = req.query;
    
    let query = `
      SELECT l.*, u.first_name, u.last_name, u.email, u.phone
      FROM locations l
      JOIN users u ON l.user_id = u.id
    `;
    const params = [];

    // Admin voit tout, client voit seulement ses locations
    if (req.user.role === 'client') {
      query += ' WHERE l.user_id = $1';
      params.push(req.user.userId);
    }

    if (statut) {
      const whereClause = params.length > 0 ? 'AND' : 'WHERE';
      params.push(statut);
      query += ` ${whereClause} l.statut = $${params.length}`;
    }

    query += ' ORDER BY l.created_at DESC';

    console.log('📡 GET /locations - User role:', req.user.role, 'User ID:', req.user.userId);
    console.log('📡 Query:', query);
    console.log('📡 Params:', params);

    const result = await pool.query(query, params);

    console.log('📡 Locations trouvées:', result.rows.length);

    res.json({
      locations: result.rows.map(l => ({
        id: l.id,
        code: l.code,
        clientNom: `${l.first_name} ${l.last_name}`,
        clientEmail: l.email,
        clientPhone: l.phone,
        appareilNom: l.appareil_nom,
        dateDebut: l.date_debut,
        dateFin: l.date_fin,
        prixJournalier: l.prix_journalier,
        montantTotal: l.montant_total,
        statut: l.statut,
        commentaireAdmin: l.commentaire_admin,
        createdAt: l.created_at
      }))
    });
  } catch (error) {
    console.error('Erreur liste locations:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Créer une location (admin ou client)
router.post('/', authMiddleware, [
  body('appareilId').isInt().withMessage('ID appareil requis'),
  body('dateDebut').isISO8601().withMessage('Date début invalide'),
  body('dateFin').isISO8601().withMessage('Date fin invalide'),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      console.log('❌ Validation errors:', errors.array());
      return res.status(400).json({ errors: errors.array() });
    }

    const { appareilId, dateDebut, dateFin, userId, nombreJours, total } = req.body;
    console.log('📦 POST /locations body:', req.body);
    console.log('👤 User:', req.user.role, req.user.userId);
    console.log('👤 User ID from token:', req.user.userId);

    // Admin peut créer pour un autre user, client seulement pour lui-même
    const targetUserId = req.user.role === 'admin' && userId ? parseInt(userId) : req.user.userId;

    // Extract numeric ID from format like 'APP-001' → 1
    let targetAppareilId = appareilId;
    if (typeof appareilId === 'string' && appareilId.includes('APP-')) {
      targetAppareilId = parseInt(appareilId.replace('APP-', ''));
      console.log('🔧 Converted appareilId from', appareilId, 'to', targetAppareilId);
    } else if (typeof appareilId === 'string') {
      // Try parsing as plain number string
      targetAppareilId = parseInt(appareilId);
    }
    
    // Validate the parsed ID
    if (isNaN(targetAppareilId) || targetAppareilId <= 0) {
      console.log('❌ Invalid appareilId after parsing:', targetAppareilId);
      return res.status(400).json({ error: 'ID appareil invalide' });
    }

    console.log('🔍 Looking for appareil with id:', targetAppareilId);

    // Récupérer les infos de l'appareil
    const appareilResult = await pool.query(
      'SELECT * FROM appareils WHERE id = $1',
      [targetAppareilId]
    );

    if (appareilResult.rows.length === 0) {
      console.log('❌ Appareil non trouvé avec ID:', targetAppareilId, '(original:', appareilId, ')');
      return res.status(404).json({ error: 'Appareil introuvable. Veuillez sélectionner un autre appareil.' });
    }

    const appareil = appareilResult.rows[0];
    console.log('🔍 Appareil:', appareil.nom, 'disponible:', appareil.disponible ? 'OUI' : 'NON');
    
    // Nettoyage et validation des dates
    const dateDebutClean = dateDebut.split('T')[0];
    const dateFinClean = dateFin.split('T')[0];
    const debut = new Date(dateDebutClean);
    const fin = new Date(dateFinClean);

    if (isNaN(debut.getTime()) || isNaN(fin.getTime())) {
      return res.status(400).json({ error: 'Format de date invalide (attendu: YYYY-MM-DD)' });
    }

    let jours = Math.ceil((fin - debut) / (1000 * 60 * 60 * 24)) + 1;
    if (jours <= 0) jours = 1;

    // Vérifier si le prix existe (gestion camelCase ou snake_case du DB)
    const prixJournalier = appareil.prix_location || appareil.prix_journalier || 0;
    
    // Utiliser total du client si fourni, sinon calcul automatique
    const montantTotal = (total && !isNaN(total)) ? parseInt(total) : (prixJournalier * jours);

    if (isNaN(montantTotal) || montantTotal <= 0) {
      console.error('❌ Erreur calcul montantTotal:', { prixJournalier, jours, total });
      return res.status(400).json({ error: 'Le montant total calculé est invalide' });
    }
    
    const code = `LOC-${Date.now()}`;
    console.log(`💰 Insertion Location: User=${targetUserId}, Appareil=${appareilId}, Total=${montantTotal}`);

    const result = await pool.query(
      `INSERT INTO locations (code, user_id, appareil_id, appareil_nom, date_debut, date_fin, prix_journalier, montant_total, statut)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'en_attente')
       RETURNING *`,
      [code, parseInt(targetUserId), parseInt(appareilId), appareil.nom, dateDebutClean, dateFinClean, prixJournalier, montantTotal]
    );

    console.log('✅ Location INSERTED id=', result.rows[0].id, 'code=', code, 'statut=en_attente');

    const location = result.rows[0];

    // NE PAS marquer l'appareil comme indisponible automatiquement
    // L'appareil ne sera marqué indisponible que quand l'admin approuve

    res.status(201).json({
      message: 'Location créée en attente de validation',
      location: {
        id: location.id,
        code: location.code,
        appareilNom: location.appareil_nom,
        dateDebut: location.date_debut,
        dateFin: location.date_fin,
        montantTotal: location.montant_total,
        statut: location.statut
      }
    });
  } catch (error) {
    console.error('💥 Erreur création location:', error);
    
    // Provide more specific error messages based on the error type
    let errorMessage = 'Erreur serveur';
    let hint = 'Veuillez réessayer plus tard';
    
    if (error.code === '23502') {
      // NOT NULL constraint violation
      errorMessage = 'Données manquantes';
      hint = 'Vérifiez que tous les champs obligatoires sont remplis';
    } else if (error.code === '23503') {
      // Foreign key violation
      errorMessage = 'Appareil ou utilisateur introuvable';
      hint = 'L\'appareil ou l\'utilisateur sélectionné n\'existe plus';
    } else if (error.code === '22P02') {
      // Invalid input syntax
      errorMessage = 'Format de données invalide';
      hint = 'Les dates doivent être au format YYYY-MM-DD';
    } else if (error.message) {
      errorMessage = error.message;
    }
    
    res.status(500).json({ 
      error: errorMessage, 
      details: error.message,
      hint: hint
    });
  }
});

// Terminer une location (admin)
router.patch('/:id/terminer', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { id } = req.params;

    const result = await pool.query(
      `UPDATE locations
       SET statut = 'termine', updated_at = CURRENT_TIMESTAMP
       WHERE id = $1
       RETURNING appareil_id`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Location non trouvée' });
    }

    // Rendre l'appareil disponible
    const appareilId = result.rows[0].appareil_id;
    if (appareilId) {
      await pool.query('UPDATE appareils SET disponible = true WHERE id = $1', [appareilId]);
    }

    res.json({ message: 'Location terminée' });
  } catch (error) {
    console.error('Erreur terminer location:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Approuver une location (admin)
router.patch('/:id/approuver', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { id } = req.params;

    // First get the location with user info
    const locResult = await pool.query(
      `SELECT l.*, u.first_name, u.last_name, u.email 
       FROM locations l 
       JOIN users u ON l.user_id = u.id 
       WHERE l.id = $1`,
      [id]
    );

    if (locResult.rows.length === 0) {
      return res.status(404).json({ error: 'Location non trouvée' });
    }

    const location = locResult.rows[0];

    // Update the location status
    const result = await pool.query(
      `UPDATE locations
       SET statut = 'en_cours', updated_at = CURRENT_TIMESTAMP
       WHERE id = $1
       RETURNING *`,
      [id]
    );

    const updatedLocation = result.rows[0];

    // Marquer l'appareil comme indisponible
    if (updatedLocation.appareil_id) {
      await pool.query('UPDATE appareils SET disponible = false WHERE id = $1', [updatedLocation.appareil_id]);
    }

    // Envoyer un email de notification
    const userName = `${location.first_name} ${location.last_name}`;
    const userEmail = location.email;
    
    // Envoyer l'email de manière asynchrone (ne pas bloquer la réponse)
    sendLocationApprovedEmail(
      userEmail,
      userName,
      updatedLocation.code,
      updatedLocation.appareil_nom,
      updatedLocation.date_debut,
      updatedLocation.date_fin,
      updatedLocation.montant_total
    ).catch(err => console.error('Erreur envoi email approbation:', err));

    res.json({ message: 'Location approuvée', location: updatedLocation });
  } catch (error) {
    console.error('Erreur approuver location:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Rejeter une location (admin)
router.patch('/:id/rejeter', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const { raison } = req.body;

    // First get the location with user info
    const locResult = await pool.query(
      `SELECT l.*, u.first_name, u.last_name, u.email 
       FROM locations l 
       JOIN users u ON l.user_id = u.id 
       WHERE l.id = $1`,
      [id]
    );

    if (locResult.rows.length === 0) {
      return res.status(404).json({ error: 'Location non trouvée' });
    }

    const location = locResult.rows[0];

    const result = await pool.query(
      `UPDATE locations
       SET statut = 'rejetee', commentaire_admin = $1, updated_at = CURRENT_TIMESTAMP
       WHERE id = $2
       RETURNING *`,
      [raison || 'Demande rejetée', id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Location non trouvée' });
    }

    const updatedLocation = result.rows[0];

    // Envoyer un email de notification
    const userName = `${location.first_name} ${location.last_name}`;
    const userEmail = location.email;
    
    // Envoyer l'email de manière asynchrone (ne pas bloquer la réponse)
    sendLocationRejectedEmail(
      userEmail,
      userName,
      updatedLocation.code,
      updatedLocation.appareil_nom,
      raison || 'Demande rejetée'
    ).catch(err => console.error('Erreur envoi email rejet:', err));

    res.json({ message: 'Location rejetée', location: updatedLocation });
  } catch (error) {
    console.error('Erreur rejeter location:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

module.exports = router;