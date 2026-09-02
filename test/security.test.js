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

test('Security: Planted symlink at ~/.config paths is rejected and victim is not overwritten', () => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'alcalc-config-test-'));
  const victimPath = path.join(tmpDir, 'victim.txt');
  fs.writeFileSync(victimPath, 'PRECIOUS_USER_DATA');

  // Planted symlink for hyprland.lua
  const hyprDir = path.join(tmpDir, 'hypr');
  fs.mkdirSync(hyprDir);
  const hyprSymlink = path.join(hyprDir, 'hyprland.lua');
  fs.symlinkSync(victimPath, hyprSymlink);

  // Configure hypr should NOT follow symlink or overwrite victim
  execFileSync('python3', [HELPER_SCRIPT, 'configure-hypr', hyprDir, 'hyprland.lua']);
  assert.equal(fs.readFileSync(victimPath, 'utf-8'), 'PRECIOUS_USER_DATA');
  assert.ok(fs.lstatSync(hyprSymlink).isSymbolicLink());

  // Planted symlink for shell.json
  const omarchyDir = path.join(tmpDir, 'omarchy');
  fs.mkdirSync(omarchyDir);
  const shellSymlink = path.join(omarchyDir, 'shell.json');
  fs.symlinkSync(victimPath, shellSymlink);

  // Configure shell should NOT follow symlink or overwrite victim
  execFileSync('python3', [HELPER_SCRIPT, 'configure-shell', omarchyDir, 'shell.json']);
  assert.equal(fs.readFileSync(victimPath, 'utf-8'), 'PRECIOUS_USER_DATA');
  assert.ok(fs.lstatSync(shellSymlink).isSymbolicLink());

  // Unconfigure shell should NOT follow symlink or overwrite victim
  execFileSync('python3', [HELPER_SCRIPT, 'unconfigure-shell', omarchyDir, 'shell.json']);
  assert.equal(fs.readFileSync(victimPath, 'utf-8'), 'PRECIOUS_USER_DATA');
  assert.ok(fs.lstatSync(shellSymlink).isSymbolicLink());

  // Cleanup
  fs.rmSync(tmpDir, { recursive: true, force: true });
});

test('Security: Planted FIFO at ~/.config paths does not hang configure/unconfigure operations', () => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'alcalc-fifo-test-'));

  const hyprDir = path.join(tmpDir, 'hypr');
  fs.mkdirSync(hyprDir);
  const hyprFifo = path.join(hyprDir, 'hyprland.lua');
  execFileSync('mkfifo', [hyprFifo]);

  const omarchyDir = path.join(tmpDir, 'omarchy');
  fs.mkdirSync(omarchyDir);
  const shellFifo = path.join(omarchyDir, 'shell.json');
  execFileSync('mkfifo', [shellFifo]);

  // All three commands must finish immediately and not hang
  execFileSync('python3', [HELPER_SCRIPT, 'configure-hypr', hyprDir, 'hyprland.lua'], { timeout: 2000 });
  execFileSync('python3', [HELPER_SCRIPT, 'configure-shell', omarchyDir, 'shell.json'], { timeout: 2000 });
  execFileSync('python3', [HELPER_SCRIPT, 'unconfigure-shell', omarchyDir, 'shell.json'], { timeout: 2000 });

  // Assert they are still FIFOs (not replaced or corrupted)
  assert.ok(fs.lstatSync(hyprFifo).isFIFO());
  assert.ok(fs.lstatSync(shellFifo).isFIFO());

  // Cleanup
  fs.rmSync(tmpDir, { recursive: true, force: true });
});

test('Configuration: Descriptor-safe modification and idempotency of config files', () => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'alcalc-conf-test-'));

  // Test Hyprland config
  const hyprDir = path.join(tmpDir, 'hypr');
  fs.mkdirSync(hyprDir);
  const hyprFile = path.join(hyprDir, 'hyprland.lua');
  fs.writeFileSync(hyprFile, '-- Hyprland Configuration\n');

  execFileSync('python3', [HELPER_SCRIPT, 'configure-hypr', hyprDir, 'hyprland.lua']);
  const hyprContent = fs.readFileSync(hyprFile, 'utf-8');
  assert.ok(hyprContent.includes('o.window("alcalc", { float = true })'));

  // Idempotent: second run does not duplicate rule
  execFileSync('python3', [HELPER_SCRIPT, 'configure-hypr', hyprDir, 'hyprland.lua']);
  const hyprContent2 = fs.readFileSync(hyprFile, 'utf-8');
  assert.equal(hyprContent, hyprContent2);

  // Test Omarchy shell.json config
  const omarchyDir = path.join(tmpDir, 'omarchy');
  fs.mkdirSync(omarchyDir);
  const shellFile = path.join(omarchyDir, 'shell.json');
  fs.writeFileSync(shellFile, JSON.stringify({ bar: { layout: { right: [{ id: 'clock' }] } } }, null, 2));

  // Configure shell
  execFileSync('python3', [HELPER_SCRIPT, 'configure-shell', omarchyDir, 'shell.json']);
  let shellData = JSON.parse(fs.readFileSync(shellFile, 'utf-8'));
  assert.equal(shellData.bar.layout.right[0].id, 'dorneles.alcalc');
  assert.equal(shellData.bar.layout.right[1].id, 'clock');

  // Idempotent: second run does not duplicate plugin
  execFileSync('python3', [HELPER_SCRIPT, 'configure-shell', omarchyDir, 'shell.json']);
  shellData = JSON.parse(fs.readFileSync(shellFile, 'utf-8'));
  assert.equal(shellData.bar.layout.right.filter(i => i.id === 'dorneles.alcalc').length, 1);

  // Unconfigure shell
  execFileSync('python3', [HELPER_SCRIPT, 'unconfigure-shell', omarchyDir, 'shell.json']);
  shellData = JSON.parse(fs.readFileSync(shellFile, 'utf-8'));
  assert.equal(shellData.bar.layout.right.filter(i => (i.id || i) === 'dorneles.alcalc').length, 0);
  assert.equal(shellData.bar.layout.right[0].id, 'clock');

  // Cleanup
  fs.rmSync(tmpDir, { recursive: true, force: true });
});

test('Configuration Integrity: CAS revalidation detects concurrent edits and avoids silent overwriting', () => {
  const pyCode = `
import sys, os, importlib.util
spec = importlib.util.spec_from_file_location("alcalc_state", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

import tempfile
with tempfile.TemporaryDirectory() as td:
    cfg_file = os.path.join(td, "test.conf")
    with open(cfg_file, "w") as f:
        f.write("INITIAL_CONTENT\\n")
    
    attempts = [0]
    def concurrent_edit_updater(content):
        attempts[0] += 1
        if attempts[0] == 1:
            # Simulate a concurrent user edit in the file before commit
            with open(cfg_file, "w") as f2:
                f2.write("CONCURRENT_USER_EDIT\\n")
        return content + "ALCALC_ADDITION\\n"
    
    res = mod.safe_update_config(td, "test.conf", concurrent_edit_updater)
    assert res is True, "safe_update_config should succeed after retry"
    assert attempts[0] == 2, f"Expected 2 attempts due to CAS retry, got {attempts[0]}"
    
    with open(cfg_file, "r") as f:
        final_content = f.read()
    assert "CONCURRENT_USER_EDIT" in final_content, "Concurrent user edit must not be overwritten"
    assert "ALCALC_ADDITION" in final_content, "New addition must be present in file"
`;
  execFileSync('python3', ['-c', pyCode, HELPER_SCRIPT]);
});

test('Configuration Integrity: CAS revalidation detects concurrent inode replacement', () => {
  const pyCode = `
import sys, os, importlib.util
spec = importlib.util.spec_from_file_location("alcalc_state", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

import tempfile
with tempfile.TemporaryDirectory() as td:
    cfg_file = os.path.join(td, "test.conf")
    with open(cfg_file, "w") as f:
        f.write("INITIAL_CONTENT\\n")
    
    attempts = [0]
    def concurrent_replace_updater(content):
        attempts[0] += 1
        if attempts[0] == 1:
            # Simulate atomic rename/replacement by external editor (new inode)
            tmp_other = os.path.join(td, "other.tmp")
            with open(tmp_other, "w") as f_other:
                f_other.write("EXTERNAL_EDITOR_REPLACE\\n")
            os.replace(tmp_other, cfg_file)
        return content + "ALCALC_ADDITION\\n"
    
    res = mod.safe_update_config(td, "test.conf", concurrent_replace_updater)
    assert res is True, "safe_update_config should succeed after CAS retry on inode change"
    assert attempts[0] == 2, f"Expected 2 attempts due to inode change, got {attempts[0]}"
    
    with open(cfg_file, "r") as f:
        final_content = f.read()
    assert "EXTERNAL_EDITOR_REPLACE" in final_content
    assert "ALCALC_ADDITION" in final_content
`;
  execFileSync('python3', ['-c', pyCode, HELPER_SCRIPT]);
});


