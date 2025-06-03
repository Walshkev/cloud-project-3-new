const { Router } = require('express')
const { Business, BusinessClientFields } = require('../models/business')
const { requireAuth } = require('./auth')
const { User } = require('../models/user')

const router = Router()

// GET /businesses - List all businesses (public)
router.get('/', async (req, res, next) => {
  try {
    const businesses = await Business.findAll()
    res.status(200).json({ businesses })
  } catch (err) {
    next(err)
  }
})

// GET /businesses/:id - Get a single business (public)
router.get('/:id', async (req, res, next) => {
  try {
    const business = await Business.findByPk(req.params.id)
    if (business) {
      res.status(200).json(business)
    } else {
      res.status(404).json({ error: "Business not found" })
    }
  } catch (err) {
    next(err)
  }
})

// POST /businesses - Create a new business (owner or admin only)
router.post('/', requireAuth, async (req, res, next) => {
  try {
    // Only allow if req.user.admin or req.user.userId === req.body.ownerId
    if (!req.user.admin && req.body.ownerId != req.user.userId) {
      return res.status(403).json({ error: "Forbidden: not your resource" })
    }
    const business = await Business.create(req.body, { fields: BusinessClientFields })
    res.status(201).json({ id: business.id })
  } catch (err) {
    next(err)
  }
})

// PUT /businesses/:id - Update a business (owner or admin only)
router.put('/:id', requireAuth, async (req, res, next) => {
  try {
    const business = await Business.findByPk(req.params.id)
    if (!business) {
      return res.status(404).json({ error: "Business not found" })
    }
    if (!req.user.admin && business.ownerId != req.user.userId) {
      return res.status(403).json({ error: "Forbidden: not your resource" })
    }
    await business.update(req.body, { fields: BusinessClientFields })
    res.status(200).json({ message: "Business updated" })
  } catch (err) {
    next(err)
  }
})

// DELETE /businesses/:id - Delete a business (owner or admin only)
router.delete('/:id', requireAuth, async (req, res, next) => {
  try {
    const business = await Business.findByPk(req.params.id)
    if (!business) {
      return res.status(404).json({ error: "Business not found" })
    }
    if (!req.user.admin && business.ownerId != req.user.userId) {
      return res.status(403).json({ error: "Forbidden: not your resource" })
    }
    await business.destroy()
    res.status(204).end()
  } catch (err) {
    next(err)
  }
})

module.exports = router