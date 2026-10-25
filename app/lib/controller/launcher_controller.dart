import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../model/appearance.dart';
import '../model/card_layout.dart';
import '../platform/native_gateway.dart';

class LauncherController extends ChangeNotifier {
  final NativeGateway gateway;
  final native = ValueNotifier<Map<String, dynamic>>({});
  Appearance appearance = const Appearance();
  List<LauncherCard> cards = defaultCards();
  int page = 0, pageCount = 2;
  bool settings = false, editing = false, ready = false;
  Future<void> Function()? beforeExternalLaunch;
  String _overlayDesign = '';
  bool get isGlobalDock =>
      {'global-dock', 'global-panel'}.contains(native.value['hostMode']);

  /// Route card and dock entry points to the same physical panel window.
  Future<bool> presentGlobalPanel(String panel) async {
    final dock = native.value['globalDock'];
    if (native.value['hostMode'] == 'global-panel' ||
        dock is! Map ||
        dock['running'] != true ||
        dock['visible'] == false ||
        dock['enabled'] != true) {
      return false;
    }
    await command('show-dock-panel', value: panel);
    return true;
  }

  String settingsTab = 'appearance', message = '';
  List<LauncherCard>? _backup, _undo;
  int _backupPages = 2;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Future<void> _saveTail = Future.value();
  final Map<String, Uint8List> _icons = {};
  LauncherController(this.gateway);
  Future<void> initialize() async {
    gateway.onHome(home);
    if (gateway is AndroidGateway)
      (gateway as AndroidGateway).onOpenSettings(openSettings);
    try {
      final state = await gateway.bootstrap();
      final raw = state['savedDesign'];
      if (raw is String && raw.isNotEmpty) {
        try {
          final data = jsonDecode(raw) as Map<String, dynamic>;
          appearance = Appearance.fromJson(
              Map<String, dynamic>.from(data['preferences'] ?? {}));
          final parsed = (data['cards'] as List)
              .map((c) => LauncherCard.fromJson(Map<String, dynamic>.from(c)))
              .toList();
          if (validLayout(parsed)) {
            cards = parsed;
            pageCount = max(
                    1,
                    max((data['pageCount'] as num?)?.toInt() ?? 1,
                        cards.fold<int>(1, (n, c) => max(n, c.page + 1))))
                .clamp(1, 20);
          }
        } catch (_) {
          message = '旧布局无法读取，已恢复默认卡片';
        }
      }
      _receive(state);
      if (state['initialSettings'] == true) settings = true;
      _subscription = gateway.events.listen(_receive, onError: (Object e) {
        message = '原生连接暂不可用';
        notifyListeners();
      });
    } catch (_) {
      message = '等待 Android 接入';
    }
    ready = true;
    notifyListeners();
  }

  void _receive(Map<String, dynamic> state) {
    final apps = state['apps'];
    if (apps is List) {
      for (final app in apps) {
        if (app is Map && app['icon'] is String) {
          final raw = app['icon'] as String;
          try {
            app['iconBytes'] = _icons.putIfAbsent(
                raw, () => base64Decode(raw.split(',').last));
          } catch (_) {}
        }
      }
    }
    bool overlayThemeChanged = false;
    if ({'global-dock', 'global-panel'}.contains(state['hostMode']) &&
        state['savedDesign'] is String &&
        state['savedDesign'] != _overlayDesign) {
      _overlayDesign = state['savedDesign'];
      try {
        appearance = Appearance.fromJson(Map<String, dynamic>.from(
            jsonDecode(_overlayDesign)['preferences']));
        overlayThemeChanged = true;
      } catch (_) {}
    }
    final oldDark = native.value['dark'];
    final oldDemo = native.value['demo'];
    final oldEmbed = (native.value['navigation'] as Map?)?['canEmbed'];
    final oldHeight = native.value['viewportHeightPx'];
    native.value = state;
    if (state['message'] is String && (state['message'] as String).isNotEmpty) {
      message = state['message'];
      notifyListeners();
    }
    if (overlayThemeChanged ||
        (appearance.mode == 'system' && oldDark != state['dark']) ||
        oldDemo != state['demo'] ||
        oldHeight != state['viewportHeightPx'] ||
        oldEmbed != (state['navigation'] as Map?)?['canEmbed'])
      notifyListeners();
  }

  Future<void> command(String action,
      {String? value, String? zone, bool? enabled}) async {
    try {
      if (isGlobalDock &&
          {
            'launch-app',
            'app-info',
            'request-uninstall',
            'launch-navigation',
            'launch-player',
            'open-official',
            'official-widget',
            'show-home',
            'show-desktop-settings',
            'show-recents'
          }.contains(action)) {
        await beforeExternalLaunch?.call();
      }
      await gateway.action(action, value: value, zone: zone, enabled: enabled);
    } catch (_) {
      message = '操作暂不可用';
      notifyListeners();
    }
  }

  String serialize() => jsonEncode({
        'version': 4,
        'preferences': appearance.toJson(),
        'cards': cards.map((c) => c.toJson()).toList(),
        'pageCount': pageCount
      });
  Future<void> persist() {
    final payload = serialize();
    _saveTail = _saveTail
        .catchError((_) {})
        .then((_) => gateway.save(payload))
        .catchError((Object e) {
      message = '保存失败，请重试';
      notifyListeners();
    });
    return _saveTail;
  }

  void setAppearance(Appearance next, {bool save = true}) {
    appearance = next;
    notifyListeners();
    if (save) persist();
  }

  void home() {
    if (isGlobalDock) {
      command('show-home');
      return;
    }
    if (editing) return;
    settings = false;
    page = 0;
    notifyListeners();
  }

  void openSettings() {
    if (isGlobalDock) {
      command('show-desktop-settings');
      return;
    }
    if (editing) return;
    settings = true;
    notifyListeners();
  }

  void back() {
    if (editing) {
      cancelEdit();
    } else if (settings) {
      settings = false;
      notifyListeners();
    }
  }

  void tab(String value) {
    settingsTab = value;
    notifyListeners();
  }

  void switchPage(int value) {
    page = value.clamp(0, pageCount - 1);
    notifyListeners();
  }

  void beginEdit() {
    _backup = List.of(cards);
    _backupPages = pageCount;
    editing = true;
    settings = false;
    notifyListeners();
  }

  void finishEdit() {
    editing = false;
    _backup = null;
    persist();
    notifyListeners();
  }

  void cancelEdit() {
    cards = _backup ?? cards;
    pageCount = _backupPages;
    page = page.clamp(0, pageCount - 1);
    editing = false;
    _backup = null;
    notifyListeners();
  }

  void remove(String id) {
    _undo = List.of(cards);
    cards = cards.where((c) => c.id != id).toList();
    notifyListeners();
  }

  void undoRemove() {
    if (_undo != null) {
      cards = _undo!;
      _undo = null;
      notifyListeners();
    }
  }

  bool transform(LauncherCard next) {
    if (!next.inBounds || cards.any((c) => c.id != next.id && c.overlaps(next)))
      return false;
    cards = cards.map((c) => c.id == next.id ? next : c).toList();
    notifyListeners();
    return true;
  }

  bool add(String type) {
    final spec = specFor(type);
    LauncherCard? next;
    for (int y = 0; y <= 6 - spec.h; y++) {
      for (int x = 0; x <= 12 - spec.w; x++) {
        final c = LauncherCard('card-${DateTime.now().microsecondsSinceEpoch}',
            type, spec.label, x, y, spec.w, spec.h, page);
        if (!cards.any((old) => old.overlaps(c))) {
          next = c;
          break;
        }
      }
      if (next != null) break;
    }
    if (next == null) {
      if (pageCount >= 20) return false;
      page = pageCount++;
      next = LauncherCard('card-${DateTime.now().microsecondsSinceEpoch}', type,
          spec.label, 0, 0, spec.w, spec.h, page);
    }
    cards = [...cards, next];
    notifyListeners();
    return true;
  }

  void newPage() {
    if (pageCount < 20) {
      page = pageCount++;
      notifyListeners();
    }
  }

  void resetLayout() {
    cards = defaultCards();
    pageCount = 2;
    page = 0;
    persist();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    native.dispose();
    super.dispose();
  }
}
