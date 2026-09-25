const jwt = require('jsonwebtoken');
const pool = require('../config/database');

const authMiddleware = async (req, res, next) => {
  try {
    const secret = process.env.JWT_SECRET?.trim();
    if (!secret) {
      console.error('JWT_SECRET manquant');
      return res.status(503).json({ error: 'Service d’authentification indisponible' });
    }

    const token = req.headers.authorization?.split(' ')[1];
    if (!token) {
      return res.status(401).json({ error: 'Token manquant' });
    }

    const decoded = jwt.verify(token, secret);
    req.user = decoded;

    // Les comptes clients désactivés perdent aussi l’accès avec leurs anciens JWT.
    if (decoded.role !== 'admin') {
      const account = await pool.query(
        'SELECT is_active FROM users WHERE id = $1',
        [decoded.userId],
      );
      if (account.rows.length === 0 || account.rows[0].is_active === false) {
        return res.status(401).json({ error: 'Compte désactivé ou introuvable' });
      }
    }

    return next();
  } catch (error) {
    if (error.name === 'JsonWebTokenError' || error.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Token invalide' });
    }
    console.error('Erreur de vérification de session:', error);
    return res.status(503).json({ error: 'Service d’authentification indisponible' });
  }
};

const adminMiddleware = (req, res, next) => {
  if (req.user?.role !== 'admin') {
    return res.status(403).json({ error: 'Accès interdit - Admin seulement' });
  }
  return next();
};

module.exports = { authMiddleware, adminMiddleware };
