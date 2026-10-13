import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'home.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';

Future<void> _sheet(BuildContext c, Widget child) => showModalBottomSheet(
      context: c,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => _Shell(child: child),
    );

Future<void> showEditor(BuildContext c, Item item, {bool isNew = false}) => _sheet(c, _Editor(item, isNew));

Future<void> showSettings(BuildContext c) => _sheet(c, const _Settings());

class _Shell extends StatelessWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = context.skin;
    const r = BorderRadius.vertical(top: Radius.circular(28));
    final glass = s.look == Look.glass;
    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: glass ? const Color(0xB3141432) : (s.look == Look.amoled ? const Color(0xFF0D0D11) : s.surface),
        borderRadius: r,
        border: Border(top: BorderSide(color: s.line)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        Container(width: 38, height: 4, decoration: BoxDecoration(color: s.ink.withValues(alpha: .2), borderRadius: BorderRadius.circular(4))),
        Flexible(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 24), child: child)),
      ]),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius: r,
        child: glass ? BackdropFilter(filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), child: body) : body,
      ),
    );
  }
}

Widget _label(BuildContext c, String t) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(t.toUpperCase(), style: c.skin.body(11, w: FontWeight.w700, color: c.skin.mute).copyWith(letterSpacing: 1.2)),
    );

// ---------------------------------------------------------------- editor
class _Editor extends StatefulWidget {
  const _Editor(this.item, this.isNew);

  final Item item;
  final bool isNew;

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late final it = widget.item;
  late final _title = TextEditingController(text: it.title);
  late final _note = TextEditingController(text: it.note);

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    it
      ..title = _title.text.trim()
      ..note = _note.text.trim();
    store.upsert(it);
    HapticFeedback.lightImpact();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.skin;
    final a = it.cat.accent;
    final ok = _title.text.trim().isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!widget.isNew) ...[PosterBox(it, w: 64, h: 92), const SizedBox(width: 14)],
        Expanded(
          child: TextField(
            controller: _title,
            autofocus: widget.isNew,
            onChanged: (_) => setState(() {}),
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.words,
            cursorColor: a,
            style: s.disp(24, h: 1.15),
            decoration: InputDecoration(border: InputBorder.none, hintText: 'Title', hintStyle: s.disp(24, color: s.mute)),
          ),
        ),
      ]),
      _label(context, 'Section'),
      SizedBox(
        height: 40,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final c in Cat.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Pill(c.label, on: it.cat == c, color: c.accent, icon: c.icon, onTap: () => setState(() => it.cat = c)),
            ),
        ]),
      ),
      _label(context, 'Status'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final st in Status.values)
          Pill(it.cat.statusLabel(st), on: it.status == st, color: st.color, onTap: () {
            HapticFeedback.selectionClick();
            setState(() => it.status = st);
          }),
      ]),
      _label(context, 'Progress'),
      Row(children: [
        _Step(it.progress, () => setState(() => it.progress = (it.progress - 1).clamp(0, 9999)),
            () => setState(() => it.progress++)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('of', style: s.body(14, color: s.mute))),
        _Step(it.total, () => setState(() => it.total = (it.total - 1).clamp(0, 9999)), () => setState(() => it.total++),
            zeroAs: '?'),
      ]),
      _label(context, 'Rating'),
      Row(children: [
        for (var i = 1; i <= 5; i++)
          Press(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => it.rating = it.rating == i ? 0 : i);
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: AnimatedSwitcher(
                duration: dur(context, 220),
                transitionBuilder: (c, an) => ScaleTransition(scale: an, child: c),
                child: Icon(it.rating >= i ? Icons.star_rounded : Icons.star_outline_rounded,
                    key: ValueKey(it.rating >= i), size: 34, color: it.rating >= i ? const Color(0xFFFFC857) : s.mute),
              ),
            ),
          ),
        const Spacer(),
        _Toggle(Icons.favorite_rounded, Icons.favorite_border_rounded, it.fav, const Color(0xFFFF6B9A),
            () => setState(() => it.fav = !it.fav)),
        const SizedBox(width: 6),
        _Toggle(Icons.flag_rounded, Icons.outlined_flag_rounded, it.flag, const Color(0xFFFF5D73),
            () => setState(() => it.flag = !it.flag)),
      ]),
      _label(context, 'Note'),
      Panel(
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: TextField(
          controller: _note,
          minLines: 2,
          maxLines: 5,
          cursorColor: a,
          style: s.body(14.5),
          decoration: InputDecoration(border: InputBorder.none, hintText: 'ep 6 · waiting for s3 · 2 more movies…', hintStyle: s.body(14.5, color: s.mute)),
        ),
      ),
      if (!widget.isNew) ...[
        _label(context, 'Poster'),
        Row(children: [
          Pill('Re-fetch', on: false, color: a, icon: Icons.refresh_rounded, onTap: () {
            store.refetch(it);
            Navigator.pop(context);
          }),
          const SizedBox(width: 8),
          Pill('Remove', on: false, color: a, icon: Icons.hide_image_outlined, onTap: () {
            store.clearPoster(it);
            Navigator.pop(context);
          }),
        ]),
      ],
      const SizedBox(height: 22),
      Row(children: [
        if (!widget.isNew)
          Press(
            onTap: () {
              final m = ScaffoldMessenger.of(context);
              store.remove(widget.item);
              Navigator.pop(context);
              m
                ..clearSnackBars()
                ..showSnackBar(SnackBar(
                    content: Text('Removed "${it.title}"'),
                    action: SnackBarAction(label: 'Undo', onPressed: () => store.restore(widget.item))));
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text('Delete', style: s.body(14.5, w: FontWeight.w600, color: const Color(0xFFFF5D73))),
            ),
          ),
        Expanded(
          child: Press(
            onTap: ok ? _save : null,
            child: AnimatedOpacity(
              duration: dur(context, 200),
              opacity: ok ? 1 : .4,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(color: a, borderRadius: BorderRadius.circular(18)),
                child: Text(widget.isNew ? 'Add' : 'Save', style: s.body(16, w: FontWeight.w700, color: Colors.black)),
              ),
            ),
          ),
        ),
      ]),
    ]);
  }
}

class _Step extends StatelessWidget {
  const _Step(this.v, this.minus, this.plus, {this.zeroAs});

  final int v;
  final VoidCallback minus, plus;
  final String? zeroAs;

  @override
  Widget build(BuildContext context) {
    final s = context.skin;
    Widget b(IconData i, VoidCallback t) => Press(
          onTap: () {
            HapticFeedback.selectionClick();
            t();
          },
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(shape: BoxShape.circle, color: s.ink.withValues(alpha: .07), border: Border.all(color: s.line)),
            child: Icon(i, size: 20, color: s.ink),
          ),
        );
    return Row(children: [
      b(Icons.remove_rounded, minus),
      SizedBox(
        width: 48,
        child: AnimatedSwitcher(
          duration: dur(context, 160),
          transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: .8, end: 1.0).animate(a), child: c)),
          child: Text(v == 0 && zeroAs != null ? zeroAs! : '$v', key: ValueKey(v), textAlign: TextAlign.center, style: s.disp(20)),
        ),
      ),
      b(Icons.add_rounded, plus),
    ]);
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle(this.on, this.off, this.value, this.color, this.onTap);

  final IconData on, off;
  final bool value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Press(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: AnimatedSwitcher(
            duration: dur(context, 240),
            transitionBuilder: (c, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack), child: c),
            child: Icon(value ? on : off, key: ValueKey(value), size: 28, color: value ? color : context.skin.mute),
          ),
        ),
      );
}

// -------------------------------------------------------------- settings
class _Settings extends StatefulWidget {
  const _Settings();

  @override
  State<_Settings> createState() => _SettingsState();
}

class _SettingsState extends State<_Settings> {
  late final _key = TextEditingController(text: store.tmdbKey);

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _export() async {
    final d = DateTime.now();
    final name = 'mylist-${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}.json';
    try {
      final r = await FilePicker.saveFile(
          fileName: name, bytes: Uint8List.fromList(utf8.encode(store.exportJson())), mimeType: 'application/json');
      if (r != null) _toast('Backup saved');
    } catch (e) {
      _toast('Export failed: $e');
    }
  }

  Future<void> _import() async {
    try {
      final f = await FilePicker.pickFile();
      if (f?.path == null) return;
      final txt = await File(f!.path!).readAsString();
      final n = jsonDecode(txt) is Map ? (jsonDecode(txt)['items'] as List).length : (jsonDecode(txt) as List).length;
      if (!mounted) return;
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Replace your list?'),
          content: Text('This swaps your ${store.items.length} items for $n from the file. Export first if unsure.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Replace')),
          ],
        ),
      );
      if (yes != true) return;
      store.importJson(txt);
      _toast('Imported $n items');
    } catch (e) {
      _toast('That file is not a MyList backup');
    }
  }

  Future<void> _lock(bool v) async {
    if (v && !await LocalAuthentication().isDeviceSupported()) {
      _toast('Set a screen lock / biometric on this device first');
      return;
    }
    store.setLock(v);
  }

  Future<void> _bg() async {
    final f = await FilePicker.pickFile(type: FileType.image);
    if (f?.path != null) await store.setBackground(f!.path);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final s = context.skin;
          final a = glow.value;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Settings', style: s.disp(28)),
            _label(context, 'Look'),
            Row(children: [
              for (final l in Look.values) Expanded(child: _LookTile(l, store.look == l, () => store.setLook(l))),
            ]),
            AnimatedSize(
              duration: dur(context, 260),
              curve: easeOut,
              child: store.look == Look.editorial
                  ? _Row('Dark paper', Switch(value: store.editorialDark, onChanged: store.setEditorialDark, activeThumbColor: a))
                  : const SizedBox(width: double.infinity),
            ),
            _label(context, 'Background image'),
            Row(children: [
              Pill(store.bgPath == null ? 'Choose image' : 'Change', on: false, color: a, icon: Icons.image_outlined, onTap: _bg),
              const SizedBox(width: 8),
              if (store.bgPath != null) Pill('Remove', on: false, color: a, onTap: () => store.setBackground(null)),
            ]),
            if (store.bgPath != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                Text('Dim', style: s.body(13, color: s.mute)),
                Expanded(child: Slider(value: store.bgDim, min: 0, max: .95, activeColor: a, onChanged: store.setDim)),
              ]),
            ],
            _label(context, 'Posters'),
            Panel(
              radius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                controller: _key,
                onSubmitted: store.setTmdb,
                onTapOutside: (_) => store.setTmdb(_key.text),
                style: s.body(14.5),
                cursorColor: a,
                decoration: InputDecoration(
                    border: InputBorder.none, hintText: 'TMDB API key (shows & movies)', hintStyle: s.body(14.5, color: s.mute)),
              ),
            ),
            const SizedBox(height: 4),
            Text('Anime, manga & books work without a key. Stored on this device only.', style: s.body(12, color: s.mute)),
            const SizedBox(height: 10),
            Pill(store.fetching ? 'Fetching… ${store.fetchLeft} left' : 'Retry missing posters',
                on: false, color: a, icon: Icons.photo_library_outlined, onTap: () => store.fetchPosters(retryFailed: true)),
            _label(context, 'Security'),
            _Row('App lock', Switch(value: store.lock, onChanged: _lock, activeThumbColor: a)),
            _label(context, 'Backup'),
            Row(children: [
              Pill('Export', on: false, color: a, icon: Icons.upload_rounded, onTap: _export),
              const SizedBox(width: 8),
              Pill('Import', on: false, color: a, icon: Icons.download_rounded, onTap: _import),
            ]),
            const SizedBox(height: 22),
            Center(child: Text('MyList 0.1.0 · github.com/ArtisticSyndrome/mylist', style: s.body(12, color: s.mute))),
          ]);
        },
      );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.trailing);

  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(label, style: context.skin.body(15))),
        trailing,
      ]);
}

class _LookTile extends StatelessWidget {
  const _LookTile(this.look, this.on, this.onTap);

  final Look look;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.skin;
    final c = glow.value;
    final (bg, card, ink) = switch (look) {
      Look.amoled => (Colors.black, const Color(0xFF16161B), Colors.white),
      Look.editorial => (const Color(0xFFF4EFE6), const Color(0xFFFBF8F2), const Color(0xFF1B1A17)),
      Look.glass => (const Color(0xFF2A1B5E), Colors.white24, Colors.white),
    };
    return Press(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedScale(
        scale: on ? 1 : .94,
        duration: dur(context, 260),
        curve: easeOut,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(children: [
            AnimatedContainer(
              duration: dur(context, 260),
              curve: easeOut,
              height: 92,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bg,
                gradient: look == Look.glass
                    ? const LinearGradient(colors: [Color(0xFF2A1B5E), Color(0xFF0E3A4D)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : null,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: on ? c : s.line, width: on ? 2 : 1),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Aa', style: TextStyle(color: ink, fontSize: 17, fontWeight: FontWeight.w700, fontFamily: look == Look.editorial ? 'serif' : null)),
                const Spacer(),
                for (var i = 0; i < 2; i++)
                  Container(
                      height: 14,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(look == Look.editorial ? 4 : 7),
                          border: Border.all(color: ink.withValues(alpha: .12)))),
              ]),
            ),
            const SizedBox(height: 8),
            Text(look.label, style: s.body(12.5, w: on ? FontWeight.w700 : FontWeight.w500, color: on ? s.ink : s.mute)),
          ]),
        ),
      ),
    );
  }
}
