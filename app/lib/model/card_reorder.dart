import 'card_layout.dart';

/// Atomic, bounded grid rearrangement. The requested card is locked to its drop
/// cell; displaced cards retain their IDs, content, layouts and sizes.
List<LauncherCard>? reorderCards(
    List<LauncherCard> original, LauncherCard target,
    {int searchBudget = 3000}) {
  final source = original.where((c) => c.id == target.id).firstOrNull;
  if (source == null ||
      source.type != target.type ||
      !target.inBounds ||
      !validLayout(original)) return null;
  final others = original.where((c) => c.id != target.id).toList();
  final conflicts = others.where((c) => c.overlaps(target)).toList();
  if (conflicts.isEmpty)
    return [for (final c in original) c.id == target.id ? target : c];
  final pages = {source.page, target.page};
  if (others
          .where((c) => pages.contains(c.page))
          .fold<int>(target.w * target.h, (area, c) => area + c.w * c.h) >
      pages.length * 72) return null;
  var remainingBudget = searchBudget;

  List<LauncherCard>? attempt(List<LauncherCard> movable) {
    final ids = movable.map((c) => c.id).toSet();
    final placed = <LauncherCard>[
      target,
      ...others.where((c) => !ids.contains(c.id))
    ];
    final candidates = <String, List<LauncherCard>>{};
    int cost(LauncherCard old, LauncherCard next) =>
        (next.page == old.page ? 0 : 200) +
        (next.x - old.x).abs() * 10 +
        (next.y - old.y).abs() * 10;
    for (final c in movable) {
      candidates[c.id] = [
        for (final page in pages)
          for (var y = 0; y <= 6 - c.h; y++)
            for (var x = 0; x <= 12 - c.w; x++)
              c.copyWith(page: page, x: x, y: y)
      ]..sort((a, b) {
          final difference = cost(c, a).compareTo(cost(c, b));
          return difference != 0
              ? difference
              : (a.page * 72 + a.y * 12 + a.x)
                  .compareTo(b.page * 72 + b.y * 12 + b.x);
        });
    }
    bool place(List<LauncherCard> todo) {
      if (todo.isEmpty) return true;
      if (--remainingBudget < 0) return false;
      // Most constrained first avoids stranding larger widgets in small holes.
      LauncherCard? chosen;
      List<LauncherCard>? slots;
      for (final c in todo) {
        final free = candidates[c.id]!
            .where((next) => !placed.any(next.overlaps))
            .toList();
        if (free.isEmpty) return false;
        if (slots == null ||
            free.length < slots.length ||
            (free.length == slots.length && c.w * c.h > chosen!.w * chosen.h)) {
          chosen = c;
          slots = free;
        }
      }
      final rest = todo.where((c) => c.id != chosen!.id).toList();
      for (final slot in slots!) {
        if (remainingBudget < 0) return false;
        placed.add(slot);
        if (place(rest)) return true;
        placed.removeLast();
      }
      return false;
    }

    if (!place(movable)) return null;
    final byId = {for (final c in placed) c.id: c};
    return [for (final c in original) byId[c.id]!];
  }

  // Preserve uninvolved widgets first. If holes require a chain of movements,
  // retry with only the source/destination pages unlocked. No extra page is used.
  final direct = attempt(conflicts);
  if (direct != null) return direct;
  return attempt(others.where((c) => pages.contains(c.page)).toList());
}
