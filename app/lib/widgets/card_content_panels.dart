part of 'card_content.dart';

Future<void> showAppsPanel(BuildContext context, LauncherController c) async {
  if (await c.presentGlobalPanel('apps') || !context.mounted) return;
  await showLauncherSheet<void>(context,
      title: '全部应用',
      subtitle: '已安装的应用',
      closeLabel: '关闭应用列表',
      width: Design.px(1560),
      height: Design.px(760),
      builder: (context) => AppPanel(controller: c));
}

Future<void> showMediaPanel(BuildContext context, LauncherController c) async {
  if (await c.presentGlobalPanel('media') || !context.mounted) return;
  await showLauncherSheet<void>(context,
      title: '正在播放',
      closeLabel: '关闭音乐详情',
      width: Design.px(1040),
      builder: (context) => MediaPanel(controller: c));
}

class AppPanel extends StatelessWidget {
  final LauncherController controller;
  const AppPanel({super.key, required this.controller});
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<Map<String, dynamic>>(
          valueListenable: controller.native,
          builder: (context, state, _) {
            final s = SurfaceStyle.of(context);
            final apps =
                state['apps'] is List ? state['apps'] as List : const [];
            if (apps.isEmpty)
              return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                UniIcon('apps', size: Design.px(60), color: s.accent),
                SizedBox(height: Design.px(24)),
                Text('等待应用列表',
                    style: TextStyle(fontSize: Design.px(25), color: s.muted)),
              ]));
            return GridView.builder(
                padding: EdgeInsets.symmetric(vertical: Design.px(32)),
                itemCount: apps.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: Design.px(40),
                    crossAxisSpacing: Design.px(24),
                    mainAxisExtent: Design.px(156)),
                itemBuilder: (context, i) {
                  final app = mapOf(apps[i]), bytes = app['iconBytes'];
                  return Semantics(
                      button: true,
                      label: '${app['label'] ?? '应用'}',
                      child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                              borderRadius:
                                  BorderRadius.circular(s.controlRadius),
                              onLongPress: () =>
                                  showAppMenu(context, controller, app),
                              onTap: app['id'] == null
                                  ? null
                                  : () => controller.command('launch-app',
                                      value: '${app['id']}'),
                              child: Column(children: [
                                Container(
                                    width: Design.px(104),
                                    height: Design.px(104),
                                    decoration: BoxDecoration(
                                        color: s.soft,
                                        border: Border.all(color: s.edge),
                                        borderRadius: BorderRadius.circular(
                                            s.controlRadius)),
                                    child: Center(
                                        child: bytes is Uint8List
                                            ? Image.memory(bytes,
                                                width: Design.px(66),
                                                height: Design.px(66),
                                                errorBuilder:
                                                    (context, error, stack) =>
                                                        UniIcon('apps',
                                                            size: Design.px(45),
                                                            color: s.accent))
                                            : UniIcon('apps',
                                                size: Design.px(45),
                                                color: s.accent))),
                                SizedBox(height: Design.px(18)),
                                Text('${app['label'] ?? '应用'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: Design.px(23), height: 1.2)),
                              ]))));
                });
          });
}

Future<void> showAppMenu(BuildContext context, LauncherController c,
    Map<String, dynamic> app) async {
  final action = await showLauncherSheet<String>(context,
      title: '${app['label'] ?? '应用'}',
      closeLabel: '关闭应用菜单',
      width: Design.px(520),
      height: Design.px(330),
      builder: (context) => Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
                key: const ValueKey('app-menu-info'),
                leading: const Icon(Icons.info_outline),
                title: const Text('应用信息'),
                onTap: () => Navigator.pop(context, 'app-info')),
            ListTile(
                key: const ValueKey('app-menu-uninstall'),
                leading: const Icon(Icons.delete_outline),
                title: const Text('卸载'),
                enabled: app['canUninstall'] == true,
                onTap: app['canUninstall'] == true
                    ? () => Navigator.pop(context, 'request-uninstall')
                    : null),
          ]));
  if (action != null) await c.command(action, value: '${app['package']}');
}
