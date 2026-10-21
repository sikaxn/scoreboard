#!/usr/bin/env python3
"""Capture real multi-simulator demo footage with XCTest, then create narration/edit assets."""
from __future__ import annotations
import argparse
import base64
import io
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import threading
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = 'IronMaple.smartScoreboard'
ENV = dict(os.environ, DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer')
ZH_CAPTURE_OVERRIDES={
    'Smart Scoreboard':'聪明的计分板',
    'Allow This Device to Control':'允许此设备控制',
    'On the operator device, open Settings > Integration > Remote Display & Control, then enter this display\'s pairing code.':'在操作设备上打开“设置 > 集成 > 远程显示与控制”，然后输入此屏幕的配对码。',
    'LAN Only':'仅局域网',
    'Nearby':'附近设备',
    'Same Wi-Fi / LAN':'同一 Wi-Fi／局域网',
    'Nearby + LAN':'附近设备与局域网',
    'Uses the local network and also allows Apple peer-to-peer Wi-Fi for nearby devices.':'使用局域网，并允许附近的 Apple 设备通过点对点 Wi-Fi 连接。'
}

def run(*args, **kw):
    return subprocess.run(list(map(str, args)), env=ENV, check=True, **kw)

def output(*args):
    return run(*args, capture_output=True, text=True).stdout.strip()

SCENE_TESTS={
    'test01Result':'01-result', 'test02Setup':'02-game-setup', 'test03LiveControls':'03-live-controls',
    'test04AudienceViews':'04-audience-views','test05PlayersAndStations':'05-players-and-stations',
    'test06Sports':'06-sports','test07RemoteDisplayAndControl':'07-remote-display-control',
    'test08Livestream':'08-livestream-tools','test09AppearanceAndSound':'09-appearance-sound',
    'test10LibraryAndLogs':'10-library-logs'}

def reconcile_results(result,folder):
    if not result.exists(): return
    log=folder/('tests-'+result.stem.removeprefix('capture-')+'.log')
    if not (result/'Info.plist').exists():
        # A stopped session can leave a readable console log but an unfinalized
        # result bundle. Keep the actual XCTest verdict and its evidence source.
        if not log.exists():raise RuntimeError(f'No finalized result bundle or test log: {result}')
        verdicts=re.findall(r"Test Case '-\[.*?DemoVideoUITests (test\w+)\]' (passed|failed) ",log.read_text())
        for name,verdict in verdicts:
            if name not in SCENE_TESTS:continue
            path=folder/'raw'/SCENE_TESTS[name]/'capture.json'
            if not path.exists():continue
            data=json.loads(path.read_text());passed=verdict=='passed'
            data.update(xctest_result='Passed' if passed else 'Failed',result_bundle=str(result),
                result_bundle_complete=False,xctest_log=str(log),evidence_source='XCTest console log; result bundle is incomplete',
                passed=data.get('passed',False) and passed)
            path.write_text(json.dumps(data,indent=2)+'\n')
        if not verdicts:raise RuntimeError(f'No XCTest verdicts in {log}')
        return
    report=json.loads(output('xcrun','xcresulttool','get','test-results','tests','--path',result,'--compact'))
    def visit(node):
        if node.get('nodeType')=='Test Case':
            name=node['name'].removesuffix('()')
            if name in SCENE_TESTS:
                path=folder/'raw'/SCENE_TESTS[name]/'capture.json'
                if path.exists():
                    data=json.loads(path.read_text())
                    data['xctest_result']=node.get('result')
                    data['result_bundle']=str(result)
                    data['result_bundle_complete']=True
                    data['passed']=data.get('passed',False) and node.get('result')=='Passed'
                    path.write_text(json.dumps(data,indent=2)+'\n')
        for child in node.get('children',[]):visit(child)
    for node in report.get('testNodes',[]):visit(node)

def localize_capture_source(source: Path):
    """Use the real app localization while resolving XCTest's visible labels."""
    catalog_data=json.loads((ROOT/'smartScoreboard/Localizable.xcstrings').read_text())
    catalog=catalog_data['strings']
    # Recording-only localization corrections, including the user-supplied name.
    for key,value in ZH_CAPTURE_OVERRIDES.items():
        catalog.setdefault(key,{}).setdefault('localizations',{})['zh-Hans']={'stringUnit':{'state':'translated','value':value}}
    (source/'Localizable.xcstrings').write_text(json.dumps(catalog_data,ensure_ascii=False,indent=2)+'\n')
    remote=source/'smartScoreboard/RemoteScoreboardView.swift'
    text=remote.read_text().replace('private var appDisplayName: String {\n        "Smart Scoreboard"',
        'private var appDisplayName: String {\n        localizedRemoteDisplayString("Smart Scoreboard")')
    remote.write_text(text)
    translations={key:value['localizations']['zh-Hans']['stringUnit']['value'] for key,value in catalog.items()
                  if 'stringUnit' in value.get('localizations',{}).get('zh-Hans',{})}
    translations['Allow']='允许'
    translations['Test: Classic Buzzer']=translations['Test']+': '+translations['Classic Buzzer']
    table=json.dumps(translations,ensure_ascii=False)
    swift='''import Foundation

nonisolated enum DemoL10n {
    private static let strings = (try! JSONSerialization.jsonObject(with: Data(#"""
'''+table+'''
"""#.utf8))) as! [String: String]
    static func label(_ key: String) -> String { strings[key] ?? key }
}
'''
    tests=source/'smartScoreboardUITests'
    (tests/'DemoL10n.swift').write_text(swift)
    for name in ['UITestCase.swift','DemoVideoUITests.swift']:
        path=tests/name;text=path.read_text()
        text=re.sub(r'\.buttons\[("[^"\n]*")\]',r'.buttons[DemoL10n.label(\1)]',text)
        text=text.replace('.buttons[title]','.buttons[DemoL10n.label(title)]').replace('.buttons[label]','.buttons[DemoL10n.label(label)]')
        text=text.replace('"label == %@", title','"label == %@", DemoL10n.label(title)')
        text=text.replace('["Go to Control Board", "Back to Live Board"]','["Go to Control Board", "Back to Live Board"].map(DemoL10n.label)')
        text=text.replace('"(en)", "-AppleLocale", "en_US"','"(zh-Hans)", "-AppleLocale", "zh_CN"')
        text=text.replace("\"label BEGINSWITH 'Default'\"",'"label BEGINSWITH %@", DemoL10n.label("Default")')
        text=text.replace("\"label BEGINSWITH 'Timer Start'\"",'"label BEGINSWITH %@", DemoL10n.label("Timer Start")')
        text=text.replace("\"label == 'Back to Game'\"",'"label == %@", DemoL10n.label("Back to Game")')
        text=text.replace("identifier BEGINSWITH 'action.Next '","identifier BEGINSWITH 'action.下一'")
        text=text.replace("OR label CONTAINS[c] 'dismiss keyboard'","OR label CONTAINS[c] 'dismiss keyboard' OR label CONTAINS '隐藏键盘' OR label CONTAINS '收起键盘'")
        text=text.replace('Community Cup Final','社区杯决赛').replace('Community Cup','社区杯')
        text=text.replace('"North"','"北方队"').replace('"South"','"南方队"').replace('\\"North\\"','\\"北方队\\"').replace('\\"South\\"','\\"南方队\\"')
        text=text.replace('Alex Morgan','王晨')
        path.write_text(text)
    preferences=source/'smartScoreboard/ScoreboardPreferences.swift';text=preferences.read_text()
    replacements={'Alex Morgan':'王晨','Jordan Lee':'李博','Taylor Chen':'张宇','Sam Rivera':'陈浩','Casey Park':'刘洋','Jamie Brooks':'赵杰',
                  'Riley James':'周宁','Avery Kim':'吴迪','Drew Wilson':'徐航','Quinn Davis':'孙凯','Morgan Reed':'马骁','Cameron Bell':'何俊'}
    for english,chinese in replacements.items():text=text.replace(english,chinese)
    preferences.write_text(text)
    localized=source/'smartScoreboard/zh-Hans.lproj';localized.mkdir(exist_ok=True)
    (localized/'InfoPlist.strings').write_text('"CFBundleDisplayName" = "聪明的计分板";\n')

def stage(folder: Path,language='en'):
    source = folder / 'source'
    if source.exists(): shutil.rmtree(source)
    shutil.copytree(ROOT / 'smartScoreboard', source, ignore=shutil.ignore_patterns('build', 'DerivedData', 'xcuserdata'))
    shutil.copy2(ROOT / 'scripts/demo_video/DemoVideoUITests.swift', source / 'smartScoreboardUITests')
    helpers=source/'smartScoreboardUITests/UITestCase.swift'
    text=helpers.read_text().replace('        element.tap()', '        DemoTouch.record(element, window: mainWindow)\n        element.tap()')
    text=text.replace('        field.coordinate(withNormalizedOffset:', '        DemoTouch.record(field, window: mainWindow, at: CGPoint(x: field.frame.minX + field.frame.width * 0.99, y: field.frame.midY))\n        field.coordinate(withNormalizedOffset:')
    text=text.replace('        action.coordinate(withNormalizedOffset:', '        DemoTouch.record(action, window: mainWindow)\n        action.coordinate(withNormalizedOffset:')
    helpers.write_text(text)
    preferences = source / 'smartScoreboard/ScoreboardPreferences.swift'
    text = preferences.read_text()
    text = text.replace('store.isSoundEnabled = false', '''store.isSoundEnabled = false
        if ProcessInfo.processInfo.environment["SCOREBOARD_DEMO_CAPTURE"] == "1" {
            store.homeScore = 42; store.guestScore = 38
            store.theme = .night
            store.setPlayerTrackingEnabled(true)
            store.setRosterSizePerTeam(6)
            let homeNames = ["Alex Morgan", "Jordan Lee", "Taylor Chen", "Sam Rivera", "Casey Park", "Jamie Brooks"]
            let guestNames = ["Riley James", "Avery Kim", "Drew Wilson", "Quinn Davis", "Morgan Reed", "Cameron Bell"]
            for i in store.homeRoster.players.indices { store.homeRoster.players[i].name = homeNames[i % homeNames.count] }
            for i in store.guestRoster.players.indices { store.guestRoster.players[i].name = guestNames[i % guestNames.count] }
        }''')
    # Simple typographic demo identities; no logos are downloaded or taken from real teams.
    from PIL import Image, ImageDraw, ImageFont
    logo_code = []
    identities=[('home', '北' if language=='zh-Hans' else 'N', '#ee6070'),
                ('guest', '南' if language=='zh-Hans' else 'S', '#60b0ff'),
                ('event', '杯' if language=='zh-Hans' else 'CUP', '#66d8c2')]
    for kind, initials, color in identities:
        image = Image.new('RGBA', (256, 256))
        draw = ImageDraw.Draw(image); draw.rounded_rectangle((8,8,248,248), 52, fill=color)
        font = ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc',154,index=1) if language=='zh-Hans' else ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Bold.ttf', 86 if kind == 'event' else 154)
        box = draw.textbbox((0,0), initials, font=font)
        draw.text(((256-(box[2]-box[0]))/2, (256-(box[3]-box[1]))/2-box[1]), initials, font=font, fill='#091523')
        stream=io.BytesIO(); image.save(stream,format='PNG'); encoded=base64.b64encode(stream.getvalue()).decode()
        if kind == 'event':
            logo_code.append(f'if let data = Data(base64Encoded: "{encoded}") {{ store.setEventLogoImage(EventLogoImage(sourceName: "Community Cup.png", pixelWidth: 256, pixelHeight: 256, byteCount: data.count, data: data)) }}')
        else:
            logo_code.append(f'if let data = Data(base64Encoded: "{encoded}") {{ store.setTeamLogoImage(TeamLogoImage(sourceName: "{initials}.png", pixelWidth: 256, pixelHeight: 256, byteCount: data.count, data: data), for: .{kind}) }}')
    text = text.replace('store.homeScore = 42; store.guestScore = 38', 'store.homeScore = 42; store.guestScore = 38\n' + '\n'.join(logo_code))
    preferences.write_text(text)
    receiver = source / 'smartScoreboard/RemoteScoreboardView.swift'
    text = receiver.read_text().replace('acquireReceiverIfNeeded()', '''acquireReceiverIfNeeded()
            #if DEBUG && targetEnvironment(simulator)
            if ProcessInfo.processInfo.environment["SCOREBOARD_DEMO_RECEIVER"] == "1" {
                Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
                    Task { @MainActor in
                        let receiver = ScoreboardRemoteDisplayReceiver.shared
                        var info: [String: Any] = ["code": receiver.pairingCode, "displayID": receiver.displayID,
                            "status": String(describing: receiver.status)]
                        if let state = receiver.state {
                            info["homeScore"] = state.teams.home.score
                            info["guestScore"] = state.teams.guest.score
                            info["clock"] = state.clocks.gameClockSeconds
                            info["wallTime"] = Date().timeIntervalSince1970
                            info["projectedClock"] = RemoteScoreboardProjection(state: state,
                                lastReceivedAt: receiver.lastReceivedAt, masterClockOffset: receiver.masterClockOffset,
                                now: Date()).gameClockSeconds
                            info["clockOffset"] = receiver.masterClockOffset ?? 0
                            info["generatedAt"] = state.generatedAtUnixTime ?? 0
                        }
                        if let data = try? JSONSerialization.data(withJSONObject: info) {
                            try? data.write(to: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("demo-receiver.json"), options: .atomic)
                            let history=FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("demo-receiver-history.jsonl")
                            if !FileManager.default.fileExists(atPath: history.path) { FileManager.default.createFile(atPath: history.path, contents: nil) }
                            if let file=try? FileHandle(forWritingTo: history) {
                                file.seekToEndOfFile(); file.write(data); file.write(Data([10])); try? file.close()
                            }
                        }
                    }
                }
            }
            #endif''', 1)
    receiver.write_text(text)
    transport=source/'smartScoreboard/ScoreboardRemoteDisplay.swift'
    text=transport.read_text()
    needle='        guard canAcceptCodePairing || canAcceptTrustedReconnect else {'
    diagnostic='''        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.environment["SCOREBOARD_DEMO_RECEIVER"] == "1" {
            let detail: [String: Any] = ["entered": request.pairingCode ?? "", "expected": pairingCode,
                "displayMatches": isDisplayMatch, "secretPresent": hasPairingSecret,
                "canAcceptCode": canAcceptCodePairing, "receiverState": String(describing: receiverState)]
            if let data = try? JSONSerialization.data(withJSONObject: detail) {
                try? data.write(to: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("demo-pair-debug.json"), options: .atomic)
            }
        }
        #endif
'''
    transport.write_text(text.replace(needle,diagnostic+needle))
    plan = source / 'TestPlans/AllUI.xctestplan'
    data = json.loads(plan.read_text()); data['defaultOptions']['maximumTestExecutionTimeAllowance'] = 900
    plan.write_text(json.dumps(data, indent=2))
    if language=='zh-Hans':localize_capture_source(source)
    return source / 'smartScoreboard.xcodeproj'

class Capture:
    def __init__(self, folder, operator, receiver, app, controller, language='en'):
        self.folder, self.operator, self.receiver, self.app = folder, operator, receiver, app
        self.controller=controller
        self.language=language
        self.active = None; self.processes = []; self.lock = threading.Lock()
        self.container = Path(output('xcrun', 'simctl', 'get_app_container', receiver, BUNDLE, 'data'))
        self.controller_container=Path(output('xcrun','simctl','get_app_container',controller,BUNDLE,'data'))

    def receiver_info(self, control=False):
        path = (self.controller_container if control else self.container) / 'Documents/demo-receiver.json'
        try:
            data=json.loads(path.read_text())
            diagnostic=path.with_name('demo-pair-debug.json')
            if diagnostic.exists(): data['pairDebug']=json.loads(diagnostic.read_text())
            return data
        except (OSError, ValueError): return {}

    def restart_receiver(self, control=False):
        device=self.controller if control else self.receiver
        container=self.controller_container if control else self.container
        subprocess.run(['xcrun', 'simctl', 'terminate', device, BUNDLE], env=ENV, capture_output=True)
        (container / 'Documents/demo-receiver.json').unlink(missing_ok=True)
        (container / 'Documents/demo-pair-debug.json').unlink(missing_ok=True)
        (container / 'Documents/demo-receiver-history.jsonl').unlink(missing_ok=True)
        env = dict(ENV, SIMCTL_CHILD_SCOREBOARD_UI_TEST_ID=str(uuid.uuid4()),
                   SIMCTL_CHILD_SCOREBOARD_UI_TEST_SCENARIO='remote', SIMCTL_CHILD_SCOREBOARD_DEMO_RECEIVER='1')
        subprocess.run(['xcrun', 'simctl', 'launch', device, BUNDLE, '-AppleLanguages', f'({self.language})', '-AppleLocale', 'zh_CN' if self.language=='zh-Hans' else 'en_US'], env=env, check=True, capture_output=True)
        for _ in range(80):
            info = self.receiver_info(control)
            if info.get('code'):
                time.sleep(2)
                return self.receiver_info(control)
            time.sleep(.25)
        raise RuntimeError('Receiver did not publish its pairing code')

    def begin(self, identifier):
        if self.active: self.end(False)
        # Relaunch an already-running receiver to bring it to the foreground.
        # Network telemetry can remain live while tvOS shows its home screen.
        subprocess.run(['xcrun','simctl','launch',self.receiver,BUNDLE],env=ENV,check=True,capture_output=True)
        directory = self.folder / 'raw' / identifier; directory.mkdir(parents=True, exist_ok=True)
        self.active = dict(id=identifier, language=self.language, started=time.time(), marks=[], touches=[], directory=str(directory),
            devices={'operator':{'udid':self.operator,'platform':'iPadOS'},
                     'audience':{'udid':self.receiver,'platform':'tvOS'}})
        devices=[('operator', self.operator), ('audience', self.receiver)]
        if identifier=='07-remote-display-control':
            devices.append(('controller',self.controller))
            self.active['devices']['controller']={'udid':self.controller,'platform':'iPadOS'}
        for label, device in devices:
            log = (directory / f'{label}-capture.log').open('w')
            process = subprocess.Popen(['xcrun', 'simctl', 'io', device, 'recordVideo', '--codec=h264', '--force', str(directory / f'{label}.mov')], env=ENV, stdout=log, stderr=log)
            self.processes.append((process, log))
        time.sleep(1)
        print(f'RECORD {identifier}', flush=True)
        return {'ok': True}

    def touch(self,query):
        if self.active:
            self.active['touches'].append(dict(seconds=round(time.time()-self.active['started'],4),
                device=query.get('device','operator'),x=float(query['x']),y=float(query['y']),label=query.get('label','')))
        return {'ok':True}

    def mark(self, name, details=None):
        if not self.active: raise RuntimeError('No scene recording')
        directory = Path(self.active['directory'])
        index = len(self.active['marks'])
        mark = dict(name=name, seconds=round(time.time() - self.active['started'], 3))
        if details and details.get('operatorClock'): mark['operator_clock']=details['operatorClock']
        self.active['marks'].append(mark)
        devices=[('operator', self.operator), ('audience', self.receiver)]
        if self.active['id']=='07-remote-display-control': devices.append(('controller',self.controller))
        for label, device in devices:
            run('xcrun', 'simctl', 'io', device, 'screenshot', directory / f'{index:02}-{name}-{label}.png', stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.active['receiver'] = self.receiver_info()
        (directory / 'capture.json').write_text(json.dumps(self.active, indent=2))
        print(f'  {name}', flush=True)
        return {'ok': True}

    def end(self, passed):
        for process, _ in self.processes:
            process.send_signal(signal.SIGINT)
        for process, log in self.processes:
            try: process.wait(timeout=30)
            except subprocess.TimeoutExpired: process.terminate(); process.wait(timeout=5)
            log.close()
        self.processes = []
        if self.active:
            self.active.update(passed=passed, duration=round(time.time() - self.active['started'], 3))
            (Path(self.active['directory']) / 'capture.json').write_text(json.dumps(self.active, indent=2))
            history=self.container/'Documents/demo-receiver-history.jsonl'
            if history.exists(): shutil.copy2(history,Path(self.active['directory'])/'receiver-telemetry.jsonl')
            print(f'END {self.active["id"]}: {passed}', flush=True)
            self.active = None
        return {'ok': True}

    def web(self):
        browser = Path('/Users/nathan/Library/Caches/ms-playwright/chromium_headless_shell-1228/chrome-headless-shell-mac-arm64/chrome-headless-shell')
        if not browser.exists(): raise RuntimeError('Local capture browser is unavailable')
        directory = self.folder / 'web'; directory.mkdir(exist_ok=True)
        pages=[]
        for name, route in [('scoreboard','/demo/scoreboard'), ('overlay','/demo/obs'), ('commentator','/commentator')]:
            result=run('node',ROOT/'scripts/demo_video/capture_browser.mjs',browser,
                'http://127.0.0.1:5516'+route,directory,name,self.language,
                capture_output=True,text=True,timeout=15)
            pages.append({'page':name,'url':'http://127.0.0.1:5516'+route,'screenshot':name+'.png',
                **json.loads(result.stdout)})
        (directory/'capture.json').write_text(json.dumps(pages,indent=2)+'\n')
        return {'ok':True,'pages':pages}

    def remote_action(self):
        with (self.folder / 'remote-control-test.log').open('w') as log:
            run('xcodebuild','test-without-building','-project',self.folder/'source/smartScoreboard.xcodeproj',
                '-scheme','smartScoreboardUITests','-destination',f'platform=iOS Simulator,id={self.controller}',
                '-derivedDataPath',self.folder/'DerivedData','-parallel-testing-enabled','NO',
                '-only-testing:smartScoreboardUITests/DemoReceiverUITests/testAuthorizedRemoteScoring',
                '-resultBundlePath',self.folder/f'remote-control-{time.strftime("%Y%m%d-%H%M%S")}.xcresult',
                'CODE_SIGNING_ALLOWED=NO',stdout=log,stderr=subprocess.STDOUT,timeout=50)
        info=self.receiver_info()
        if info.get('homeScore') != 46: raise RuntimeError('Remote scoring did not reach the Apple TV')
        return {'ok':True,**info}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'DemoVideo')
    parser.add_argument('--language',choices=['en','zh-Hans'],default='en')
    parser.add_argument('--operator', default='2821010D-98C2-4F11-9F7F-1A622DFC64AF')
    parser.add_argument('--receiver', default='5C699294-AA55-4F2F-AB25-C7E03B374AB7',help='Apple TV simulator UDID')
    parser.add_argument('--controller', default='DF6CFCE9-F588-4A72-A477-FF47B78E3C79',help='Second iPad simulator UDID')
    parser.add_argument('--only', action='append', help='XCTest method; repeat to select several')
    parser.add_argument('--skip-build', action='store_true')
    parser.add_argument('--skip', action='append', default=[], help='Skip a capture method already completed')
    args = parser.parse_args(); folder = args.output.resolve(); folder.mkdir(parents=True, exist_ok=True)
    project = folder / 'source/smartScoreboard.xcodeproj'
    derived = folder / 'DerivedData'
    if not args.skip_build:
        project = stage(folder,args.language)
        with (folder / 'build.log').open('w') as log:
            run('xcodebuild', 'build-for-testing', '-project', project, '-scheme', 'smartScoreboardUITests',
                '-destination', f'platform=iOS Simulator,id={args.operator}', '-derivedDataPath', derived,
                'CODE_SIGNING_ALLOWED=NO', stdout=log, stderr=subprocess.STDOUT)
    app = derived / 'Build/Products/Debug-iphonesimulator/smartScoreboard.app'
    tv_derived=folder/'DerivedDataTV'
    tv_app=tv_derived/'Build/Products/Debug-appletvsimulator/smartScoreboard.app'
    if not args.skip_build or not (tv_app/'smartScoreboard.debug.dylib').exists():
        with (folder/'build-tv.log').open('w') as log:
            run('xcodebuild','build','-project',project,'-scheme','smartScoreboard','-configuration','Debug',
                '-sdk','appletvsimulator','-destination','generic/platform=tvOS Simulator','-derivedDataPath',tv_derived,
                'CODE_SIGNING_ALLOWED=NO','ARCHS=arm64','ONLY_ACTIVE_ARCH=YES',stdout=log,stderr=subprocess.STDOUT)
    for device in [args.operator, args.receiver, args.controller]:
        devices = json.loads(output('xcrun', 'simctl', 'list', 'devices', '--json'))
        detail = next(d for group in devices['devices'].values() for d in group if d['udid'] == device)
        if detail['state'] != 'Booted': run('xcrun', 'simctl', 'boot', device)
        run('xcrun', 'simctl', 'bootstatus', device, '-b', stdout=subprocess.DEVNULL)
        run('xcrun', 'simctl', 'install', device, tv_app if device==args.receiver else app)
        if device!=args.receiver:
            run('xcrun', 'simctl', 'status_bar', device, 'override', '--time', '9:41', '--dataNetwork', 'wifi', '--wifiMode', 'active', '--wifiBars', '3', '--batteryState', 'charged', '--batteryLevel', '100')
            run('xcrun', 'devicectl', 'device', 'orientation', 'set', '--device', device, 'landscapeLeft', stdout=subprocess.DEVNULL)
    capture = Capture(folder, args.operator, args.receiver, app, args.controller,args.language)
    capture.restart_receiver()
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *a): pass
        def do_GET(self):
            parsed = urlparse(self.path); query = {k: v[0] for k,v in parse_qs(parsed.query).items()}
            try:
                # The second XCTest runner reports touches while its command is in progress.
                if parsed.path == '/touch':
                    data=capture.touch(query)
                    self.send_response(200); self.send_header('Content-Type','application/json'); self.end_headers()
                    self.wfile.write(json.dumps(data).encode()); return
                with capture.lock:
                    if parsed.path == '/begin': data = capture.begin(query['id'])
                    elif parsed.path == '/mark': data = capture.mark(query['name'],query)
                    elif parsed.path == '/end': data = capture.end(query.get('passed') == 'true')
                    elif parsed.path == '/receiver': data = capture.restart_receiver()
                    elif parsed.path == '/control-receiver': data = capture.restart_receiver(True)
                    elif parsed.path == '/status': data = capture.receiver_info()
                    elif parsed.path == '/control-status': data = capture.receiver_info(True)
                    elif parsed.path == '/web': data = capture.web()
                    elif parsed.path == '/remote-action': data = capture.remote_action()
                    else: raise RuntimeError('Unknown route')
                self.send_response(200)
            except Exception as error:
                data = {'error': str(error)}; self.send_response(500)
            self.send_header('Content-Type', 'application/json'); self.end_headers()
            self.wfile.write(json.dumps(data).encode())
    server = ThreadingHTTPServer(('127.0.0.1', 18765), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    stamp = time.strftime('%Y%m%d-%H%M%S')
    result = folder / f'capture-{stamp}.xcresult'
    base_selection='smartScoreboardUITests/DemoVideoUITests'
    selections=[base_selection+'/'+method for method in args.only] if args.only else [base_selection]
    try:
        with (folder / f'tests-{stamp}.log').open('w') as log:
            run('xcodebuild', 'test-without-building', '-project', project, '-scheme', 'smartScoreboardUITests',
                '-destination', f'platform=iOS Simulator,id={args.operator}', '-derivedDataPath', derived,
                '-parallel-testing-enabled', 'NO', *['-only-testing:'+selection for selection in selections],
                '-resultBundlePath', result, *['-skip-testing:smartScoreboardUITests/DemoVideoUITests/' + name for name in args.skip], 'CODE_SIGNING_ALLOWED=NO', stdout=log, stderr=subprocess.STDOUT)
    finally:
        capture.end(False); server.shutdown()
        reconcile_results(result,folder)
    print(result, flush=True)

if __name__ == '__main__': main()
