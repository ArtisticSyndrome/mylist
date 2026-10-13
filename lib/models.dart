import 'package:flutter/material.dart';

enum Cat { anime, animated, live, manga, doujin, sites, books, games }

enum Status { todo, ongoing, waiting, done, dropped }

enum _Kind { watch, read, play, site }

const _labels = {
  _Kind.watch: ['To watch', 'Watching', 'Waiting', 'Watched', 'Dropped'],
  _Kind.read: ['To read', 'Reading', 'Waiting', 'Read', 'Dropped'],
  _Kind.play: ['To play', 'Playing', 'Waiting', 'Finished', 'Dropped'],
  _Kind.site: ['Unchecked', 'Using', 'Shaky', 'Alive', 'Dead'],
};

extension CatX on Cat {
  String get label => const {
        Cat.anime: 'Anime',
        Cat.animated: 'Animated',
        Cat.live: 'Live Action',
        Cat.manga: 'Manga',
        Cat.doujin: 'Doujin',
        Cat.sites: 'Sites',
        Cat.books: 'Books',
        Cat.games: 'Games',
      }[this]!;

  IconData get icon => const {
        Cat.anime: Icons.auto_awesome_rounded,
        Cat.animated: Icons.animation_rounded,
        Cat.live: Icons.movie_filter_rounded,
        Cat.manga: Icons.menu_book_rounded,
        Cat.doujin: Icons.local_fire_department_rounded,
        Cat.sites: Icons.public_rounded,
        Cat.books: Icons.auto_stories_rounded,
        Cat.games: Icons.sports_esports_rounded,
      }[this]!;

  Color get accent => const {
        Cat.anime: Color(0xFFFF5D8F),
        Cat.animated: Color(0xFFF5B83D),
        Cat.live: Color(0xFFFF7A45),
        Cat.manga: Color(0xFF2EC4B6),
        Cat.doujin: Color(0xFFD45CFF),
        Cat.sites: Color(0xFF4D8DFF),
        Cat.books: Color(0xFFD4A373),
        Cat.games: Color(0xFF6EE7A0),
      }[this]!;

  _Kind get _kind => switch (this) {
        Cat.anime || Cat.animated || Cat.live => _Kind.watch,
        Cat.manga || Cat.doujin || Cat.books => _Kind.read,
        Cat.games => _Kind.play,
        Cat.sites => _Kind.site,
      };

  String statusLabel(Status s) => _labels[_kind]![s.index];
}

extension StatusX on Status {
  Color get color => const [
        Color(0xFF8A8F9C),
        Color(0xFF4DA3FF),
        Color(0xFFFFB547),
        Color(0xFF3DDC97),
        Color(0xFFFF5D73),
      ][index];
}

class Item {
  Item({
    required this.id,
    required this.title,
    required this.cat,
    this.status = Status.todo,
    this.note = '',
    this.progress = 0,
    this.total = 0,
    this.rating = 0,
    this.fav = false,
    this.flag = false,
    this.poster,
    required this.added,
  });

  final String id;
  String title, note;
  Cat cat;
  Status status;
  int progress, total, rating; // total 0 = unknown
  bool fav, flag;

  /// null = not looked up yet, '' = lookup failed / none, else image url
  String? poster;
  final int added;

  Item copy() => Item(
        id: id,
        title: title,
        cat: cat,
        status: status,
        note: note,
        progress: progress,
        total: total,
        rating: rating,
        fav: fav,
        flag: flag,
        poster: poster,
        added: added,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'cat': cat.name,
        'status': status.name,
        'note': note,
        'progress': progress,
        'total': total,
        'rating': rating,
        'fav': fav,
        'flag': flag,
        'poster': poster,
        'added': added,
      };

  factory Item.fromJson(Map<String, dynamic> j) => Item(
        id: j['id'] as String,
        title: j['title'] as String,
        cat: Cat.values.byName(j['cat'] as String),
        status: Status.values.byName((j['status'] as String?) ?? 'todo'),
        note: (j['note'] as String?) ?? '',
        progress: (j['progress'] as int?) ?? 0,
        total: (j['total'] as int?) ?? 0,
        rating: (j['rating'] as int?) ?? 0,
        fav: (j['fav'] as bool?) ?? false,
        flag: (j['flag'] as bool?) ?? false,
        poster: j['poster'] as String?,
        added: (j['added'] as int?) ?? 0,
      );
}
