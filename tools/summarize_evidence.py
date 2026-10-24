#!/usr/bin/env python3
"""Create compact, traceable facts; APK code presence is never a runtime test."""
import json
import re
from pathlib import Path
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / 'analysis/raw'
entries = []

def methods(source, patterns, instruction_pattern, limit=36):
    lines = (RAW / source / 'bytecode.txt').read_text().splitlines()
    selected = []
    current = None
    for number, line in enumerate(lines, 1):
        if line.startswith(('CLASS ', 'METHOD ')):
            if line.startswith('METHOD ') and any(re.search(pattern, line[7:]) for pattern in patterns):
                current = {'method': line[7:], 'raw_line': number, 'instructions': []}
                selected.append(current)
            else:
                current = None
        elif current is not None and re.search(instruction_pattern, line) and len(current['instructions']) < limit:
            current['instructions'].append(line)
    if not selected:
        raise ValueError('No evidence found: ' + repr(patterns))
    return selected

def entry(id, source, claim, patterns, instructions, limit=36):
    entries.append({'id': id, 'source': source, 'claim': claim, 'confidence': 'static-code',
                    'evidence': methods(source, patterns, instructions, limit)})

inventories = {source: json.loads((RAW / source / 'inventory.json').read_text()) for source in ['official', 'dudu']}
(ROOT / 'analysis/inventory.json').write_text(json.dumps(inventories, ensure_ascii=False, indent=2) + '\n')

entry('O01', 'official', '标准 Widget 承载和媒体 Widget 定向刷新',
      [r'LauncherImpl\$WidgetUpdateTask;->sendUpdateIntentLocked', r'ScalesLauncherAppWidgetHostView;->onClickEvent'],
      r'const-string|invoke-.*(?:Widget|Intent|Broadcast)')
entry('O02', 'official', '车型能力探测：摄像头配置、PM2.5 支持、DVR',
      [r'CarUtils;->updateCarConnected', r'CarUtils;->updateDeviceConnected'],
      r'const v|invoke-.*(?:xui|setHvacPM25|update)|FunctionStatus;->')
entry('O03', 'official', '随系统 Configuration 昼夜切换、主题广播和图标变化',
      [r'app/App;->getNightMode', r'app/App;->onConfigurationChanged', r'LauncherAppState;-><init>'],
      r'uiMode|and-int|const.*(?:48|16|32)|const-string.*(?:THEME|WALLPAPER)|invoke-.*(?:getNightMode|recreate|setNeedReload)')
entry('O04', 'official', 'Launcher 与系统生命周期通知、应用面板 IPC',
      [r'BaseActivity;->launcherFirstBroadcast', r'LauncherImpl;->sendLoadingCompleteBroadcastIfNecessary', r'apppane/AppPaneService;->onBind'],
      r'const-string|invoke-.*(?:Intent|Broadcast)|return-object', 20)
entry('D01', 'dudu', '获取 ECARX 车身 Binder 并连接车辆管理器',
      [r'manage/i/h/i/f/d;->a\(\)V'], r'const-string|invoke-.*(?:Service|ecarx|->a|->b|->c)')
entry('D02', 'dudu', '空调状态初始化与回调订阅',
      [r'manage/i/h/i/f/b;->a\(\)V'], r'const-string|invoke-.*(?:getCarManager|getECarXCarClimateManager|getPA_|registerCallback)', 25)
entry('D03', 'dudu', '空调与座椅指令，左右温度以 2 倍整数编码',
      [r'manage/i/h/i/f/b;->(?:a|b)\(F\)V', r'manage/i/h/i/f/b;->\w+\((?:I)?\)V', r'manage/i/h/i/f/b\$a;->onPA_CL_(?:Left|Right)Temp'],
      r'invoke-.*CB_|const/(?:wide/)?high16|const-wide/high16|mul-float|float-to-int|div-double|int-to-double|invoke-.*getData', 8)
entry('D04', 'dudu', '四轮胎压读取和回调',
      [r'manage/i/h/i/f/e;->a\(\)V'], r'invoke-.*(?:getPA_dTPMS|registerCallback)|const v', 12)
entry('D05', 'dudu', '车辆信号订阅与亮暗相关状态候选',
      [r'manage/i/h/i/f/c;->a\(\)V', r'manage/i/h/i/f/c\$a;->onChangeEvent'],
      r'const-string|const(?:/16)? v|invoke-.*(?:getTwliBriSts|registerCallback|getPropertyId|getValue)', 16)
entry('D06', 'dudu', '高德状态广播解析：转向、路名、距离、时间、车道与路况',
      [r'manage/s/i/g\$a;->onReceive'], r'const-string|const/16 v\d+, (?:10001|10019|10072|12110|13011|13012)', 60)
entry('D07', 'dudu', 'Android 9 ActivityView 嵌入与生命周期',
      [r'pipsdk/Pip28View;->(?:<init>|startActivity|release)', r'pipsdk/PipView\$b;->onActivityViewReady'],
      r'const-string|invoke-.*(?:ActivityView|VirtualDisplay)', 12)
entry('D08', 'dudu', '高德 plus 地图透出拓展广播，与标准引导广播是不同机制',
      [r'DevPluginPopupAMapService;->a\(I I I I\)V'], r'const-string.*(?:autonavi|"[xywh]")', 10)
entry('D09', 'dudu', '媒体会话获取与播放状态',
      [r'GetMusicInfoService;->a\(\)V', r'musicInfo/c;->'], r'invoke-.*(?:MediaSessionManager|MediaController|registerCallback)|const-string', 20)
entry('D10', 'dudu', '领克状态栏浮层服务',
      [r'LingkeStateBarPopupService;->(?:onCreate|onStartCommand|b\()'],
      r'invoke-.*(?:WindowManager|startForeground)|const-string|new-instance.*LayoutParams', 16)

widget_path = RAW / 'official/xml/res/xml/dcy11_widgetpage_default.xml'
namespace = '{http://schemas.android.com/apk/res-auto/ecarx.launcher3}'
widgets = [{key.removeprefix(namespace): value for key, value in node.attrib.items()}
           for node in ET.parse(widget_path).getroot()]
entries.append({'id': 'O05', 'source': 'official', 'claim': 'DCY11 默认 Widget 与空间配置',
                'confidence': 'static-resource', 'path': 'res/xml/dcy11_widgetpage_default.xml', 'widgets': widgets})
for source in ['official', 'dudu']:
    text = (RAW / source / 'strings.txt').read_text()
    origins = sorted(set(re.findall(r'https?://([A-Za-z0-9.-]+)', text)))
    entries.append({'id': 'O06' if source == 'official' else 'D11', 'source': source,
                    'claim': '明文域名仅表示包内配置或 SDK 字符串，未观察实际网络流量',
                    'confidence': 'string-only', 'origins': origins})
(ROOT / 'analysis/evidence.json').write_text(json.dumps(entries, ensure_ascii=False, indent=2) + '\n')
print('Wrote inventory.json and', len(entries), 'evidence groups.')
