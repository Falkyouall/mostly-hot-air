# MVP Epsilon — M2 Prototype

Godot 4 prototype for **Milestone M2** of *Mostly Hot Air*. Design spec: [`../H2_DESIGN.md`](../H2_DESIGN.md).

Goal of M2: a juicy, 1→4-player-scalable vertical slice of the *Tense Shared-Vehicle
Coordination Journey* — built and tested solo (one avatar does every task).

## Status — Etappe M2-E5

> Korb + Charakter-Movement + rollenless Stations-System (Spawn 1..4-fähig, 1 Avatar).

Implemented:
- Round basket with a central burner obstacle that forces pathing around the centre.
- Player avatar (`CharacterBody3D`) — walk with WASD / arrows / left stick.
- Rollenless station system — hold **Space / E / gamepad A** near a station to occupy it;
  release or walk away to free it. Occupied stations light up.
- `PlayerSpawner` — spawns 1–4 players from one code path; M2-E5 spawns 1.
- Three rim stations (Fernrohr, Stoss-Ruder, Ballast) — visual/occupancy only;
  functional behaviour arrives in M2-E6+.

**Testable:** the avatar walks in the basket and occupies/leaves stations
(occupy/release is logged to the console).

## Run

```sh
# editor
godot --path mvp_epsilon -e

# play directly
godot --path mvp_epsilon
```

(`godot` = `/Applications/Godot.app/Contents/MacOS/Godot`)

## Next — M2-E6

Stream-field navigation ported from `mvp_delta`, Stoss-Ruder + mountains.
