# Design notes

Timbre should feel like a small printed music magazine that happens to play
files. The rules below keep it coherent.

## Voice

Short, warm, plain. Say what a control does. No hype, no exclamation marks, no
filler. A listener should never wonder what a row does.

## Type

- Titles: Instrument Serif, tight leading, slight negative tracking.
- Everything else: Instrument Sans at 11 to 15, medium weights.
- Numbers and times: tabular figures via `context.numeric`.
- Overlines: uppercase, letter spaced, 10 to 11.

## Color

- Ink `#0A0B0D` and paper `#F6F3EC` are the two canvases.
- One accent at a time. Eight choices, default Ember `#E0562D`.
- Accent is used for the play control, progress, selection, and one wash per
  screen. Never as a gradient across body text.
- Covers may tint the player background and, if enabled, the whole app.

## Shape and space

- Radii: 8, 12, 18, 26, and full pill for controls.
- Hairlines at 8 to 12 percent opacity separate rows. Avoid cards inside cards.
- Page padding 20. Section gaps 22 to 30. Touch targets at least 44.

## Motion

- Page transitions: 320 ms, ease out cubic, small fade and rise.
- Press: scale to 0.96, 120 ms.
- Player skin change: 420 ms cross fade.
- Bars and vinyl only animate while playing, and stop when paused.

## Player skins

- **Sleeve:** cover art with a soft gradient, title, artist, technical line.
- **Vinyl:** black disc with fine grooves, cover as the label, tonearm resting on
  the outer groove. Rotates only while playing.
- **Spectrum:** a card of 40 rounded bars driven by a smooth pseudo spectrum.
  Reads as a visualizer, not a fake analyzer.

## Home

When the library is empty, Home teaches: scan or import, and what the app does.
When there is music, Home becomes a dashboard: pick up again, week card with goal
ring, mixes, recently added, on repeat, recap.

## What to avoid

- Purple gradients, glows, gradient text, emoji labels.
- Generic "AI" dashboards and charts with no meaning.
- Rows that lead nowhere. Every row opens a page or changes a setting.
- Fake features. If the phone cannot do it, say so.
