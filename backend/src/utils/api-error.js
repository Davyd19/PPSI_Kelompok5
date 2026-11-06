module.exports = (status, code, message, details) => Object.assign(new Error(message), {
  status,
  code,
  details
});
