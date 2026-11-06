const jwt = require('jsonwebtoken');

const { isSessionRevoked } = require('../services/session_revocation');

const authMiddleware = (req, res, next) => {
  try {
    const secret = process.env.JWT_SECRET?.trim();
    if (!secret) {
      console.error('❌ JWT_SECRET manquant');
      return res.status(503).json({ error: 'Service d’authentification indisponible' });
    }

    const token = req.headers.authorization?.split(' ')[1];

    if (!token) {
      return res.status(401).json({ error: 'Token manquant' });
    }

    const decoded = jwt.verify(token, secret);

    // Un jeton reste signé jusqu'à son expiration : la liste de révocation est
    // ce qui coupe l'accès d'un compte supprimé ou désactivé, tout de suite.
    if (isSessionRevoked(decoded.userId)) {
      return res.status(401).json({
        code: 'SESSION_REVOKED',
        error:
          'Session fermée : ce compte a été supprimé ou désactivé. Reconnectez-vous ou créez un nouveau compte.',
      });
    }

    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Token invalide' });
  }
};

const adminMiddleware = (req, res, next) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Accès interdit - Admin seulement' });
  }
  next();
};

// Renseigne req.user si un jeton valide est fourni, sans jamais bloquer la requête.
// Utilisé sur les routes publiques qui doivent pouvoir rattacher une action à un compte.
const optionalAuthMiddleware = (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return next();

  const secret = process.env.JWT_SECRET?.trim();
  if (!secret) return next();

  try {
    const decoded = jwt.verify(token, secret);
    // Une session fermée est traitée comme une requête anonyme.
    req.user = isSessionRevoked(decoded.userId) ? undefined : decoded;
  } catch (error) {
    // Un jeton invalide est traité comme une requête anonyme.
  }
  return next();
};

module.exports = { authMiddleware, adminMiddleware, optionalAuthMiddleware };
