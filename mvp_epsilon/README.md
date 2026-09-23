# MVP Epsilon — M2 Prototype

Godot 4 prototype for **Milestone M2** of *Mostly Hot Air*. Design spec: [`../H2_DESIGN.md`](../H2_DESIGN.md).

Goal of M2: a juicy, 1→4-player-scalable vertical slice of the *Tense Shared-Vehicle
Coordination Journey* — built and tested solo (one avatar does every task).

## Status — Etappe M2-E6

> Stream-field navigation + Stoss-Ruder + mountains, ported from `mvp_delta`.
> Brenner + fuel pool. Hand-placed mountain hazards. Follow camera with vertical damping.

Implemented:
- **World** (`level.gd`): ground, goal flag at +800 m east, 5 hand-placed mountains
  using `mvp_delta`'s exact `MOUNTAINS` layout and organic-silhouette math.
- **Wind field**: continuous 2D vector field (`f(x, z)` = superposed sines from
  `mvp_delta`), altitude attenuation, mountain swirl + outward push deflection.
- **Balloon** (`balloon.gd`): drifts with `wind_at()`, lifts under burner, sinks
  passively at 8 m/s; fuel pool depletes while burning; 3-hit hull damage on
  mountain contact; glide-to-ground at empty fuel; ground touch ends the run
  (win in goal zone, loss outside).
- **Stations** — three now functional:
  - **Brenner** (`station_brenner.gd`): continuous lift while occupied.
  - **Stoss-Ruder** (`station_ruder.gd`): one-shot perpendicular nudge,
    direction taken from the stick at the moment of press, ~3.5 s cooldown.
  - **Ballast** (`station_ballast.gd`): one-shot upward kick; 3 bags per run.
- **Camera** (`camera_rig.gd`): 45° schräg-Draufsicht, target-oriented (looks
  toward goal), vertical damping per H1_DESIGN §9. `snap_to_follow()` for
  pre-warm at run start.
- **HUD** (`hud.gd`): wind-direction arrow, drift speed, fuel bar, hull pips,
  ballast count, distance to goal; win/loss banner.
- **Run lifecycle**: `R` resets; win/loss banner appears; physics halts.

**Testable:** solo player takes off, navigates the stream field, dodges or
takes hull damage from mountains, lands in goal zone (win) or runs out of
fuel and glides into the dirt (loss).

## Controls

| Input | Action |
|---|---|
| WASD / arrows / left stick | Walk in basket (screen-relative — W is always "up on screen"). The avatar turns to face where you push; its visor + eyes show the look direction (cosmetic). |
| Space / E / gamepad A (hold) | Occupy any station whose **floor ring you are standing in** — facing doesn't matter. The ring brightens when you're inside it; once grabbed, only leaving range drops it. |
| F / gamepad X | Secondary (nudge at Ruder, drop sandbag at Ballast) |
| R / gamepad Back | Reset run |

## Run

```sh
# editor
godot --path mvp_epsilon -e

# play directly
godot --path mvp_epsilon
```

(`godot` = `/Applications/Godot.app/Contents/MacOS/Godot`)

## Status — Etappe M2-E5

> Korb + Charakter-Movement + rollenless Stations-System (Spawn 1..4-fähig, 1 Avatar).

Implemented in commit `d56212b`: round basket, central burner obstacle,
CharacterBody3D avatar, rollenless station base, 1..4-capable spawner.

## Next — M2-E7

Drifting cloud layer (Fog-of-War). Sets up the substrate for the M2-E8 telescope
that creates the actual H2-precondition test.
