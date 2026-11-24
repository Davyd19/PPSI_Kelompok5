'use strict';

module.exports = {
  ...require('./dashboard.controller'),
  ...require('./attendance.controller'),
  ...require('./counseling.controller'),
  ...require('./badges.controller'),
  ...require('./extracurriculars.controller'),
  ...require('./achievements.controller'),
  ...require('./notifications.controller'),
};
