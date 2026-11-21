# Changelog - Milkshakson - Run Away Little Girl

## Unreleased
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
