part of 'card_content.dart';

String _mediaValue(
    Map<String, dynamic> state, String key, String demoValue, String waiting) {
  final value = mapOf(state['media'])[key]?.toString().trim() ?? '';
  return value.isNotEmpty
      ? value
      : state['demo'] == true
          ? demoValue
          : waiting;
}

String mediaSourceLabel(Map<String, dynamic> state) {
  if (state['demo'] == true) return '原车媒体中心 · 样式示例';
  final media = mapOf(state['media']);
  final preferred = mapOf(state['integrationPreferences'])['mediaPackage'];
  final source = media['source'] ?? (preferred == 'auto' ? null : preferred);
  for (final raw in state['apps'] is List ? state['apps'] as List : const []) {
    final app = mapOf(raw);
    if (app['package'] == source && source != null)
      return '${app['label'] ?? source}';
  }
  return source?.toString() ?? '音乐播放器';
}

class _MediaCover extends StatelessWidget {
  final bool demo;
  final double size;
  final Map<String, dynamic> media;
  const _MediaCover(
      {required this.demo, required this.size, required this.media});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(s.radius * .93),
            boxShadow: [
              BoxShadow(
                  color: s.shadow,
                  offset: Offset(0, Design.px(18)),
                  blurRadius: Design.px(40))
            ]),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(s.radius * .93),
            child: MediaArtwork(media: media, demo: demo)));
  }
}

class _MusicCard extends StatelessWidget {
  final LauncherCard card;
  final LauncherController controller;
  final Map<String, dynamic> state;
  const _MusicCard(
      {required this.card, required this.controller, required this.state});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context), demo = state['demo'] == true;
    final title = _mediaValue(state, 'title', '向海而行', '暂无播放');
    final artist = _mediaValue(state, 'artist', 'Coastline', '等待媒体会话');
    final collection = _mediaValue(state, 'collection', '晨间驾驶歌单', '');
    final subtitle =
        [artist, if (collection.isNotEmpty) collection].join(' · ');
    final editing = controller.editing;
    return LayoutBuilder(builder: (context, box) {
      final compact = card.h <= 2 || box.maxHeight < Design.px(250);
      final coverSize = Design.px(compact
          ? (editing ? 80 : 90)
          : editing
              ? 140
              : 180);
      final copy = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: Design.px(compact || editing ? 29 : 34),
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    letterSpacing: Design.px(1))),
            SizedBox(height: Design.px(10)),
            Text(subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: Design.px(compact || editing ? 18 : 21),
                    height: 1.2,
                    color: s.muted)),
            SizedBox(height: Design.px(10)),
            LyricsView(media: mapOf(state['media']), compact: true),
          ]);
      return _CardCanvas(
          minHeight: compact ? 190 : 320,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
                height: Design.px(28),
                child: Row(children: [
                  Expanded(
                      child: Text(card.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: Design.px(23),
                              height: 1.2,
                              color: s.muted))),
                  SizedBox(width: Design.px(14)),
                  Container(
                      width: Design.px(7),
                      height: Design.px(7),
                      decoration: BoxDecoration(
                          color: s.accent, shape: BoxShape.circle)),
                  SizedBox(width: Design.px(9)),
                  Text(demo ? '原车媒体' : '媒体会话',
                      style:
                          TextStyle(fontSize: Design.px(19), color: s.muted)),
                ])),
            SizedBox(height: Design.px(editing ? 14 : 22)),
            Expanded(
                child: LayoutBuilder(
                    builder: (context, body) => Align(
                          alignment: Alignment.topCenter,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: SizedBox(
                                width: body.maxWidth,
                                child: compact
                                    ? Row(children: [
                                        _MediaCover(
                                            demo: demo,
                                            size: coverSize,
                                            media: mapOf(state['media'])),
                                        SizedBox(width: Design.px(20)),
                                        Expanded(child: copy),
                                        IconAction(
                                            icon: Icons.arrow_forward,
                                            label: '打开音乐详情',
                                            size: Design.px(28),
                                            iconSize: Design.px(25),
                                            active: true,
                                            onTap: () => showMediaPanel(
                                                context, controller)),
                                      ])
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                            _MediaCover(
                                                demo: demo,
                                                size: coverSize,
                                                media: mapOf(state['media'])),
                                            SizedBox(
                                                height: Design.px(
                                                    editing ? 14 : 20)),
                                            copy,
                                            SizedBox(height: Design.px(14)),
                                            Padding(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: Design.px(12)),
                                                child: MediaProgress(
                                                    media:
                                                        mapOf(state['media']),
                                                    onSeek: (v) => controller
                                                        .command('seek',
                                                            value: '$v'))),
                                            if (!editing) ...[
                                              SizedBox(height: Design.px(13)),
                                              Padding(
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal:
                                                          Design.px(12)),
                                                  child: Row(children: [
                                                    Expanded(
                                                        child: Text(
                                                            mediaSourceLabel(
                                                                state),
                                                            style: TextStyle(
                                                                fontSize:
                                                                    Design.px(
                                                                        18),
                                                                color: s.muted),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis)),
                                                    IconAction(
                                                        icon:
                                                            Icons.arrow_forward,
                                                        label: '打开音乐详情',
                                                        size: Design.px(28),
                                                        iconSize: Design.px(25),
                                                        active: true,
                                                        onTap: () =>
                                                            showMediaPanel(
                                                                context,
                                                                controller)),
                                                  ])),
                                            ],
                                          ])),
                          ),
                        ))),
          ]));
    });
  }
}

class MediaPanel extends StatelessWidget {
  final LauncherController controller;
  const MediaPanel({super.key, required this.controller});
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<Map<String, dynamic>>(
          valueListenable: controller.native,
          builder: (context, state, _) {
            final s = SurfaceStyle.of(context), m = mapOf(state['media']);
            final demo = state['demo'] == true,
                available = demo || m['available'] == true;
            final artist = _mediaValue(state, 'artist', 'Coastline', '等待媒体会话');
            final collection = _mediaValue(state, 'collection', '晨间驾驶歌单', '');
            return SingleChildScrollView(
                child: Padding(
                    padding: EdgeInsets.symmetric(vertical: Design.px(25)),
                    child: Row(children: [
                      _MediaCover(demo: demo, size: Design.px(260), media: m),
                      SizedBox(width: Design.px(44)),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            TextButton.icon(
                                onPressed: () =>
                                    controller.command('launch-player'),
                                icon: const UniIcon('music', size: 20),
                                label: const Text('打开关联播放器')),
                            Text(_mediaValue(state, 'title', '向海而行', '暂无播放'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: Design.px(42), height: 1.2)),
                            SizedBox(height: Design.px(18)),
                            Text(
                                [artist, if (collection.isNotEmpty) collection]
                                    .join(' · '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: Design.px(22),
                                    height: 1.4,
                                    color: s.muted)),
                            SizedBox(height: Design.px(20)),
                            LyricsView(media: m),
                            SizedBox(height: Design.px(20)),
                            MediaProgress(
                                media: m,
                                onSeek: (v) =>
                                    controller.command('seek', value: '$v')),
                            SizedBox(height: Design.px(26)),
                            Row(children: [
                              for (final action in [
                                'previous',
                                'toggle-play',
                                'next'
                              ]) ...[
                                if (action != 'previous')
                                  SizedBox(width: Design.px(24)),
                                IconAction(
                                    icon: action == 'previous'
                                        ? Icons.skip_previous_outlined
                                        : action == 'next'
                                            ? Icons.skip_next_outlined
                                            : m['playing'] == true
                                                ? Icons.pause
                                                : Icons.play_arrow,
                                    label: action == 'previous'
                                        ? '上一首'
                                        : action == 'next'
                                            ? '下一首'
                                            : m['playing'] == true
                                                ? '暂停'
                                                : '播放',
                                    solid: action == 'toggle-play',
                                    size: Design.px(58),
                                    iconSize: Design.px(28),
                                    onTap: available &&
                                            (demo ||
                                                m[action == 'next'
                                                        ? 'canNext'
                                                        : action == 'previous'
                                                            ? 'canPrevious'
                                                            : 'canToggle'] ==
                                                    true)
                                        ? () => controller.command(action)
                                        : null),
                              ],
                            ]),
                          ])),
                    ])));
          });
}
