# MyList

A fluid, good-looking personal tracker for everything you watch, read and play — anime, shows, movies, manga, books, games, even the streaming sites you rely on. Built with Flutter. Local-first, no account.

> Replaces the password-protected Word file. Same idea, with springs.

## Features (v0.1)

- 8 sections: Anime, Other Animated, Live Action, Manga, Doujin, Sites, Books, Games
- 5 statuses per item — To-do / Ongoing / Waiting (next season) / Done / Dropped — plus a free-text note and optional progress counter
- Favourite, flag, 5-star rating
- Search, status filter, sort
- Poster lookup: Jikan (anime/manga, no key) and TMDB (shows/movies, your own free key in Settings)
- 3 looks — **AMOLED**, **Editorial**, **Glass** — switchable, plus a custom background image
- App lock (biometric / device PIN)
- Export / import JSON backup

## Run

```bash
flutter pub get
flutter run            # pick a device
```

### Your own data

The repo ships an empty `assets/seed/sample.json`. To pre-load a list on first launch, drop a `my_list.json` next to it (gitignored) — same shape as an export file. Or just import a backup from Settings.

### TMDB posters

Get a free key at <https://www.themoviedb.org/settings/api> and paste it in **Settings → TMDB key**. It's stored on-device only.

## TODO

- [ ] Cloud sync across devices (Firebase / Drive appdata)
- [ ] Seasons/episodes tracker per item
- [ ] Home-screen widget
- [ ] iOS build

## License

MIT
