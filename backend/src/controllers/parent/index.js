'use strict';

module.exports = {
  ...require('./dashboard.controller'),
  ...require('./attendance.controller'),
  ...require('./achievements.controller'),
  ...require('./badges.controller'),
  ...require('./extracurriculars.controller'),
  ...require('./counseling.controller'),
  ...require('./notifications.controller'),
};
