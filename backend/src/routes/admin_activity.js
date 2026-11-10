/**
 * Activité des demandes clientes, réservée aux administrateurs.
 *
 * `GET /`         : rattrapage et compteurs (utilisé au démarrage et en repli).
 * `GET /stream`   : flux temps réel, une ligne SSE par demande déposée.
 * `POST /:id/read`: acquittement d'une demande consultée.
 * `POST /read-all`: acquittement global.
 */
const express = require('express');

const router = express.Router();

const { authMiddleware, adminMiddleware } = require('../middleware/auth');
const activite = require('../services/admin_activity');

router.get('/', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const evenements = await activite.listActivity({
      since: req.query.since,
      limit: req.query.limit,
    });
    const resume = await activite.activitySummary();

    res.set('Cache-Control', 'private, no-store');
    return res.json({ events: evenements, ...resume });
  } catch (error) {
    console.error('Erreur activité admin:', error.message);
    return res.status(500).json({ error: 'Erreur serveur.' });
  }
});

router.get('/stream', authMiddleware, adminMiddleware, async (req, res) => {
  // `no-transform` et l'absence de compression sont indispensables : un proxy
  // qui bufferise le flux rendrait les alertes inutiles.
  res.set({
    'Content-Type': 'text/event-stream; charset=utf-8',
    'Cache-Control': 'no-cache, no-transform',
    Connection: 'keep-alive',
    'X-Accel-Buffering': 'no',
  });
  res.flushHeaders();
  res.write('retry: 5000\n\n');

  try {
    const resume = await activite.activitySummary();
    res.write(`event: etat\ndata: ${JSON.stringify(resume)}\n\n`);
  } catch (error) {
    console.error('Erreur état initial du flux activité:', error.message);
  }

  const unsubscribe = activite.subscribe(res);
  const heartbeat = setInterval(() => {
    try {
      res.write(': ping\n\n');
    } catch (error) {
      clearInterval(heartbeat);
    }
  }, activite.HEARTBEAT_MS);

  if (typeof heartbeat.unref === 'function') heartbeat.unref();

  req.on('close', () => {
    clearInterval(heartbeat);
    unsubscribe();
  });
});

router.post('/read-all', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const acknowledge = await activite.markAllRead(req.user.userId);
    return res.json({ acknowledged: acknowledge });
  } catch (error) {
    console.error('Erreur acquittement global activité:', error.message);
    return res.status(500).json({ error: 'Erreur serveur.' });
  }
});

router.post('/:id/read', authMiddleware, adminMiddleware, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isSafeInteger(id) || id <= 0) {
    return res.status(400).json({ error: 'Identifiant invalide.' });
  }

  try {
    const evenement = await activite.markEventRead(id, req.user.userId);
    if (!evenement) {
      // Déjà lu (ou disparu) : rien à signaler, l'écran s'aligne sur son état.
      return res.json({ event: null, dejaLu: true });
    }
    return res.json({ event: evenement });
  } catch (error) {
    console.error('Erreur acquittement activité:', error.message);
    return res.status(500).json({ error: 'Erreur serveur.' });
  }
});

module.exports = router;
