import { spawnSync } from 'node:child_process';
import { readFileSync, writeFileSync, mkdirSync, readdirSync, rmSync, existsSync } from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '..');
process.chdir(root);
mkdirSync('build', { recursive: true });
const mode = process.argv[2];

function run(command, args, name) {
  const result = spawnSync(command, args, { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024, timeout: 600_000 });
  const output = (result.stdout ?? '') + (result.stderr ?? '');
  writeFileSync(`build/${name}.log`, output);
  if (result.status !== 0 || result.error) {
    const decisive = output.split('\n').filter(line => /error:|warning:|failed|failure|Assertion|Test Case/.test(line));
    console.error(decisive.length ? decisive.slice(-30).join('\n') : output.split('\n').slice(-20).join('\n'));
    throw new Error(`${command} failed: ${result.error?.message ?? result.status}`);
  }
  return output;
}

const common = ['-project', 'Bob.xcodeproj', '-scheme', 'Bob', '-derivedDataPath', 'build/DerivedData', 'CODE_SIGNING_ALLOWED=NO'];
if (mode === 'build' || mode === 'device-build') {
  run('xcodegen', ['generate'], 'project-generation');
  const destination = mode === 'build' ? 'generic/platform=iOS Simulator' : 'generic/platform=iOS';
  const output = run('xcodebuild', ['build', ...common, '-destination', destination], mode);
  assert(!/\bwarning:|\berror:/.test(output), 'Build emitted warnings or errors; inspect its log.');
  assert(output.includes('** BUILD SUCCEEDED **'), 'Xcode did not report a successful build.');
  const platform = mode === 'build' ? 'iphonesimulator' : 'iphoneos';
  const bundleInfo = JSON.parse(run('plutil', ['-convert', 'json', '-o', '-', `build/DerivedData/Build/Products/Debug-${platform}/Bob.app/Info.plist`], `${mode}-bundle-info`));
  assert.deepEqual(bundleInfo.UIDeviceFamily, [1], 'The built app must target iPhone only.');
  console.log(mode === 'build' ? 'BOB BUILD VERIFIED' : 'BOB DEVICE BUILD VERIFIED');
} else if (mode === 'ui') {
  const inventory = JSON.parse(run('xcrun', ['simctl', 'list', 'devices', 'available', '-j'], 'simulators'));
  const candidates = Object.values(inventory.devices).flat().filter(device => device.name === 'iPhone 17');
  const device = process.env.BOB_SIMULATOR_UDID ?? candidates.find(device => device.state === 'Booted')?.udid ?? candidates[0]?.udid;
  assert(device, 'Install an iPhone 17 simulator in Xcode, or set BOB_SIMULATOR_UDID.');
  const selected = Object.values(inventory.devices).flat().find(entry => entry.udid === device);
  assert(selected, 'The selected simulator is unavailable. Check BOB_SIMULATOR_UDID.');
  if (selected.state !== 'Booted') run('xcrun', ['simctl', 'boot', device], 'simulator-boot');
  run('xcrun', ['simctl', 'bootstatus', device, '-b'], 'simulator-ready');
  run('xcodegen', ['generate'], 'project-generation');
  if (existsSync('build/UITests.xcresult')) rmSync('build/UITests.xcresult', { recursive: true });
  run('xcodebuild', ['test', ...common, '-destination', `platform=iOS Simulator,id=${device}`, '-resultBundlePath', 'build/UITests.xcresult', '-parallel-testing-enabled', 'NO'], 'ui');
  const summary = JSON.parse(run('xcrun', ['xcresulttool', 'get', 'test-results', 'summary', '--path', 'build/UITests.xcresult', '--compact'], 'ui-summary'));
  assert(summary.passedTests > 0 && summary.failedTests === 0 && summary.skippedTests === 0, 'UI suite did not fully execute and pass.');
  console.log(`BOB UI VERIFIED: ${summary.passedTests} tests passed`);
} else if (mode === 'privacy') {
  function walk(folder) {
    return readdirSync(folder, { withFileTypes: true }).flatMap(entry => {
      if (entry.name.startsWith('.') || entry.name === 'build') return [];
      const file = path.join(folder, entry.name);
      return entry.isDirectory() ? walk(file) : file.endsWith('.swift') ? [file] : [];
    });
  }
  const banned = /\b(?:URLSession|NWConnection|AVCaptureMovieFileOutput|AVAssetWriter|UIImageWriteToSavedPhotosAlbum|FamilyControls|ManagedSettings|DeviceActivity)\b|https?:\/\//;
  function inspect(source) { assert(!banned.test(source), 'Unexpected network, footage recording, or paid app-blocking surface'); }
  assert.throws(() => inspect('let session = URLSession.shared'), 'Negative control failed to reject networking');
  assert.throws(() => inspect('let writer: AVAssetWriter'), 'Negative control failed to reject video recording');
  const files = [...walk('Bob'), ...walk('Sources')];
  files.forEach(file => inspect(readFileSync(file, 'utf8')));
  const plist = JSON.parse(run('plutil', ['-convert', 'json', '-o', '-', 'Bob/Info.plist'], 'privacy-info'));
  assert(plist.NSAlarmKitUsageDescription && plist.NSCameraUsageDescription, 'Missing permission explanations');
  assert(!plist.UIBackgroundModes, 'No background-mode workaround should be present');
  const privacy = JSON.parse(run('plutil', ['-convert', 'json', '-o', '-', 'Bob/PrivacyInfo.xcprivacy'], 'privacy-manifest'));
  assert.equal(privacy.NSPrivacyTracking, false);
  assert.deepEqual(privacy.NSPrivacyCollectedDataTypes, []);
  assert(!readFileSync('project.yml', 'utf8').includes('CODE_SIGN_ENTITLEMENTS'), 'Unexpected paid entitlement configuration');
  console.log(`BOB PRIVACY VERIFIED: ${files.length} Swift files audited; both negative controls rejected`);
} else {
  throw new Error('Use build, device-build, ui, or privacy');
}
