/// Lightweight launcher effects. No perspective, blur, bitmap capture or
/// per-card stagger is required by any preset.
const pageEffects = [
  (id: 'slide', name: '平移', detail: '跟手滑动 · 推荐'),
  (id: 'fade', name: '淡入淡出', detail: '两页柔和交替'),
  (id: 'zoom', name: '缩放', detail: '滑动时轻微缩放'),
  (id: 'depth', name: '层叠', detail: '新页面覆盖收拢的旧页'),
  (id: 'none', name: '无动画', detail: '松手后直接切换'),
];

String normalizePageEffect(Object? value) =>
    pageEffects.any((effect) => effect.id == value) ? value as String : 'slide';
