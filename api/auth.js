const jwt = require('jsonwebtoken')
const JWT_SECRET = process.env.JWT_SECRET || 'supersecret'

function requireAuth(req, res, next) {
  const authHeader = req.get('Authorization')
  if (!authHeader) {
    return res.status(401).json({ error: 'Missing Authorization header' })
  }
  const [type, token] = authHeader.split(' ')
  if (type !== 'Bearer' || !token) {
    return res.status(401).json({ error: 'Invalid Authorization header format' })
  }
  try {
    const payload = jwt.verify(token, JWT_SECRET)
    req.user = payload
    next()
  } catch (err) {
    return res.status(401).json({ error: 'Invalid or expired token' })
  }
}

function requireUserOrAdmin(req, res, next) {
  const userId = req.params.userId || req.params.id
  if (req.user.admin || String(req.user.userId) === String(userId)) {
    return next()
  }
  return res.status(403).json({ error: 'Forbidden: not your resource' })
}

module.exports = { requireAuth, requireUserOrAdmin }