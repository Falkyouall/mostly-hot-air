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
| Runder Korb, Ofen in der Mitte | **Pilotenstand** — die Säule in der Mitte trägt Brenner, Ventil-Leine, Pinne und Gashebel. Nur wer hier steht, steuert |
| Fässer | **Brennstoff-Lager** — Kanister zum Pilotenstand tragen = Tank +70 |
| Sandsäcke | **Ballast** — über Bord = dauerhaft mehr Auftrieb (spart Sprit, macht Sinken zäh) |
| Fernrohr an der Reling | **Fernrohr** (GDD §2.3) — halten reißt ein Loch in die Wolken, Sichtfenster per Stick verschiebbar, schließt beim Loslassen. Zeigt, **was ein Dorf bestellt hat**, lange bevor man es sieht |
| Kisten, Säcke, Werkbank, kleine Crew mit weißen Mützen | **Werkstatt:** Warenstapel, Packtisch, Fallschirm-Haken, Ablage — und eine Spielfigur, die alles allein machen muss |
| Seile zur Hülle | **Ventil-Leine** (rot, neben der Säule) — halten = schnell sinken |
| *(nicht im Bild)* | **Außenbordmotor** auf einer Messingschiene um den Korb — sitzt immer auf der Seite, von der er schiebt. Siehe „Steuern" |
| Wolkendecke *unter* dem Korb, Dörfer/Fluss weit unten | Wolkenschicht auf 110–145 m; darüber schnell, aber blind. Dörfer sind die Ziele, Wasser frisst Pakete |
| Fels unten rechts | Berge ragen durch die Wolken — Felswand kostet Hülle |

## Spielziel

Fünf Dörfer entlang der Strecke beliefern, dann im **Hafen Luftikus** landen.

- **Der Motor ist das Lenkrad, die Höhe ist die Spurwahl.** Der Außenbordmotor schiebt in
  Pinnenrichtung — Vollgas 26 m/s, Halbgas 11 m/s — und dazu kommt der Wind des Bandes, in dem man
  gerade fliegt. Unten sind das gut 6 m/s (Motor : Wind ≈ 80 : 20), im mittleren Band 9 m/s, ganz oben
  17 m/s (≈ 60 : 40). Unteres und mittleres Band drücken in entgegengesetzte Richtungen, zweimal pro
  Strecke tauschen sie die Seite — der Höhenmesser links zeigt den Wind *hier*, der helle Punkt am
  Boden zeigt, wo Motor und Wind zusammen in 10 s hinführen.
- **Der Wind zappelt.** Unteres Band: Böen, Wirbel im Lee jedes Massivs und Thermik über den Dörfern.
  Mittleres Band: halb so böig. Oberes Band: schnell und ruhig, aber blind über den Wolken. Das ist
  grob das, was die Grenzschicht der echten Atmosphäre auch macht — unten Reibung und Thermik,
  oben glatter, schneller Wind.
- **Die Pinne bleibt stehen.** Wer zum Packtisch geht, lässt den Motor in die alte Richtung schieben,
  und der Wind trägt den Ballon derweil vom Kurs. Wer packt, korrigiert nicht.
- **Sprit ist das Steuer hinter dem Steuer.** Motor und Brenner ziehen aus einem Tank. Halbgas kostet
  fast nichts (0,3/s), Vollgas frisst (1,5/s), der Brenner 3/s. Mit dem Wind fahren ist billig, gegen ihn
  teuer; ein Massiv umfahren ist billiger als drüberklettern.
- **Dorf verpasst?** Es bleibt offen. Mit Vollgas nach Westen geht es zurück, auch gegen das Band —
  oder ganz oben (über 185 m) mit der **Rückströmung** gratis, aber blind. Auch am Hafen vorbei? Gleicher Weg zurück.
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
- **Der Konflikt:** Wer packt, steuert nicht. Der Ballon kühlt ab und driftet, während man am Packtisch
  steht oder an der Reling auf den grünen Ring wartet — und das Dorf kommt trotzdem näher.
- **Tank** ist die Uhr. 1 Tank + 4 Kanister.
- **Hülle** (3): Felswand oder Aufsetzen außerhalb des Hafens kostet je 1. Bei 0: Absturz.

Wertung: ★ 3 Zustellungen · ★★ 4 + Hafenlandung · ★★★ alle 5 + Hafenlandung.
Jede Fahrt würfelt Karte, Dorf-Lage, Berge und Windseite neu (`R`).

## Steuerung

| Eingabe | Aktion |
|---|---|
| `WASD` / linker Stick | laufen (im Fernrohr: Sichtfenster bewegen) |
| `E` / Pad `A` | benutzen: nehmen, abwerfen, zurücklegen, tanken — **halten** für Packtisch und Fernrohr |
| `R` / Pad `Start` | neue Fahrt |

**Am Pilotenstand** (in Reichweite der Säule), Twin-Stick, ohne Modus und ohne Griff-Taste:

| Eingabe | Aktion |
|---|---|
| Pfeiltasten / rechter Stick | **Pinne** — halten dreht den Motor mit 90°/s auf die gedrückte Richtung zu; loslassen lässt ihn genau dort stehen, auch beim Weggehen. So ist jeder Kurs über 360° einstellbar |
| `E` / Pad `A` | **Gashebel** — Aus → Halbgas → Vollgas → Aus |
| Leertaste / `RT` | **Brenner** halten = steigen |
| Umschalt / `LT` | **Ventil** halten = sinken |

## Aufbau

Alles unter `scripts/` wird von `game.gd` im Code zusammengesetzt (`scenes/main.tscn` ist nur der Einstieg).

| Datei | Rolle |
|---|---|
| `game.gd` | Lauf-Zustand, Wertung, Kamera (normal ↔ Fernrohr), Abwurf-Marker, Debug-Flags |
| `world.gd` | Landschaft + alle Fragen an sie: `wind_at` (Bänder + Böen, Wirbel, Thermik; `steady` für Instrumente), `land_height`, `mountain_height`, Dörfer, Wolken |
| `balloon.gd` | Fahrzeug: Hitze → Auftrieb, Motor + Wind → Drift, Felskollision, Tank, Hülle; Hülle/Korb/Flamme/Motorschiene als Mesh |
| `basket.gd` | Werkstatt + Pilotenstand, Items, Ein-Knopf-Interaktionsregeln (Angebot mit höchster Priorität in Reichweite gewinnt) |
| `wares.gd` | Die drei Waren: Name + Farbe, geteilt von Welt, Korb und HUD |
| `player.gd` | Spielfigur (Bewegung, Animation) |
| `parcel.gd` | fallende Dinge + `predict_landing` (gleiche Integration wie der echte Fall) |
| `hud.gd` | Höhenmesser mit Windpfeilen, Tank/Hitze/Motor/Hülle, Vorhalt-Label, Streckenleiste, Zielpfeil, Intro/Ergebnis |
| `sfx.gd` | Autoload, synthetisiert alle Sounds beim Start |
| `shaders/` | Boden (Küste, Felder), Wolken (Dither-Tunnel + Fernrohr-Loch), Hülle, Planken |

## Tests

```bash
# Skriptete Spielfigur läuft echte Input-Actions durch alle Stationen (Exit-Code ≠ 0 bei Fehler)
godot --headless --path mvp_zeta -- --playtest --seed=3

# Balance-Sonde: Bot fliegt eine ganze Fahrt auf Ballon-Ebene (Pinne, Gas, Brenner), gibt Ergebnis +
# Spritverbrauch aus; Berge umfährt er, statt drüberzuklettern
godot --headless --path mvp_zeta -- --bot --seed=3        # --trace für Verlauf

# Dasselbe, aber der Bot fährt absichtlich am ersten Dorf vorbei und motort zurück
godot --headless --path mvp_zeta -- --bot --bot-return --seed=3
```

Weitere Debug-Flags (nach `--`): `--seed=N --autostart --x=N --z=N --alt=N --village=I --carry=rot|blau|gelb --scope
--shot=/abs/pfad.png --shot-at=SEK`.

## Bekannte Lücken

- Spielgefühl ist nur per Bot/Skript und Screenshots geprüft, noch nicht von Hand gespielt — Tuning-Werte
  (`balloon.gd` Konstanten inkl. `MOTOR_SPEED`/`MOTOR_FUEL`, Windstärken und Böen in `world.gd`) sind erste Schätzungen.
- Mit dem Motor lohnt sich ein Bandwechsel selten: Der Bot bleibt unten und umfährt Berge. Ob die oberen
  Bänder (schnell, ruhig, blind) im Handspiel jemals attraktiv sind, ist die offene Frage dieses Umbaus —
  Stellschrauben sind Spritpreise und Böenstärke, nicht die Motorstärke.
- Die Werkstatt-Kette ist der Versuch, aus dem „Schaltpult" einen Arbeitsplatz zu machen (Befund: vorher
  trug fast nur die Windband-Mechanik). Ob Kettenlänge und Packzeit solo tragen, muss Handspiel zeigen.
- Keine Balance/Schräglage (GDD §2.1), kein Anker, kein Seil, keine Propeller-Ökonomie — bewusst weggelassen.
- Boden-Textur wird mit 6 m/Pixel gebacken und wirkt im Tiefflug weich.
