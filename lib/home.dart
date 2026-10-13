import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'sheets.dart';
import 'store.dart';
import 'theme.dart';

/// Accent of the active section; the backdrop glow listens to it.
final glow = ValueNotifier<Color>(Cat.anime.accent);

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final _pc = PageController();
  final _keys = [for (final _ in Cat.values) GlobalKey()];
  final _search = TextEditingController();
  int _page = 0;
  bool _searching = false;
  Status? _status;
  bool _fav = false, _flag = false;

  void _filter(Status? s, {bool fav = false, bool flag = false}) =>
      setState(() {
        _status = s;
        _fav = fav;
        _flag = flag;
      });

  Cat get _cat => Cat.values[_page];

  @override
  void dispose() {
    _pc.dispose();
    _search.dispose();
    super.dispose();
  }

  void _go(int i) => _pc.animateToPage(i, duration: dur(context, 380), curve: easeOut);

  void _onPage(int i) {
    setState(() => _page = i);
    glow.value = _cat.accent;
    HapticFeedback.selectionClick();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _keys[i].currentContext;
      if (c != null) Scrollable.ensureVisible(c, alignment: .5, duration: dur(context, 300), curve: easeOut);
    });
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _search.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.skin;
    return PopScope(
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _toggleSearch();
      },
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final done = store.items.where((i) => i.status == Status.done).length;
          final total = store.items.length;
          final q = _search.text;
          final global = _searching && q.trim().isNotEmpty;
          final sig = '$_status$_fav$_flag${store.sort}$q';
          return Scaffold(
            floatingActionButton: _Fab(cat: _cat, onTap: () => showEditor(context, store.blank(_cat), isNew: true)),
            body: SafeArea(
              bottom: false,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
                  child: Row(children: [
                    Expanded(child: Text('MyList', style: s.disp(36, w: FontWeight.w700))),
                    _IconBtn(_searching ? Icons.close_rounded : Icons.search_rounded, _toggleSearch),
                    _IconBtn(Icons.tune_rounded, () => showSettings(context)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
                  child: Row(children: [
                    Text('$done of $total finished',
                        style: s.body(13, w: FontWeight.w500, color: s.mute)),
                    if (store.fetching) ...[
                      const SizedBox(width: 10),
                      SizedBox(
                          width: 11,
                          height: 11,
                          child: CircularProgressIndicator(strokeWidth: 1.6, color: s.mute)),
                      const SizedBox(width: 6),
                      Text('posters ${store.fetchLeft}', style: s.body(12, color: s.mute)),
                    ],
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: total == 0 ? 0 : done / total),
                    duration: dur(context, 700),
                    curve: easeOut,
                    builder: (_, v, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                          value: v, minHeight: 4, color: _cat.accent, backgroundColor: s.ink.withValues(alpha: .08)),
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: dur(context, 260),
                  curve: easeOut,
                  child: _searching
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Panel(
                            radius: 16,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: TextField(
                              controller: _search,
                              autofocus: true,
                              onChanged: (_) => setState(() {}),
                              style: s.body(15),
                              cursorColor: _cat.accent,
                              decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Search every section…',
                                  hintStyle: s.body(15, color: s.mute),
                                  icon: Icon(Icons.search_rounded, color: s.mute, size: 20)),
                            ),
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: Cat.values.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => Pill(Cat.values[i].label,
                        key: _keys[i],
                        on: i == _page,
                        color: Cat.values[i].accent,
                        icon: Cat.values[i].icon,
                        count: store.count(Cat.values[i]),
                        onTap: () => global ? setState(() => _search.clear()) : _go(i)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _chip('All', _status == null && !_fav && !_flag, s.ink,
                          () => _filter(null)),
                      for (final st in Status.values)
                        _chip(_cat.statusLabel(st), _status == st, st.color,
                            () => _filter(_status == st ? null : st)),
                      _chip('Favourites', _fav, const Color(0xFFFF6B9A),
                          () => _filter(null, fav: !_fav),
                          icon: Icons.favorite_rounded),
                      _chip('Flagged', _flag, const Color(0xFFFF5D73),
                          () => _filter(null, flag: !_flag),
                          icon: Icons.flag_rounded),
                      PopupMenuButton<Sort>(
                        tooltip: 'Sort',
                        initialValue: store.sort,
                        onSelected: store.setSort,
                        color: s.dark ? const Color(0xFF1A1A20) : s.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        itemBuilder: (_) => [
                          for (final o in Sort.values)
                            PopupMenuItem(value: o, child: Text(o.label, style: s.body(14))),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4, top: 7),
                          child: Row(children: [
                            Icon(Icons.swap_vert_rounded, size: 18, color: s.mute),
                            const SizedBox(width: 4),
                            Text(store.sort.label, style: s.body(13, color: s.mute)),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: global
                      ? _list(store.view(null, q: q, status: _status, fav: _fav, flag: _flag), sig, null)
                      : PageView.builder(
                          controller: _pc,
                          onPageChanged: _onPage,
                          itemCount: Cat.values.length,
                          itemBuilder: (_, i) => _list(
                              store.view(Cat.values[i], q: q, status: _status, fav: _fav, flag: _flag), sig, Cat.values[i]),
                        ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _chip(String l, bool on, Color c, VoidCallback t, {IconData? icon}) =>
      Padding(padding: const EdgeInsets.only(right: 8), child: Pill(l, on: on, color: c, onTap: t, icon: icon));

  Widget _list(List<Item> l, String sig, Cat? c) => AnimatedSwitcher(
        duration: dur(context, 220),
        child: l.isEmpty
            ? _Empty(key: ValueKey('e$sig'), cat: c)
            : ListView.builder(
                key: ValueKey('l${c?.name}$sig'),
                padding: const EdgeInsets.only(top: 4, bottom: 110),
                itemCount: l.length,
                itemBuilder: (_, i) => ItemCard(key: ValueKey(l[i].id), item: l[i], index: i, showCat: c == null),
              ),
      );
}

class _IconBtn extends StatelessWidget {
  const _IconBtn(this.icon, this.onTap);

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Press(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: AnimatedSwitcher(
            duration: dur(context, 200),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
            child: Icon(icon, key: ValueKey(icon), size: 24, color: context.skin.ink.withValues(alpha: .85)),
          ),
        ),
      );
}

class _Fab extends StatelessWidget {
  const _Fab({required this.cat, required this.onTap});

  final Cat cat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Press(
        onTap: onTap,
        child: AnimatedContainer(
          duration: dur(context, 400),
          curve: easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: cat.accent,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: cat.accent.withValues(alpha: .35), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add_rounded, color: Colors.black, size: 22),
            const SizedBox(width: 6),
            Text('Add', style: context.skin.body(15, w: FontWeight.w700, color: Colors.black)),
          ]),
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({super.key, this.cat});

  final Cat? cat;

  @override
  Widget build(BuildContext context) {
    final s = context.skin;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(cat?.icon ?? Icons.search_off_rounded, size: 44, color: (cat?.accent ?? s.ink).withValues(alpha: .5)),
        const SizedBox(height: 12),
        Text('Nothing here', style: s.disp(20)),
        const SizedBox(height: 4),
        Text('Tap Add, or loosen the filter.', style: s.body(13.5, color: s.mute)),
      ]),
    );
  }
}

/// Poster thumbnail with a typographic fallback.
class PosterBox extends StatelessWidget {
  const PosterBox(this.item, {super.key, this.w = 56, this.h = 80});

  final Item item;
  final double w, h;

  @override
  Widget build(BuildContext context) {
    final s = context.skin;
    final a = item.cat.accent;
    final fallback = Container(
      decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [a.withValues(alpha: .55), a.withValues(alpha: .12)])),
      alignment: Alignment.center,
      child: Text(item.title.isEmpty ? '?' : item.title.characters.first.toUpperCase(),
          style: s.disp(w * .5, color: Colors.white.withValues(alpha: .92))),
    );
    final p = item.poster;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: w,
        height: h,
        child: p == null || p.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: p,
                fit: BoxFit.cover,
                fadeInDuration: dur(context, 300),
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

class ItemCard extends StatelessWidget {
  const ItemCard({super.key, required this.item, required this.index, this.showCat = false});

  final Item item;
  final int index;
  final bool showCat;

  @override
  Widget build(BuildContext context) {
    final s = context.skin;
    final it = item;
    final done = it.status == Status.done;
    final card = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Press(
        onTap: () => showEditor(context, it.copy()),
        child: Panel(
          glow: it.cat.accent,
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            PosterBox(it),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (showCat)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(it.cat.label.toUpperCase(),
                        style: s.body(10.5, w: FontWeight.w700, color: it.cat.accent).copyWith(letterSpacing: 1)),
                  ),
                Text(it.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: s.disp(16.5, w: FontWeight.w600, h: 1.2)),
                const SizedBox(height: 6),
                Row(children: [
                  Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: it.status.color, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(it.cat.statusLabel(it.status),
                      style: s.body(12.5, w: FontWeight.w600, color: it.status.color)),
                  if (it.progress > 0 || it.total > 0)
                    Text('  ·  ${it.progress}${it.total > 0 ? ' / ${it.total}' : ''}',
                        style: s.body(12.5, color: s.mute)),
                  if (it.rating > 0) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFC857)),
                    Text('${it.rating}', style: s.body(12.5, color: s.mute)),
                  ],
                  if (it.fav) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.favorite_rounded, size: 14, color: Color(0xFFFF6B9A))),
                  if (it.flag) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.flag_rounded, size: 15, color: Color(0xFFFF5D73))),
                ]),
                if (it.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(it.note, maxLines: 1, overflow: TextOverflow.ellipsis, style: s.body(12.5, color: s.mute)),
                ],
              ]),
            ),
            const SizedBox(width: 6),
            Press(
              onTap: () {
                HapticFeedback.lightImpact();
                store.toggleDone(it);
              },
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: AnimatedContainer(
                  duration: dur(context, 260),
                  curve: easeOut,
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? Status.done.color : Colors.transparent,
                    border: Border.all(color: done ? Status.done.color : s.ink.withValues(alpha: .28), width: 1.6),
                  ),
                  child: AnimatedScale(
                    scale: done ? 1 : 0,
                    duration: dur(context, 260),
                    curve: Curves.easeOutBack,
                    child: const Icon(Icons.check_rounded, size: 18, color: Colors.black),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );

    final dismissible = Dismissible(
      key: ValueKey('d${it.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.only(right: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(color: const Color(0x33FF5D73), borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF5D73)),
      ),
      onDismissed: (_) {
        store.remove(it);
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text('Removed "${it.title}"'),
            action: SnackBarAction(label: 'Undo', onPressed: () => store.restore(it)),
          ));
      },
      child: card,
    );

    if (index >= 10) return dismissible;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: dur(context, 280 + index * 45),
      curve: easeOut,
      builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * 16), child: child)),
      child: dismissible,
    );
  }
}
