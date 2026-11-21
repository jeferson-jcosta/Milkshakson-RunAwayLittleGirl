# Milkshakson - Run Away Little Girl (WoW: Forever)

*"Run away, little girl! Run away!"* A "rearview mirror" that shows the mobs still chasing you while you flee. The mob on you appears as a live 3D model with its name, its health bar and "on you" when it is targeting you. When more mobs are chasing you, the mirror keeps the same size and shows a red **+N** badge with how many more.

## When it shows up
All of these must be true:
1. You are in combat.
2. You have been running for at least **2 s** (`/rv secs`).
3. The game's own **low-health warning** (red screen edges) is on. The game decides when you're low; the addon only listens to it.
4. At least one hostile mob with a nameplate is chasing you.

Once shown, the mirror stays up until no mob is chasing you, or until you leave combat. Then it shows **"The little girl got away!"** for a moment and hides.


## Position
By default the mirror sits right under your player frame, and it follows that frame if you move it in Edit Mode. Once you drag the mirror, it stays where you put it. `/rv reset` puts it back under the player frame.

## Options
Options > AddOns > **Milkshakson > Run Away Little Girl**, or `/mrv config` (also `/rv config`), or right-click the addon button next to the minimap. From there you can:
- Set the running seconds and "only when running".
- Toggle the sounds.
- Lock the mirror.
- Move/resize, test or reset it.
- Pick the language.

## Install
Copy `Milkshakson-RunAwayLittleGirl` to `World of Warcraft\_forever_\Interface\AddOns\` and enable it on the AddOns screen.

## Commands
| Command | Action |
|---|---|
| `/rv` | Status + help |
| `/rv test` | Preview using your current target, without combat |
| `/rv move` | Positioning mode: shows the mirror (with your own model) so you can drag it and resize it from the corner. Run it again to finish |
| `/rv lock` | Lock/unlock dragging. When unlocked (default) the mirror can be dragged any time it is visible |
| `/rv reset` | Back to the default spot under your player frame, default size |
| `/rv secs <n>` | Seconds running before it activates (default 2) |
| `/rv sound` | Toggle the alert and "escaped" sounds |
| `/rv lang <code\|auto>` | Language (enUS, ptBR) |

Aliases: `/mrv`, `/runaway`, `/mrunaway`, `/runawaylittlegirl`, `/retrovisor`. Every `/rv` command also works as `/mrv`, e.g. `/mrv move`.

## Requirements and limits
- **Enemy nameplates must be on** (default key: `V`). The addon finds mobs through their nameplates, so a mob outside nameplate range is not shown. In practice it is already far behind.
- WoW has no API for a real rear camera. The "mirror" shows each mob's own model instead.
- On the Forever/Midnight client the game can hide some combat values from addons ("secret values"). The addon checks each one:
  - Your own health is never read: the game's low-health warning is the trigger, so hidden health doesn't matter.
  - If a mob's target and threat are both hidden, any hostile mob in combat counts as chasing you.
  - Mob names and health bars still display, because hidden values can be passed straight to the UI.

## Support / Apoie
If you enjoy the addon, you can buy me a coffee. The same links are in the in-game options panel, in copyable fields.
- **PayPal:** [Donate](https://www.paypal.com/donate/?business=Q72ZP8CCJ6PFA&no_recurring=0&item_name=Buy+me+a+coffee+to+keep+my+WoW+Forever+addons+updated%21+%2F+Me+pague+um+caf%C3%A9+e+ajude+a+manter+os+addons+atualizados%21&currency_code=BRL)
- **PIX (Brasil):** `2d8f2ae7-76df-497d-9afa-cb7d12dd73f9`

## Sounds
- **When the mirror appears:** the Big Bad Wolf's *"Run away, little girl! Run away!"* (Karazhan opera). It plays together with the mirror, when the game's low-health warning fires.
- **When you get away:** your character's laugh (race and gender).
