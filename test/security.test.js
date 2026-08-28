// test/security.test.js - Security tests for alcalc-state helper
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { execFileSync } = require('node:child_process');

const HELPER_SCRIPT = path.join(__dirname, '..', 'scripts', 'alcalc-state.py');
const STATE_DIR = path.join(os.homedir(), '.local', 'state', 'omarchy', 'alcalc');

test('Security & Descriptor Safety: Normal read and write', () => {
  // Clear history
  execFileSync('python3', [HELPER_SCRIPT, 'clear-history']);
  let out = execFileSync('python3', [HELPER_SCRIPT, 'read-history'], { encoding: 'utf-8' });
  assert.equal(out.trim(), '[]');

  // Write history
  const testHist = [{ expr: '2+2', result: '4', time: '12:00:00' }];
  execFileSync('python3', [HELPER_SCRIPT, 'write-history', JSON.stringify(testHist)]);
  out = execFileSync('python3', [HELPER_SCRIPT, 'read-history'], { encoding: 'utf-8' });
  assert.deepEqual(JSON.parse(out), testHist);

  // Clear vars
  execFileSync('python3', [HELPER_SCRIPT, 'clear-vars']);
  out = execFileSync('python3', [HELPER_SCRIPT, 'read-vars'], { encoding: 'utf-8' });
  assert.equal(out.trim(), '{}');

  // Write vars
  const testVars = { ANS: 42, X: 10 };
  execFileSync('python3', [HELPER_SCRIPT, 'write-vars', JSON.stringify(testVars)]);
  out = execFileSync('python3', [HELPER_SCRIPT, 'read-vars'], { encoding: 'utf-8' });
  assert.deepEqual(JSON.parse(out), testVars);

  // read-all
  out = execFileSync('python3', [HELPER_SCRIPT, 'read-all'], { encoding: 'utf-8' });
  const all = JSON.parse(out);
  assert.deepEqual(all.history, testHist);
  assert.deepEqual(all.vars, testVars);
});

test('Security: Planted FIFO does not hang reader and is safely replaced on write', () => {
  fs.mkdirSync(STATE_DIR, { recursive: true });
  const histPath = path.join(STATE_DIR, 'history.json');

  // Remove existing history.json
  try { fs.unlinkSync(histPath); } catch (e) {}

  // Create FIFO at history.json
  execFileSync('mkfifo', [histPath]);
  assert.ok(fs.statSync(histPath).isFIFO());

  // Reading from planted FIFO should NOT hang, should detect non-regular file and return []
  const readOut = execFileSync('python3', [HELPER_SCRIPT, 'read-history'], { encoding: 'utf-8', timeout: 2000 });
  assert.equal(readOut.trim(), '[]');

  // Writing to history.json with planted FIFO should not hang or follow FIFO; should atomically replace FIFO with regular file
  const testHist = [{ expr: 'FIFO_TEST', result: 'SAFE' }];
  execFileSync('python3', [HELPER_SCRIPT, 'write-history', JSON.stringify(testHist)], { timeout: 2000 });

  const stat = fs.lstatSync(histPath);
  assert.ok(stat.isFile(), 'history.json should now be a regular file');
  assert.ok(!stat.isFIFO(), 'history.json should no longer be a FIFO');

  const afterOut = execFileSync('python3', [HELPER_SCRIPT, 'read-history'], { encoding: 'utf-8' });
  assert.deepEqual(JSON.parse(afterOut), testHist);
});

test('Security: Planted symlink does not redirect writes and is not traversed on read', () => {
  fs.mkdirSync(STATE_DIR, { recursive: true });
  const histPath = path.join(STATE_DIR, 'history.json');
  const targetSecretPath = path.join(STATE_DIR, 'secret_target.txt');

  fs.writeFileSync(targetSecretPath, 'DO_NOT_OVERWRITE_SECRET_DATA');

  // Remove existing history.json and make it a symlink to targetSecretPath
  try { fs.unlinkSync(histPath); } catch (e) {}
  fs.symlinkSync(targetSecretPath, histPath);
  assert.ok(fs.lstatSync(histPath).isSymbolicLink());

  // Reading via helper should NOT traverse symlink (O_NOFOLLOW) and should return default []
  const readOut = execFileSync('python3', [HELPER_SCRIPT, 'read-history'], { encoding: 'utf-8' });
  assert.equal(readOut.trim(), '[]');

  // Writing via helper should NOT overwrite targetSecretPath, but replace the symlink itself
  const newHist = [{ expr: 'SYMLINK_TEST', result: 'SAFE' }];
  execFileSync('python3', [HELPER_SCRIPT, 'write-history', JSON.stringify(newHist)]);

  // Check target file is untouched
  const secretContent = fs.readFileSync(targetSecretPath, 'utf-8');
  assert.equal(secretContent, 'DO_NOT_OVERWRITE_SECRET_DATA');

  // Check history.json is now a regular file and not a symlink
  const histStat = fs.lstatSync(histPath);
  assert.ok(histStat.isFile());
  assert.ok(!histStat.isSymbolicLink());

  // Cleanup
  try { fs.unlinkSync(targetSecretPath); } catch (e) {}
});

test('Security: Oversized file is rejected by byte cap', () => {
  fs.mkdirSync(STATE_DIR, { recursive: true });
  const varsPath = path.join(STATE_DIR, 'vars.json');

  try { fs.unlinkSync(varsPath); } catch (e) {}

  // Write a file larger than 512KB cap (e.g. 600KB of spaces)
  const bigBuffer = Buffer.alloc(600 * 1024, 32);
  fs.writeFileSync(varsPath, bigBuffer);

  // Read should fail size check and return default {}
  const readOut = execFileSync('python3', [HELPER_SCRIPT, 'read-vars'], { encoding: 'utf-8' });
  assert.equal(readOut.trim(), '{}');
});
