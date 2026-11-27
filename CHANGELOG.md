# Changelog - Milkshakson - Run Away Little Girl

## Unreleased
- Fishing: **Nat Pagle and the pole hide while you fish** — they only show with the pole equipped and no cast going (the "you are not fishing" reminder).
- Fishing: **fishing skill up** — the new level ("Fishing 76") rises in blue from the middle of the screen. Option on, with a test button.
- Fishing: **Nat Pagle and the fishing pole can be moved and resized**, each on its own: untick "Lock Nat and the pole", both show (outlined, with a name), drag to move, pull the corner to resize (the pole stays round); tick again when done. "Reset their position" puts them back in the middle.
- Options: changing the language changes the options page right away (it used to need /reload) — MilkshaksonUI v9.
- Fishing options: show Nat Pagle, show the fishing pole, play the warning — each on or off; **Test everything** shows both for 8 seconds (no pole needed) and plays the warning.
- **Fishing pole warning**: with a fishing pole equipped, a warning sound plays — the game's "quest failed" horn by default, an alarm clock, the raid warning, or **spoken** ("You have a fishing pole equipped but you are not fishing.") with the game's text to speech and the voice set in Options > Accessibility (Options) — and Nat Pagle calls you, **in combat** — at once when the fight starts, then every 8 seconds while it lasts — and out of combat after a minute without fishing, then every minute, until you cast again or take the pole off. Option "Warning sound: in combat, or 1 minute without fishing" (on), with a test button.
- **Nat Pagle while fishing**: while a fishing pole is equipped, Nat Pagle (the game's own animated NPC model: he fishes, and now and then talks, waves or cheers) shows in the middle of the screen with a round fishing pole icon at his feet, so you remember to switch back to your weapon. Visual only, takes no clicks. If his model can't be loaded, only the pole icon shows. Option "Fishing" > "Nat Pagle and a fishing pole in the middle of the screen" (on).

## 2.4.2
- Options: "Buy me a coffee" moved to the top of the page, highlighted, with PayPal and PIX buttons that show the link ready to copy (addons can't open the browser). Shared UI library v8.

## 2.4.1
- With more than one chaser the mirror no longer widens: it keeps one mob (the one on you first) and shows a red **+N** badge with how many more are chasing you.

## 2.4.0
- Trigger is only the game's own low-health warning; the health % setting (`/rv hp`) and the hidden-alpha mode were removed.
- Mirror and wolf line always appear together.

## 2.3.0
- When the game hides your health, the game's own low-health warning is the trigger: it shows the mirror, starts the chase and plays the wolf line at the same moment.
- Without that warning on the client, falls back to the silent health-% gate.

## 2.2.0
- With hidden health, the wolf line plays when the game's own low-health warning fires during a chase (the mirror is already visible by then).
- `/mrv debug` shows whether the low-health warning is available.

## 2.1.3
- Tries to play the wolf line at the exact moment the mirror becomes visible, if the client allows reading it back.

## 2.1.2
- The wolf line only plays when the mirror is confirmed visible.

## 2.1.1
- The run timer starts at the pull (walking up to a mob no longer counts).
- 3D models follow the mirror's visibility.

## 2.1.0
- Option "Only when I'm running away".
- Escape message: "The little girl got away!".

## 2.0.1
- Wolf line from Deadly Boss Mods' copy when available (classic clients may lack it).

## 2.0.0
- Renamed from Rearview to Run Away Little Girl.
- "Run away, little girl!" (Big Bad Wolf) when the mirror appears.

## 1.7.0
- Character laugh (race/gender) when you get away; nothing on kill or death.

## 1.6.0
- Works with health/speed hidden in combat (movement events; the game applies the health limit to the mirror's visibility).

## 1.4.0
- Removed the "always show" option.

## 1.3.0
- Options panel, close button in test/move mode, "Stop test".

## 1.2.0
- Default position under the player frame, drag anywhere.

## 1.1.0
- Resizable mirror.

## 1.0.0
- Rearview mirror showing mobs still chasing you while fleeing at low health.
