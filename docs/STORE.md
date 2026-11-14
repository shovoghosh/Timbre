# Store checklist

Everything needed to publish Timbre on Google Play and the App Store. The app
name, package, and bundle id are already set.

## Identity

| Item | Value |
| --- | --- |
| Name | Timbre |
| Android package | `com.samlabs.timbre` |
| iOS bundle id | `com.samlabs.timbre` |
| Version | 1.0.0 (build 1) |
| Category | Music and Audio |
| Price | Free |
| Ads | None |
| In-app purchases | None |
| Account required | No |

## Play Store listing

**App name (30 max)**

Timbre: Offline Music

**Short description (80 max)**

Play the music on your phone. Local files, real covers, no account.

**Full description**

Timbre is a player for the music you already own.

Point it at the folders you keep your songs in, and it builds a library from the
tags and cover art inside your files. Nothing is uploaded. There is no account,
no ads, and no subscription.

WHAT YOU GET

- A home screen that picks up where you left off, shows your week, and builds
  mixes from what you actually play.
- Four ways to listen: Sleeve, Vinyl, and Spectrum player skins, plus a queue you
  can reorder.
- Lyrics from LRC files or your own text, a sleep timer that fades out, per song
  speed, shuffle, repeat, and soft fades.
- Playlists, favorites, star ratings, recently played, and on repeat.
- Listening stats: minutes, streaks, top artists, albums, genres, and your
  busiest hour.
- A weekly recap card you can share.
- Cover search, or choose a picture from your files.
- Auto, light, dark, and black themes with eight accents. The accent can follow
  the current cover.
- A real equalizer with presets and bass boost on phones that allow it.
- Backup and restore to move your setup to a new phone.

GOOD TO KNOW

- Timbre plays files, it does not stream or sell music.
- The equalizer is Android only. iPhone does not let apps change the system
  equalizer.
- Everything works offline except cover search.

**Keywords**

local music player, offline music, mp3 player, flac, no ads, album art, music
library, equalizer

## Data safety answers (Play)

- Does your app collect or share any required user data types? **Cover search
  queries are sent to iTunes and Deezer when the user searches.** Declare search
  terms as shared for app functionality, not collected, not linked to identity.
- Data collected: none.
- Data shared: search terms (user initiated, app functionality).
- Data encrypted in transit: yes (HTTPS).
- Data deletion request: not applicable, everything is local. The user can clear
  the library or uninstall.
- Ads: no. Analytics: no. Crash reporting: no.

## App Store privacy answers

- Data not collected.
- Data linked to you: none.
- Tracking: no.
- Third party requests: cover search only.

## Screenshots

Google Play wants 2 to 8 phone screenshots, 320 to 3840 px, 9:16 portrait.
App Store wants 6.9 inch and 6.5 inch sets, portrait.

Capture on the phone at 1440x3120 with the status bar hidden, then frame them at
1080x1920:

```powershell
$adb = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"

# Hide the status bar while capturing, then put it back.
& $adb shell settings put global policy_control immersive.status=*

# One capture per screen, named NN_screen.png, into shots\store_src.
& $adb exec-out screencap -p > shots\store_src\01_home.png
# ...02_player_sleeve, 03_player_vinyl, 04_search, 05_you, 06_equalizer

& $adb shell settings put global policy_control null

powershell -ExecutionPolicy Bypass -File scripts\make_store_shots.ps1
```

The script reads every `shots\store_src\NN_name.png`, adds the brand, headline,
and phone frame, crops the Android navigation bar, and writes
`store\shots\NN_name.png`. It skips files without a caption in the script, so
add a caption there when you add a new screen.

Use these screens, in order:

1. Home, with the week card and a mix visible.
2. Player, Sleeve skin with a demo cover.
3. Player, Vinyl skin.
4. Search results for a demo album.
5. You, with playlists and saved lists.
6. Equalizer or Appearance.

Use only the generated demo art. Do not include other artists' cover art in
store images.

Take the captures with playback running, so the mini player is in frame, and
capture each screen without running `uiautomator dump` first. The dump turns on
Flutter's accessibility tree, which draws a green focus border around the app
until it is restarted.

## Graphics

| Asset | Size | Where |
| --- | --- | --- |
| App icon | 512x512 | `assets/brand/play_store_icon.png` |
| Adaptive icon | 1024x1024 | generated in `android/app/src/main/res` |
| Feature graphic | 1024x500 | `store/feature_graphic.png` |
| App Store icon | 1024x1024 | `assets/brand/icon.png` |

Generate the feature graphic with:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\make_store_assets.ps1
```

## Release steps

1. Bump `version` in `pubspec.yaml`.
2. Create `android/key.properties` from the example and point it at your keystore.
3. `flutter build appbundle --release`
4. Upload `build/app/outputs/bundle/release/app-release.aab`.
5. Fill in the listing, data safety, and content rating.
6. Set the privacy policy URL to the hosted `docs/PRIVACY.md`.
7. For iOS, open the workspace, set the team, archive, and upload.

`android/app/src/main/res/raw/keep.xml` keeps the media notification icons that
audio_service looks up by name. Without it, release builds throw while building
the notification, and the lock screen and media card stay empty. Always test a
release build on a phone before uploading.

## Content rating

Everyone. No user generated content is shared, no ads, no purchases, no location,
no personal information.
