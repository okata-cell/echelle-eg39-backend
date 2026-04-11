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
        appareilId: l.appareil_id,
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

    // Extract numeric ID or code from the input
    // Can be either: 'APP-001' (string code) or 11 (integer id) or '11' (string id)
    let targetAppareilId = appareilId;
    let searchByCode = false;
    
    if (typeof appareilId === 'string') {
      if (appareilId.includes('APP-')) {
        // It's like 'APP-001', find by code in DB
        searchByCode = true;
        console.log('🔧 Looking for appareil with code:', appareilId);
      } else {
        // Try parsing as plain number string
        targetAppareilId = parseInt(appareilId);
        console.log('🔧 Parsed appareilId string as int:', targetAppareilId);
      }
    } else if (typeof appareilId === 'number') {
      // It's already a number (int)
      targetAppareilId = appareilId;
      console.log('🔧 Using appareilId as int:', targetAppareilId);
    }
    
    // Validate the parsed ID (if not searching by code)
    if (!searchByCode && (isNaN(targetAppareilId) || targetAppareilId <= 0)) {
      console.log('❌ Invalid appareilId after parsing:', targetAppareilId);
      return res.status(400).json({ error: 'ID appareil invalide' });
    }

    console.log('🔍 Looking for appareil with:', searchByCode ? 'code' : 'id', ':', searchByCode ? appareilId : targetAppareilId);

    // Try to find the appareil - first by id, then by code if not found
    let appareilResult;
    if (!searchByCode) {
      // Try by id first
      appareilResult = await pool.query('SELECT * FROM appareils WHERE id = $1', [targetAppareilId]);
      
      // If not found by id, try by code format
      if (appareilResult.rows.length === 0) {
        console.log('🔄 Not found by id, trying by code...');
        const codeFormat = `APP-${String(targetAppareilId).padStart(3, '0')}`;
        appareilResult = await pool.query('SELECT * FROM appareils WHERE code = $1', [codeFormat]);
        console.log('🔍 Try by code:', codeFormat, 'Found:', appareilResult.rows.length);
      }
    } else {
      // Search by code directly
      appareilResult = await pool.query('SELECT * FROM appareils WHERE code = $1', [appareilId]);
    }

    if (appareilResult.rows.length === 0) {
      console.log('❌ Appareil non trouvé: ID=', targetAppareilId, ', original=', appareilId);
      console.log('🔍 Debug: tous les appareils dans la DB:');
      const allAppareils = await pool.query('SELECT id, code, nom FROM appareils LIMIT 20');
      console.log('→', allAppareils.rows);
      
      // Try to find by ID from the default appareils (APP-001 -> id=1, etc.)
      // This handles the case where frontend sends numeric ID like 13
      const frontendId = typeof appareilId === 'number' ? appareilId : parseInt(appareilId);
      if (!isNaN(frontendId)) {
        console.log('🔄 Trying alternative: search by ID =', frontendId);
        const altResult = await pool.query('SELECT * FROM appareils WHERE id = $1', [frontendId]);
        if (altResult.rows.length > 0) {
          console.log('✅ Found by alternative ID search!');
          appareilResult = altResult;
        }
      }
      
      // If still not found, check if there's an APP-00X format issue
      if (appareilResult.rows.length === 0 && typeof appareilId === 'number') {
        const codeFormat = `APP-${String(appareilId).padStart(3, '0')}`;
        console.log('🔄 Trying code format:', codeFormat);
        const codeResult = await pool.query('SELECT * FROM appareils WHERE code = $1', [codeFormat]);
        if (codeResult.rows.length > 0) {
          console.log('✅ Found by code format!');
          appareilResult = codeResult;
        }
      }
      
      if (appareilResult.rows.length === 0) {
        return res.status(404).json({ error: 'Appareil introuvable. Veuillez sélectionner un autre appareil.' });
      }
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
    console.log(`💰 Insertion Location: User=${targetUserId}, Appareil=${appareil.id}, Total=${montantTotal}`);

    // Insertion simple - la contrainte sera corrigée par /fix-constraint
    const result = await pool.query(
      `INSERT INTO locations (code, user_id, appareil_id, appareil_nom, date_debut, date_fin, prix_journalier, montant_total)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [code, parseInt(targetUserId), appareil.id, appareil.nom, dateDebutClean, dateFinClean, prixJournalier, montantTotal]
    );

    // Mettre à jour le statut après insertion
    await pool.query("UPDATE locations SET statut = 'en_attente' WHERE id = $1", [result.rows[0].id]);
    const finalResult = await pool.query('SELECT * FROM locations WHERE id = $1', [result.rows[0].id]);
    const location = finalResult.rows[0];

    console.log('✅ Location INSERTED id=', location.id, 'code=', code, 'statut=', location.statut);

      // NE PAS marquer l'appareil comme indisponible automatiquement
      // L'appareil ne sera marqué indisponible que quand l'admin approuve

      res.status(201).json({
        message: 'Demande de location créée - en attente de validation admin',
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

// Supprimer et recréer la CHECK constraint sans 'en_attente' (la vraie solution)
router.get('/fix-constraint', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    // Supprimer la constraint
    await pool.query('ALTER TABLE locations DROP CONSTRAINT IF EXISTS locations_statut_check');
    // Recréer avec 'en_attente' inclus
    await pool.query(
      "ALTER TABLE locations ADD CONSTRAINT locations_statut_check CHECK (statut IN ('en_attente', 'approuvee', 'rejetee', 'en_cours', 'termine', 'en_retard'))"
    );
    console.log('✅ CHECK constraint recréée avec en_attente');
    res.json({ message: 'Constraint corrigée' });
  } catch (e) {
    console.error('❌ Erreur:', e);
    res.status(500).json({ error: e.message });
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

// Réinitialiser toutes les locations en 'en_attente' (pour diagnostic/fix)
router.patch('/reset-statuts', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      "UPDATE locations SET statut = 'en_attente' WHERE statut = 'en_cours' RETURNING *"
    );
    console.log('🔧 Reset statuts: ${result.rowCount} locations mises à jour');
    res.json({ 
      message: '${result.rowCount} locations remises en attente',
      updated: result.rows 
    });
  } catch (error) {
    console.error('Erreur reset statuts:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Vérifier et expirer les locations automatiquement
router.get('/check-expired', authMiddleware, async (req, res) => {
  try {
    const today = new Date().toISOString().split('T')[0];
    
    const expiredResult = await pool.query(
      "SELECT l.id, l.code, l.appareil_id, l.date_fin FROM locations l WHERE statut = 'en_cours' AND date_fin < $1",
      [today]
    );
    
    const expiredLocations = [];
    
    for (const loc of expiredResult.rows) {
      // Marquer comme terminée
      await pool.query(
        "UPDATE locations SET statut = 'termine', updated_at = NOW() WHERE id = $1",
        [loc.id]
      );
      
      // Rendre l'appareil disponible
      if (loc.appareil_id) {
        await pool.query('UPDATE appareils SET disponible = true WHERE id = $1', [loc.appareil_id]);
      }
      
      expiredLocations.push({ id: loc.id, code: loc.code, dateFin: loc.date_fin });
    }
    
    if (expiredLocations.length > 0) {
      console.log(`⏰ ${expiredLocations.length} location(s) expirée(s)`);
    }
    
    res.json({ 
      message: '${expiredLocations.length} location(s) expirée(s) et terminée(s)',
      expired: expiredLocations
    });
  } catch (error) {
    console.error('Erreur vérification:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Supprimer toutes les locations actives (en_cours) - pour recommencer à zéro
router.delete('/clear-active', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    // D'abord récupérer les appareil_id pour les rendre disponibles
    const locsToDelete = await pool.query(
      "SELECT appareil_id FROM locations WHERE statut = 'en_cours'"
    );
    
    // Rendre les appareils disponibles
    for (const loc of locsToDelete.rows) {
      if (loc.appareil_id) {
        await pool.query('UPDATE appareils SET disponible = true WHERE id = $1', [loc.appareil_id]);
      }
    }
    
    // Supprimer les locations actives
    const result = await pool.query(
      "DELETE FROM locations WHERE statut = 'en_cours' RETURNING id, code"
    );
    
    console.log('🗑️ Supprimé ${result.rowCount} locations actives');
    res.json({ 
      message: '${result.rowCount} locations actives supprimées',
      deleted: result.rows 
    });
  } catch (error) {
    console.error('Erreur suppression:', error);
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
    console.error('💥 Erreur rejeter location:', error);
    console.error('💥 Code:', error.code);
    console.error('💥 Detail:', error.detail);
    res.status(500).json({ 
      error: 'Erreur serveur', 
      details: error.message,
      code: error.code
    });
  }
});

// Supprimer une location terminée ou rejétée (client ou admin)
router.delete('/:id', authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.userId;
    const isAdmin = req.user.role === 'admin';
    
    // Vérifier que la location existe et est terminée ou rejétée
    const checkResult = await pool.query(
      'SELECT * FROM locations WHERE id = $1',
      [id]
    );
    
    if (checkResult.rows.length === 0) {
      return res.status(404).json({ error: 'Location non trouvée' });
    }
    
    const location = checkResult.rows[0];
    
    // Vérifier le statut - seulement terminé ou rejété peut être supprimé
    if (location.statut !== 'termine' && location.statut !== 'rejetee') {
      return res.status(400).json({ 
        error: 'Seules les locations terminées ou rejétées peuvent être supprimées' 
      });
    }
    
    // Vérifier les permissions: soit admin, soit le propriétaire
    if (!isAdmin && location.user_id !== userId) {
      return res.status(403).json({ error: 'Non autorisé' });
    }
    
    // Supprimer la location
    await pool.query('DELETE FROM locations WHERE id = $1', [id]);
    
    console.log('🗑️ Location supprimée: id=', id, 'par user=', userId);
    
    res.json({ message: 'Location supprimée' });
  } catch (error) {
    console.error('💥 Erreur supprimer location:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

module.exports = router;