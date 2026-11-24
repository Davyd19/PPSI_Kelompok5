const express = require('express');
const router = express.Router();
const { authenticate } = require('../controllers/auth.controller');
const student = require('../controllers/student');

// Require authentication for all student routes
router.use(authenticate);

// Student Dashboard data
router.get('/dashboard', student.dashboard);

// Attendance routes
router.post('/attendance/scan', student.scanAttendance);
router.get('/attendance/history', student.attendanceHistory);

// Counseling routes
router.get('/counseling', student.counseling);

// Badges
router.get('/badges', student.badges);

// Extracurricular routes
router.get('/extracurriculars', student.extracurriculars);
router.get('/extracurriculars/:id', student.extracurricularDetail);
router.post('/extracurriculars/:id/register', student.registerExtracurricular);

// Achievements routes
router.get('/achievements', student.achievements);
router.post('/achievements/submit', student.submitAchievement);

// Notifications routes
router.get('/notifications', student.notifications);
router.get('/notifications/:id', student.notificationDetail);
router.post('/notifications/read-all', student.markNotificationsRead);
router.post('/notifications/read', student.markNotificationsRead);

module.exports = router;
