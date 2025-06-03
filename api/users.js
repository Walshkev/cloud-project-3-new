const { Router } = require('express')
const { User } = require('../models/user')
const { Business } = require('../models/business')
const { Photo } = require('../models/photo')
const { Review } = require('../models/review')
const bcrypt = require('bcrypt')
const jwt = require('jsonwebtoken')
const { requireAuth, requireUserOrAdmin } = require('./auth')
const JWT_SECRET = process.env.JWT_SECRET || 'supersecret'

const router = Router()

// POST /users - Register a new user
router.post('/', async function (req, res, next) {
  try {
    const { name, email, password } = req.body
    if (!name || !email || !password) {
      return res.status(400).json({ error: "Missing required fields: name, email, password" })
    }
    // Check for existing user
    const existing = await User.findOne({ where: { email } })
    if (existing) {
      return res.status(409).json({ error: "Email already in use" })
    }
    // DO NOT hash password here! Let the model do it.
    const user = await User.create({
      name,
      email,
      password, // pass raw password, model will hash it
      admin: false
    })
    res.status(201).json({ id: user.id })
  } catch (err) {
    next(err)
  }
})

// POST /users/login - User login
router.post('/login', async function (req, res, next) {
  try {
    const { email, password } = req.body
    if (!email || !password) {
      return res.status(400).json({ error: "Missing email or password" })
    }
    const user = await User.findOne({ where: { email } })
    if (!user) {
      return res.status(401).json({ error: "Invalid email or password" })
    }
    const valid = await bcrypt.compare(password, user.password)
    if (!valid) {
      return res.status(401).json({ error: "Invalid email or password" })
    }
    const token = jwt.sign({ userId: user.id, admin: user.admin }, JWT_SECRET, { expiresIn: '24h' })
    res.status(200).json({ token, userId: user.id })
  } catch (err) {
    next(err)
  }
})

// GET /users/:id - Get user info (excluding password, protected)
router.get('/:id', requireAuth, requireUserOrAdmin, async function (req, res, next) {
  try {
    const user = await User.findByPk(req.params.id, {
      attributes: { exclude: ['password'] }
    })
    if (!user) {
      return res.status(404).json({ error: "User not found" })
    }
    res.status(200).json(user)
  } catch (err) {
    next(err)
  }
})

// GET /users/:userId/businesses - Protected
router.get('/:userId/businesses', requireAuth, requireUserOrAdmin, async function (req, res) {
  const userId = req.params.userId
  const userBusinesses = await Business.findAll({ where: { ownerId: userId }})
  res.status(200).json({
    businesses: userBusinesses
  })
})

// GET /users/:userId/reviews - Protected
router.get('/:userId/reviews', requireAuth, requireUserOrAdmin, async function (req, res) {
  const userId = req.params.userId
  const userReviews = await Review.findAll({ where: { userId: userId }})
  res.status(200).json({
    reviews: userReviews
  })
})

// GET /users/:userId/photos - Protected
router.get('/:userId/photos', requireAuth, requireUserOrAdmin, async function (req, res) {
  const userId = req.params.userId
  const userPhotos = await Photo.findAll({ where: { userId: userId }})
  res.status(200).json({
    photos: userPhotos
  })
})

module.exports = router