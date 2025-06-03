const { Router } = require('express')
const { Review, ReviewClientFields } = require('../models/review')
const { requireAuth } = require('./auth')

const router = Router()

// GET /reviews - List all reviews (public)
router.get('/', async (req, res, next) => {
  try {
    const reviews = await Review.findAll()
    res.status(200).json({ reviews })
  } catch (err) {
    next(err)
  }
})

// GET /reviews/:id - Get a single review (public)
router.get('/:id', async (req, res, next) => {
  try {
    const review = await Review.findByPk(req.params.id)
    if (review) {
      res.status(200).json(review)
    } else {
      res.status(404).json({ error: "Review not found" })
    }
  } catch (err) {
    next(err)
  }
})

// POST /reviews - Create a new review (owner or admin only)
router.post('/', requireAuth, async (req, res, next) => {
  try {
    // Only allow if req.user.admin or req.user.userId === req.body.userId
    if (!req.user.admin && req.body.userId != req.user.userId) {
      return res.status(403).json({ error: "Forbidden: not your resource" })
    }
    const review = await Review.create(req.body, { fields: ReviewClientFields })
    res.status(201).json({ id: review.id })
  } catch (err) {
    next(err)
  }
})

// PUT /reviews/:id - Update a review (owner or admin only)
router.put('/:id', requireAuth, async (req, res, next) => {
  try {
    const review = await Review.findByPk(req.params.id)
    if (!review) {
      return res.status(404).json({ error: "Review not found" })
    }
    if (!req.user.admin && review.userId != req.user.userId) {
      return res.status(403).json({ error: "Forbidden: not your resource" })
    }
    await review.update(req.body, { fields: ReviewClientFields })
    res.status(200).json({ message: "Review updated" })
  } catch (err) {
    next(err)
  }
})

// DELETE /reviews/:id - Delete a review (owner or admin only)
router.delete('/:id', requireAuth, async (req, res, next) => {
  try {
    const review = await Review.findByPk(req.params.id)
    if (!review) {
      return res.status(404).json({ error: "Review not found" })
    }
    if (!req.user.admin && review.userId != req.user.userId) {
      return res.status(403).json({ error: "Forbidden: not your resource" })
    }
    await review.destroy()
    res.status(204).end()
  } catch (err) {
    next(err)
  }
})

module.exports = router