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
  Map<String, String> appNames = {};
  List<LauncherCard> cards = defaultCards();
  int page = 0, pageCount = 2;
  final pageChanged = ValueNotifier<int>(0);
  int _pageRequest = 0;
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
  final Map<String, Uint8List> _recentImages = {};
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
          appNames = _decodeAppNames(state['appNames'] ?? data['appNames']);
          final parsed = (data['cards'] as List)
              .map((c) => LauncherCard.fromJson(Map<String, dynamic>.from(c)))
              .toList();
          if (validLayout(parsed)) {
            cards = parsed;
            // Empty trailing pages are editor scratch space, not persistent
            // desktops. Keeping them made an empty-page prompt animate over
            // the last real page after restart.
            pageCount =
                cards.fold<int>(1, (n, c) => max(n, c.page + 1)).clamp(1, 20);
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
    // The settings catalog can contain hundreds of entries. Android sends it
    // on bootstrap/explicit refresh, rather than with every telemetry event.
    if (!state.containsKey('systemSettings') &&
        native.value.containsKey('systemSettings')) {
      state = {...state, 'systemSettings': native.value['systemSettings']};
    }
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
    final recentTasks = state['recentTasks'];
    if (recentTasks is List) {
      for (final task in recentTasks) {
        if (task is! Map) continue;
        for (final field in const ['icon', 'snapshot']) {
          final raw = task[field];
          if (raw is! String || raw.isEmpty) continue;
          try {
            task['${field}Bytes'] = _recentImages.putIfAbsent(
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
        if (state['appNames'] is! Map) {
          appNames = _decodeAppNames(jsonDecode(_overlayDesign)['appNames']);
        }
        overlayThemeChanged = true;
      } catch (_) {}
    }
    if (state['appNames'] is Map) {
      final nextNames = _decodeAppNames(state['appNames']);
      if (!mapEquals(appNames, nextNames)) {
        appNames = nextNames;
        overlayThemeChanged = true;
      }
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
            'open-system-setting',
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
        'version': 6,
        'preferences': appearance.toJson(),
        'cards': cards.map((c) => c.toJson()).toList(),
        'pageCount': pageCount,
        'appNames': appNames
      });

  static Map<String, String> _decodeAppNames(Object? raw) {
    if (raw is! Map) return {};
    final result = <String, String>{};
    for (final entry in raw.entries) {
      final package = entry.key.toString().trim();
      final name = _normalizeAppName(entry.value);
      if (package.isNotEmpty && name.isNotEmpty) result[package] = name;
    }
    return result;
  }

  static String _normalizeAppName(Object? value) {
    final text =
        value is String ? value.replaceAll(RegExp(r'[\r\n]'), ' ').trim() : '';
    return String.fromCharCodes(text.runes.take(24));
  }

  String appName(Map<String, dynamic> app) {
    final package = app['package']?.toString();
    return (package == null ? null : appNames[package]) ??
        '${app['label'] ?? package ?? '应用'}';
  }

  Future<void> renameApp(String package, String name) async {
    package = package.trim();
    if (package.isEmpty) return;
    final normalized = _normalizeAppName(name);
    appNames = Map.of(appNames);
    if (normalized.isEmpty) {
      appNames.remove(package);
    } else {
      appNames[package] = normalized;
    }
    native.value = Map.of(native.value);
    notifyListeners();
    try {
      await gateway.action('rename-app', zone: package, value: normalized);
    } catch (_) {
      message = '应用名称保存失败，请重试';
      notifyListeners();
    }
    await persist();
  }

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
    _setPage(0);
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
    if (value == 'system') command('refresh-system-settings');
  }

  Future<void> switchPage(int value) async {
    final target = value.clamp(0, pageCount - 1), request = ++_pageRequest;
    if (target == page) return;
    // Page selection is intentionally a small one-way platform call. Sending
    // it through the general action channel publishes a complete vehicle
    // snapshot and rebuilds every telemetry/media card during a swipe.
    // Hide Android's independent map Surface BEFORE changing the Flutter
    // workspace. A post-frame hide can briefly put that Surface over page two.
    try {
      await gateway.setDesktopPage(target);
    } catch (_) {}
    if (request == _pageRequest) _setPage(target);
  }

  void _setPage(int value) {
    _pageRequest++;
    page = value;
    if (pageChanged.value != value) pageChanged.value = value;
  }

  void beginEdit() {
    _backup = List.of(cards);
    _backupPages = pageCount;
    editing = true;
    settings = false;
    notifyListeners();
  }

  void finishEdit() {
    pageCount = cards.fold<int>(1, (n, c) => max(n, c.page + 1));
    _setPage(page.clamp(0, pageCount - 1));
    editing = false;
    _backup = null;
    persist();
    notifyListeners();
  }

  void cancelEdit() {
    cards = _backup ?? cards;
    pageCount = _backupPages;
    _setPage(page.clamp(0, pageCount - 1));
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

  /// Move a card to another desktop and select the nearest free cell to the
  /// pointer's original grid position. This is used by edge dragging while the
  /// editor is open, so a card never lands on top of another card.
  bool moveToPage(String id, int targetPage,
      {int? preferredX, int? preferredY}) {
    if (targetPage < 0 || targetPage >= pageCount) return false;
    final index = cards.indexWhere((card) => card.id == id);
    if (index < 0) return false;
    final card = cards[index],
        px = preferredX ?? card.x,
        py = preferredY ?? card.y;
    final cells = <(int, int)>[
      for (int y = 0; y <= 6 - card.h; y++)
        for (int x = 0; x <= 12 - card.w; x++) (x, y)
    ]..sort((a, b) {
        final ad = (a.$1 - px).abs() + (a.$2 - py).abs();
        final bd = (b.$1 - px).abs() + (b.$2 - py).abs();
        return ad == bd
            ? (a.$2 * 12 + a.$1).compareTo(b.$2 * 12 + b.$1)
            : ad.compareTo(bd);
      });
    for (final cell in cells) {
      final next = card.copyWith(page: targetPage, x: cell.$1, y: cell.$2);
      if (!cards.any((other) => other.id != id && other.overlaps(next))) {
        cards = [
          for (final item in cards)
            if (item.id == id) next else item
        ];
        _setPage(targetPage);
        notifyListeners();
        return true;
      }
    }
    return false;
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
      _setPage(pageCount++);
      next = LauncherCard('card-${DateTime.now().microsecondsSinceEpoch}', type,
          spec.label, 0, 0, spec.w, spec.h, page);
    }
    cards = [...cards, next];
    notifyListeners();
    return true;
  }

  void newPage() {
    if (pageCount < 20) {
      _setPage(pageCount++);
      notifyListeners();
    }
  }

  void resetLayout() {
    cards = defaultCards();
    pageCount = 2;
    _setPage(0);
    persist();
    notifyListeners();
  }

  @override
  void dispose() {
    _pageRequest++;
    _subscription?.cancel();
    pageChanged.dispose();
    native.dispose();
    super.dispose();
  }
}
