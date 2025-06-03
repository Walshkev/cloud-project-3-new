const { Router } = require('express')
const { Photo, PhotoClientFields } = require('../models/photo')
const { requireAuth } = require('./auth')

const router = Router()

// GET /photos - List all photos (public)
router.get('/', async (req, res, next) => {
  try {
    const photos = await Photo.findAll()
    res.status(200).json({ photos })
  } catch (err) {
    next(err)
  }
})

// GET /photos/:id - Get a single photo (public)
router.get('/:id', async (req, res, next) => {
  try {
    const photo = await Photo.findByPk(req.params.id)
    if (photo) {
      res.status(200).json(photo)
    } else {
      res.status(404).json({ error: "Photo not found" })
    }
  } catch (err) {
    next(err)
  }
})

// POST /photos - Create a new photo (owner or admin only)
router.post('/', requireAuth, async (req, res, next) => {
  try {
    // Only allow if req.user.admin or req.user.userId === req.body.userId
    if (!req.user.admin && req.body.userId != req.user.userId) {
      return res.status(403).json({ error: "Forbidden: not your resource" })
    }
    const photo = await Photo.create(req.body, { fields: PhotoClientFields })
    res.status(201).json({ id: photo.id })
  } catch (err) {
    next(err)
  }
})

// PUT /photos/:id - Update a photo (owner or admin only)
router.put('/:id', requireAuth, async (req, res, next) => {
  try {
    const photo = await Photo.findByPk(req.params.id)
    if (!photo) {
      return res.status(404).json({ error: "Photo not found" })
    }
    if (!req.user.admin && photo.userId != req.user.userId) {
      return res.status(403).json({ error: "Forbidden: not your resource" })
    }
    await photo.update(req.body, { fields: PhotoClientFields })
    res.status(200).json({ message: "Photo updated" })
  } catch (err) {
    next(err)
  }
})

// DELETE /photos/:id - Delete a photo (owner or admin only)
router.delete('/:id', requireAuth, async (req, res, next) => {
  try {
    const photo = await Photo.findByPk(req.params.id)
    if (!photo) {
      return res.status(404).json({ error: "Photo not found" })
    }
    if (!req.user.admin && photo.userId != req.user.userId) {
      return res.status(403).json({ error: "Forbidden: not your resource" })
    }
    await photo.destroy()
    res.status(204).end()
  } catch (err) {
    next(err)
  }
})

module.exports = router