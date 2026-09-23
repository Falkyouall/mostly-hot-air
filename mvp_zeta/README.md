# MVP Zeta — „Wolkenpost"

Godot-4-Prototyp, rückwärts aus einem einzigen Bild entwickelt:
[`references/moodboard_04_3d_cloudlayered.png`](../references/moodboard_04_3d_cloudlayered.png).
Frage des Experiments: *Wenn das Spiel so aussieht — was spielt man da, und macht es allein Spaß?*

Single-Player. Engine: Godot 4.5 (Forward+). Keine Assets — Meshes, Shader und Sounds entstehen im Code.

```bash
godot --path mvp_zeta            # spielen
godot --path mvp_zeta --editor   # im Editor öffnen
```

## Was im Bild steckt → was daraus wurde

| Im Screenshot | Im Spiel |
|---|---|
| Steile Schräg-Draufsicht, Hülle ragt oben ins Bild | Feste Kamera am Ballon, Weitwinkel, Hülle + Tragring oben, Boden direkt unter dem Korb bleibt sichtbar |
| Runder Korb, Ofen in der Mitte | **Brenner** — `E` halten = Hitze = Steigen, kostet Tank |
| Fässer | **Brennstoff-Lager** — Kanister zum Brenner tragen = Tank +70 |
| Sandsäcke | **Ballast** — über Bord = dauerhaft mehr Auftrieb (spart Sprit, macht Sinken zäh) |
| Fernrohr an der Reling | **Fernrohr** (GDD §2.3) — halten reißt ein Loch in die Wolken, Sichtfenster per Stick verschiebbar, schließt beim Loslassen. Zeigt, **was ein Dorf bestellt hat**, lange bevor man es sieht |
| Kisten, Säcke, Werkbank, kleine Crew mit weißen Mützen | **Werkstatt:** Warenstapel, Packtisch, Fallschirm-Haken, Ablage — und eine Spielfigur, die alles allein machen muss |
| Seile zur Hülle | **Ventil-Leine** (rot, Nordseite) — halten = schnell sinken |
| Wolkendecke *unter* dem Korb, Dörfer/Fluss weit unten | Wolkenschicht auf 110–145 m; darüber schnell, aber blind. Dörfer sind die Ziele, Wasser frisst Pakete |
| Fels unten rechts | Berge ragen durch die Wolken — Felswand kostet Hülle |

## Spielziel

Fünf Dörfer entlang der Strecke beliefern, dann im **Hafen Luftikus** landen.

- Lenken geht nicht. **Höhe ist das Steuer** (GDD §2.1): unteres und mittleres Windband drücken in
  entgegengesetzte Richtungen, die Bandgrenze ist neutral, darüber geht es schnell geradeaus.
  Zweimal pro Strecke tauschen die Bänder die Seite — der Höhenmesser links zeigt den Wind *hier*.
- **Dorf verpasst?** Es bleibt offen. Ganz oben (über 185 m, über allen Gipfeln und weit über den
  Wolken) weht die **Rückströmung** nach Westen. Hoch, blind zurücktreiben, mit dem Fernrohr den
  Moment zum Abtauchen suchen — und großzügig überschießen, denn der Abstieg führt durch das schnelle
  Ostband. Laut Bot kostet eine Umkehr rund 2 Minuten und gut 1½ Kanister: genau **eine** pro Fahrt
  ist im Spritbudget drin. Auch am Hafen vorbeigetrieben? Gleicher Weg zurück.
- **Der Wind ist der Zug, das fertige Paket ist das Gleis** (Unrailed-Prinzip). Jedes Dorf bestellt
  Medizin (rot), Briefe (blau) oder Saatgut (gelb) — ablesbar an Flagge und Zielpunkt im Dorf, durch
  Wolken oder auf Distanz nur per Fernrohr; einmal gesehen, merkt sich das HUD den Wunsch.
  Eine Lieferung muss **hergestellt** werden:
  **Ware** nehmen → **Packtisch** (`E` 2,5 s halten) → **Fallschirm** → **Reling**, `E`.
  Der Schirm geht in beide Richtungen dran: Paket zum Haken tragen, oder einen Fallschirm vom Haken
  nehmen und an ein Paket auf Packtisch/Ablage knoten.
  Falsche Farbe = abgelehnt, Paket weg. Vorrat: 3 je Ware, 6 Fallschirme.
- **Ablage** (2 Plätze): ruhige Strecken nutzen, um vorzupacken.
- **Ohne Fallschirm** fällt ein Paket senkrecht und schnell — überlebt das aber nur aus unter 30 m.
  Tiefflug spart also einen Schirm (und ist die Rettung, wenn sie ausgehen).
- **Abwurf:** Ein Ring am Boden zeigt den Landepunkt (Fallschirm driftet mit dem Wind). Grün = trifft,
  grau = ohne Schirm zu hoch.
- **Der Konflikt:** Wer packt, brennt nicht. Der Ballon kühlt ab, während man am Packtisch steht oder
  an der Reling auf den grünen Ring wartet — und das Dorf kommt trotzdem näher.
- **Tank** ist die Uhr: langsame Bänder kosten mehr Sprit pro Strecke. 1 Tank + 4 Kanister.
- **Hülle** (3): Felswand oder Aufsetzen außerhalb des Hafens kostet je 1. Bei 0: Absturz.

Wertung: ★ 3 Zustellungen · ★★ 4 + Hafenlandung · ★★★ alle 5 + Hafenlandung.
Jede Fahrt würfelt Karte, Dorf-Lage, Berge und Windseite neu (`R`).

## Steuerung

| Eingabe | Aktion |
|---|---|
| `WASD` / Pfeile / linker Stick | laufen (im Fernrohr: Sichtfenster bewegen) |
| `E` / Leertaste / Pad `A` | benutzen: nehmen, abwerfen, zurücklegen, tanken — **halten** für Brenner, Ventil, Fernrohr |
| `R` / Pad `Start` | neue Fahrt |

## Aufbau

Alles unter `scripts/` wird von `game.gd` im Code zusammengesetzt (`scenes/main.tscn` ist nur der Einstieg).

| Datei | Rolle |
|---|---|
| `game.gd` | Lauf-Zustand, Wertung, Kamera (normal ↔ Fernrohr), Abwurf-Marker, Debug-Flags |
| `world.gd` | Landschaft + alle Fragen an sie: `wind_at`, `land_height`, `mountain_height`, Dörfer, Wolken |
| `balloon.gd` | Fahrzeug: Hitze → Auftrieb, Wind → Drift, Felskollision, Tank, Hülle; Hülle/Korb/Flamme als Mesh |
| `basket.gd` | Werkstatt + Hebel-Stationen, Items, Ein-Knopf-Interaktionsregeln (Angebot mit höchster Priorität in Reichweite gewinnt) |
| `wares.gd` | Die drei Waren: Name + Farbe, geteilt von Welt, Korb und HUD |
| `player.gd` | Spielfigur (Bewegung, Animation) |
| `parcel.gd` | fallende Dinge + `predict_landing` (gleiche Integration wie der echte Fall) |
| `hud.gd` | Höhenmesser mit Windpfeilen, Tank/Hitze/Hülle, Streckenleiste, Zielpfeil, Intro/Ergebnis |
| `sfx.gd` | Autoload, synthetisiert alle Sounds beim Start |
| `shaders/` | Boden (Küste, Felder), Wolken (Dither-Tunnel + Fernrohr-Loch), Hülle, Planken |

## Tests

```bash
# Skriptete Spielfigur läuft echte Input-Actions durch alle Stationen (Exit-Code ≠ 0 bei Fehler)
godot --headless --path mvp_zeta -- --playtest --seed=3

# Balance-Sonde: Bot fliegt eine ganze Fahrt auf Ballon-Ebene, gibt Ergebnis + Spritverbrauch aus
godot --headless --path mvp_zeta -- --bot --seed=3        # --trace für Verlauf

# Dasselbe, aber der Bot fährt absichtlich am ersten Dorf vorbei und holt es per Rückströmung nach
godot --headless --path mvp_zeta -- --bot --bot-return --seed=3
```

Weitere Debug-Flags (nach `--`): `--seed=N --autostart --x=N --z=N --alt=N --village=I --carry=rot|blau|gelb --scope
--shot=/abs/pfad.png --shot-at=SEK`.

## Bekannte Lücken

- Spielgefühl ist nur per Bot/Skript und Screenshots geprüft, noch nicht von Hand gespielt — Tuning-Werte
  (`balloon.gd` Konstanten, Windstärken in `world.gd`) sind erste Schätzungen.
- Die Werkstatt-Kette ist der Versuch, aus dem „Schaltpult" einen Arbeitsplatz zu machen (Befund: vorher
  trug fast nur die Windband-Mechanik). Ob Kettenlänge und Packzeit solo tragen, muss Handspiel zeigen.
- Keine Balance/Schräglage (GDD §2.1), kein Anker, kein Seil, keine Propeller-Ökonomie — bewusst weggelassen.
- Boden-Textur wird mit 6 m/Pixel gebacken und wirkt im Tiefflug weich.
