// Snapshot contoh; tidak membaca/menulis tabel bisnis.
const fixture = require('./demo.fixture.json');
exports.profiles = () => structuredClone(fixture.profiles);
exports.periods = () => Object.keys(fixture.periods);
exports.dashboard = (role, period = '2026-10', grade = 'all') => {
  const profile = fixture.profiles.find(item => item.role === role);
  const selection = fixture.periods[period];
  if (!profile || !selection) return null;
  return structuredClone({ simulation: true, profile, ...fixture.shared, ...fixture.dashboards[role],
    period: selection.label, selectedPeriod: period, selectedGrade: grade,
    periodOptions: Object.entries(fixture.periods).map(([value,item]) => ({ value, label:item.label })),
    trend: selection.trend[grade], trendLabels: selection.labels, incidentSeries: selection.incidentSeries,
    reportsInPeriod: selection.reports,
  });
};
