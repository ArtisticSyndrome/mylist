import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'theme.dart';

enum Sort { order, az, rating, status, newest }

extension SortX on Sort {
  String get label => const ['List order', 'A–Z', 'Rating', 'Status', 'Newest'][index];
}

/// App state. One global instance (`store`) — a single-screen app doesn't need a DI layer.
class Store extends ChangeNotifier {
  List<Item> items = [];
  Look look = Look.amoled;
  bool editorialDark = false;
  String? bgPath;
  double bgDim = .55;
  String tmdbKey = '';
  bool lock = false;
  Sort sort = Sort.order;
  bool fetching = false;
  int fetchLeft = 0;

  late final SharedPreferences _p;
  late final Directory _dir;
  Timer? _saveT;

  File get _file => File('${_dir.path}/mylist.json');

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    _dir = await getApplicationDocumentsDirectory();
    look = Look.values.byName(_p.getString('look') ?? 'amoled');
    editorialDark = _p.getBool('edDark') ?? false;
    bgPath = _p.getString('bg');
    if (bgPath != null && !File(bgPath!).existsSync()) bgPath = null;
    bgDim = _p.getDouble('dim') ?? .55;
    tmdbKey = _p.getString('tmdb') ?? '';
    lock = _p.getBool('lock') ?? false;
    sort = Sort.values.byName(_p.getString('sort') ?? 'order');
    if (_file.existsSync()) {
      items = _decode(await _file.readAsString());
    } else {
      // first launch: private seed if the dev dropped one in, else the empty sample
      for (final a in ['assets/seed/my_list.json', 'assets/seed/sample.json']) {
        try {
          items = _decode(await rootBundle.loadString(a));
          break;
        } catch (_) {}
      }
      _save();
    }
  }

  List<Item> _decode(String s) {
    final j = jsonDecode(s);
    final list = (j is Map ? j['items'] : j) as List;
    return [for (final e in list) Item.fromJson(e as Map<String, dynamic>)];
  }

  String exportJson() => const JsonEncoder.withIndent(' ').convert({'version': 1, 'items': items});

  int importJson(String s) {
    items = _decode(s);
    _changed();
    return items.length;
  }

  // ---- queries -----------------------------------------------------------
  int count(Cat c, [Status? s]) => items.where((i) => i.cat == c && (s == null || i.status == s)).length;

  List<Item> view(Cat? cat, {String q = '', Status? status, bool fav = false, bool flag = false}) {
    final qq = q.trim().toLowerCase();
    final l = items.where((i) {
      if (cat != null && i.cat != cat) return false;
      if (status != null && i.status != status) return false;
      if (fav && !i.fav) return false;
      if (flag && !i.flag) return false;
      return qq.isEmpty || i.title.toLowerCase().contains(qq) || i.note.toLowerCase().contains(qq);
    }).toList();
    const rank = [2, 0, 1, 4, 5]; // ongoing, waiting, todo, done, dropped
    switch (sort) {
      case Sort.order:
        break;
      case Sort.az:
        l.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case Sort.rating:
        l.sort((a, b) => b.rating.compareTo(a.rating));
      case Sort.status:
        l.sort((a, b) => rank[a.status.index].compareTo(rank[b.status.index]));
      case Sort.newest:
        l.sort((a, b) => b.added.compareTo(a.added));
    }
    return l;
  }

  // ---- mutations ---------------------------------------------------------
  void _changed() {
    notifyListeners();
    _saveT?.cancel();
    _saveT = Timer(const Duration(milliseconds: 400), _save);
  }

  Future<void> _save() async {
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(exportJson());
    await tmp.rename(_file.path); // atomic-ish: never leaves a half-written file
  }

  void upsert(Item it) {
    final i = items.indexWhere((e) => e.id == it.id);
    if (i < 0) {
      items.add(it);
    } else {
      final old = items[i];
      if (old.title != it.title || old.cat != it.cat) it.poster = null; // re-lookup
      items[i] = it;
    }
    _changed();
    fetchPosters();
  }

  void remove(Item it) {
    items.removeWhere((e) => e.id == it.id);
    _changed();
  }

  void restore(Item it) {
    items.add(it);
    items.sort((a, b) => a.added.compareTo(b.added));
    _changed();
  }

  void toggleDone(Item it) {
    it.status = it.status == Status.done ? Status.todo : Status.done;
    _changed();
  }

  Item blank(Cat c) => Item(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: '',
      cat: c,
      added: items.fold<int>(0, (m, e) => e.added > m ? e.added : m) + 1);

  // ---- settings ----------------------------------------------------------
  void setLook(Look l) {
    look = l;
    _p.setString('look', l.name);
    notifyListeners();
  }

  void setEditorialDark(bool v) {
    editorialDark = v;
    _p.setBool('edDark', v);
    notifyListeners();
  }

  void setSort(Sort s) {
    sort = s;
    _p.setString('sort', s.name);
    notifyListeners();
  }

  void setDim(double v) {
    bgDim = v;
    _p.setDouble('dim', v);
    notifyListeners();
  }

  void setLock(bool v) {
    lock = v;
    _p.setBool('lock', v);
    notifyListeners();
  }

  void setTmdb(String k) {
    tmdbKey = k.trim();
    _p.setString('tmdb', tmdbKey);
    notifyListeners();
    fetchPosters();
  }

  Future<void> setBackground(String? src) async {
    final old = bgPath;
    if (src == null) {
      bgPath = null;
      _p.remove('bg');
    } else {
      final dot = src.lastIndexOf('.');
      final dest = '${_dir.path}/bg_${DateTime.now().millisecondsSinceEpoch}${dot < 0 ? '' : src.substring(dot)}';
      await File(src).copy(dest);
      bgPath = dest;
      _p.setString('bg', dest);
    }
    if (old != null) File(old).delete().catchError((_) => File(old));
    notifyListeners();
  }

  // ---- posters -----------------------------------------------------------
  static final _noise = RegExp(r'\(.*?\)|\b(movie )?series\b|\bcollection\b|\btrilogy\b|\blive action\b', caseSensitive: false);

  bool _canLookup(Item i) => switch (i.cat) {
        Cat.anime || Cat.manga || Cat.books => true,
        Cat.animated || Cat.live => tmdbKey.isNotEmpty,
        _ => false,
      };

  void clearPoster(Item it) {
    it.poster = '';
    _changed();
  }

  void refetch(Item it) {
    it.poster = null;
    _changed();
    fetchPosters();
  }

  /// Background queue: Jikan allows ~1 req/s, so one item per ~1.1s.
  Future<void> fetchPosters({bool retryFailed = false}) async {
    if (fetching) return;
    if (retryFailed) {
      for (final i in items.where((i) => i.poster == '')) {
        i.poster = null;
      }
    }
    final todo = items.where((i) => i.poster == null && _canLookup(i)).toList();
    if (todo.isEmpty) return;
    fetching = true;
    fetchLeft = todo.length;
    notifyListeners();
    var errs = 0;
    for (final it in todo) {
      try {
        it.poster = await _lookup(it) ?? '';
        errs = 0;
      } catch (_) {
        if (++errs >= 5) break; // offline / blocked: stop, retry next launch
      }
      fetchLeft--;
      notifyListeners();
      _saveT?.cancel();
      _saveT = Timer(const Duration(seconds: 2), _save);
      await Future.delayed(const Duration(milliseconds: 1100));
    }
    fetching = false;
    notifyListeners();
  }

  Future<String?> _lookup(Item it) async {
    final q = Uri.encodeQueryComponent(it.title.replaceAll(_noise, ' ').replaceAll(RegExp(r'\s+'), ' ').trim());
    switch (it.cat) {
      case Cat.anime || Cat.manga:
        final r = await _get('https://api.jikan.moe/v4/${it.cat == Cat.anime ? 'anime' : 'manga'}?q=$q&limit=1');
        final d = (jsonDecode(r)['data'] as List);
        return d.isEmpty ? null : d[0]['images']['jpg']['large_image_url'] as String?;
      case Cat.animated || Cat.live:
        final bearer = tmdbKey.length > 40; // v4 token vs v3 key
        final r = await _get(
            'https://api.themoviedb.org/3/search/multi?query=$q${bearer ? '' : '&api_key=$tmdbKey'}',
            headers: bearer ? {'Authorization': 'Bearer $tmdbKey'} : null);
        for (final e in jsonDecode(r)['results'] as List) {
          if (e['media_type'] != 'person' && e['poster_path'] != null) {
            return 'https://image.tmdb.org/t/p/w342${e['poster_path']}';
          }
        }
        return null;
      case Cat.books:
        final r = await _get('https://openlibrary.org/search.json?q=$q&limit=1&fields=cover_i');
        final d = (jsonDecode(r)['docs'] as List);
        return d.isEmpty || d[0]['cover_i'] == null ? null : 'https://covers.openlibrary.org/b/id/${d[0]['cover_i']}-L.jpg';
      default:
        return null;
    }
  }

  Future<String> _get(String url, {Map<String, String>? headers}) async {
    for (var tries = 0;; tries++) {
      final r = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 12));
      if (r.statusCode == 429 && tries < 2) {
        await Future.delayed(const Duration(seconds: 3));
        continue;
      }
      if (r.statusCode != 200) throw HttpException('${r.statusCode}');
      return r.body;
    }
  }
}

final store = Store();
