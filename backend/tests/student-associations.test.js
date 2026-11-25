const { test, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { models, sequelize } = require('../src/models');

after(async () => {
  await sequelize.close();
});

function readControllerDir(dirPath) {
  return fs
    .readdirSync(dirPath)
    .filter((f) => f.endsWith('.js'))
    .map((f) => ({ file: f, content: fs.readFileSync(path.join(dirPath, f), 'utf8') }));
}

for (const folder of ['student', 'parent']) {
  test(`all Sequelize include aliases in controllers/${folder}/ match defined model associations`, () => {
    const dir = path.join(__dirname, '../src/controllers', folder);
    const files = readControllerDir(dir);
    const pattern = /model:\s*models\.(\w+),\s*as:\s*'(\w+)'/g;
    let totalMatches = 0;

    for (const { file, content } of files) {
      for (const match of content.matchAll(pattern)) {
        totalMatches++;
        const [, name, alias] = match;
        assert.ok(models[name], `Unknown model '${name}' referenced in ${folder}/${file}`);
        const found = Object.values(models).some(
          (m) => m.associations[alias]?.target === models[name],
        );
        assert.ok(
          found,
          `Association alias '${alias}' pointing to model '${name}' in ${folder}/${file} does not exist in models`,
        );
      }
    }

    assert.ok(totalMatches >= 10, `Expected at least 10 association matches in ${folder}/, found ${totalMatches}`);
  });
}
