const { Router } = require('express')
const router = Router()

router.use('/businesses', require('./businesses'))
router.use('/reviews', require('./reviews'))
router.use('/photos', require('./photos'))
router.use('/users', require('./users'))

module.exports = router
