import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '..');
process.chdir(root);

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    encoding: 'utf8', maxBuffer: 8 * 1024 * 1024, timeout: 120_000, ...options,
  });
  assert.ifError(result.error);
  return result;
}

const inventory = run('git', ['ls-files', '--cached', '--others', '--exclude-standard', '-z']);
assert.equal(inventory.status, 0, inventory.stderr);
const files = [...new Set(inventory.stdout.split('\0').filter(Boolean))];
const candidates = new Set(files);
for (const required of ['README.md', 'CONTRIBUTING.md', 'MVP_SPEC.md', 'project.yml', 'Package.swift', '.github/workflows/ci.yml']) {
  assert(candidates.has(required), `Missing publishable file: ${required}`);
}

const excludedFixtures = [
  'build/check.log', 'Sources/BobPlan/.build/check.log', '.swiftpm/configuration/check.json',
  'Bob.xcodeproj/project.pbxproj', 'Bob/Info.plist', 'Bob.xcodeproj/xcuserdata/check',
  '.env', '.env.production', 'signing/private.p8', 'signing/certificate.p12',
  'signing/profile.mobileprovision', '.unlazy/github/GATES.md', 'GATES.md', 'PLAN.md',
];
const ignored = run('git', ['check-ignore', '--no-index', '--stdin', '-z'], { input: excludedFixtures.join('\0') + '\0' });
assert.equal(ignored.status, 0, ignored.stderr);
assert.deepEqual(new Set(ignored.stdout.split('\0').filter(Boolean)), new Set(excludedFixtures), 'Ignore rules failed to exclude a local artifact fixture');
const trackedIgnored = run('git', ['ls-files', '--cached', '--ignored', '--exclude-standard', '-z']);
assert.equal(trackedIgnored.status, 0, trackedIgnored.stderr);
assert.equal(trackedIgnored.stdout, '', 'Ignored artifacts are already tracked');

let links = 0;
let bytes = 0;
for (const file of files) {
  const stat = lstatSync(file);
  assert(stat.isFile(), `Only regular files are expected: ${file}`);
  assert(stat.size < 10 * 1024 * 1024, `Unexpected large file: ${file}`);
  bytes += stat.size;
  if (!/\.(?:md|swift|mjs|yml|yaml|sh|json)$/.test(file)) continue;
  const source = readFileSync(file, 'utf8');
  assert(!/\/(?:Users|home)\/[A-Za-z0-9._-]+\//.test(source), `Machine-specific home path in ${file}`);
  if (!file.endsWith('.md')) continue;
  const prose = source.replace(/```[\s\S]*?```/g, '');
  const targets = [
    ...[...prose.matchAll(/!?\[[^\]\n]*\]\(([^)\s]+)\)/g)].map(match => match[1]),
    ...[...prose.matchAll(/(?:src|href)="([^"]+)"/g)].map(match => match[1]),
  ];
  for (const target of targets) {
    if (/^(?:[a-z][a-z\d+.-]*:|#)/i.test(target)) continue;
    const relative = decodeURIComponent(target.split('#')[0]);
    const resolved = path.posix.normalize(path.posix.join(path.posix.dirname(file), relative));
    assert(candidates.has(resolved), `Unpublished link target in ${file}: ${target}`);
    links++;
  }
}

const scratch = mkdtempSync(path.join(os.tmpdir(), 'bob-repository-check-'));
try {
  const control = path.join(scratch, 'control');
  mkdirSync(control);
  const syntheticToken = 'ghp_' + 'abcDEF0123456789GHIjklMNOPqrstUVWXyz7';
  writeFileSync(path.join(control, 'fixture.txt'), `github_token = "${syntheticToken}"\n`);
  const negative = run('gitleaks', ['dir', control, '--redact', '--no-banner']);
  assert.equal(negative.status, 1, 'Gitleaks did not detect the synthetic token control');

  const exported = path.join(scratch, 'candidate');
  mkdirSync(exported);
  for (const file of files) {
    const destination = path.join(exported, file);
    mkdirSync(path.dirname(destination), { recursive: true });
    cpSync(file, destination);
  }
  const scan = run('gitleaks', ['dir', exported, '--redact', '--no-banner']);
  assert.equal(scan.status, 0, `Secret scan failed:\n${scan.stdout}${scan.stderr}`);
} finally {
  rmSync(scratch, { recursive: true, force: true });
}

console.log(`BOB REPOSITORY VERIFIED: ${files.length} files, ${(bytes / 1024 / 1024).toFixed(2)} MiB, ${links} local links; ignore fixtures and secret-scan control passed`);
