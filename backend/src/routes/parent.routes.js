const express = require('express');
const router = express.Router();
const { authenticate } = require('../controllers/auth.controller');
const parent = require('../controllers/parent');

router.use(authenticate);

router.get('/dashboard', parent.dashboard);
router.get('/attendance', parent.attendanceHistory);
router.get('/achievements', parent.achievements);
router.get('/badges', parent.badges);
router.get('/extracurriculars', parent.extracurriculars);
router.get('/counseling', parent.counseling);
router.get('/counseling/:id', parent.counselingDetail);
router.get('/notifications', parent.notifications);
router.get('/notifications/:id', parent.notificationDetail);
router.post('/notifications/read-all', parent.markNotificationsRead);
router.post('/notifications/read', parent.markNotificationsRead);

module.exports = router;
