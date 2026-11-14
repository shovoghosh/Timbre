# Timbre

Timbre is a music player for the songs you already own. It reads the audio on
your phone, keeps everything on the device, and gives the music a calm, editorial
frame. No account, no ads, no uploads.

This is an original app. It shares no code, name, icon, or screen design with
any other player.

## Download

The latest build is on the
[Releases page](https://github.com/shovoghosh/Timbre/releases). Install the APK
on an Android phone. iPhone needs a build made with Xcode, since Apple does not
allow installing apps from a file.

## What it does

- **Library that stays local.** Scans the folders you allow, reads embedded tags
  and cover art, and never copies a file without asking.
- **Four places to be.** Home, Library, Search, and You.
- **Home that knows you.** A pick up again card, a weekly listening card with a
  goal ring, generated mixes, recently added albums, on repeat, and a recap.
- **Three player skins.** Sleeve (art and type), Vinyl (a disc with a tonearm),
  and Spectrum (bars that move with the audio).
- **Queue, lyrics, sleep timer, speed, repeat, shuffle.** Lyrics read LRC files or
  custom text. The sleep timer fades out. Per song speed is remembered.
- **Playlists, favorites, ratings, smart lists.** Make a list, add songs from the
  library, and see favorites, recently played, and on repeat.
- **Listening stats and a shareable recap.** Minutes, streaks, top artists,
  albums, genres, the busiest hour, and a weekly story card.
- **Equalizer where the phone allows it.** Real device bands, presets, bass
  boost, and a way into the system sound panel. iOS does not expose an equalizer
  to apps, so the page says so.
- **Cover search.** Look up a cover online (iTunes or Deezer), or choose a
  picture from your files. The file's own art is one tap away.
- **Appearance.** Auto, light, dark, and black themes, eight accents, an accent
  that follows the cover, frosted bars, and haptics.
- **Backup and restore.** One JSON file with settings, playlists, favorites,
  ratings, lyrics, and history. Music files are never included.
- **Background playback.** A media notification, lock screen controls, headset
  pause and resume, and soft fades.

## Design

Editorial, not glossy. Instrument Serif for titles, Instrument Sans for
everything else, a near black ink and a warm paper canvas, one accent at a time,
hairlines instead of boxes, and motion that settles quickly.

The eight accents: Ember, Amber, Olive, Tide, Cobalt, Iris, Rose, Sand. The
default is Ember. Both fonts are bundled so the app works offline.

## Build

Requires Flutter 3.47 or newer, Android SDK 37 for Android builds, and Xcode for
iOS.

```bash
flutter pub get
flutter run
flutter test
```

Release builds:

```bash
flutter build appbundle --release   # Play Store
flutter build ipa --release         # App Store, on macOS
```

### Signing

Android release signing is read from `android/key.properties`. Copy
`android/key.properties.example` and fill in your keystore. Without that file,
release builds fall back to debug keys so local builds work; do not upload a
debug signed build.

```bash
keytool -genkey -v -keystore timbre-release.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias timbre
```

For iOS, open `ios/Runner.xcworkspace`, set your team and bundle identifier, then
archive.

## Project layout

```
lib/
  app.dart                 root widget and theme wiring
  core/                    prefs, services, formatting, haptics
  theme/                   color tokens, type scale, theme controller
  data/
    models/                track, playlist, play event
    library/               scan, tags, artwork, import, stores, cover search
    history/               plays database and stats
    settings/              app settings and backup
  audio/                   playback controller and device effects
  ui/
    shell/                 tabs, bottom nav, mini player
    pages/                 home, library, search, you, player, pages
    player/                skins, scrubber, queue, lyrics, timers
    widgets/               shared pieces
android/                   Kotlin MediaStore + audio effects channels
ios/                       Runner, background audio, file sharing
test/                      unit tests for stats, lyrics, tags, formatting
scripts/                   demo audio, brand assets, store screenshots
docs/                      privacy, store checklist, design notes
```

## Data and privacy

The library, playlists, history, and settings stay on the phone. Timbre goes
online only when you open cover search, and then it sends the words in the search
box to the public iTunes and Deezer search APIs. There is no account, no
analytics, and no ad SDK. See [docs/PRIVACY.md](docs/PRIVACY.md).

## Known limits

- The equalizer is Android only. Band count follows the device, usually five.
- Crossfade is a soft fade out and in between songs, not an overlap.
- Gesture navigation and three button navigation are both supported.
- Home screen widgets are planned, not shipped.

## License

Timbre is released under the [Timbre License 1.0](LICENSE). It is free to use
and to share with people you know. Changing it, republishing it, or putting it
on a store needs written permission from the author.

The app code and brand are original work. Bundled fonts, Instrument Serif and
Instrument Sans, are used under the SIL Open Font License; the license files are
in `assets/fonts/`. Third party package licenses are available in the app under
You, About, Licenses.
