# H1 Design — Navigations-Fun Validierung

> Detail-Spezifikation für Meilenstein **M1 (Tech-MVP)** — Etappen 0–4 der GDD §6.
> Zweck: Hypothese **H1** aus GDD §1.3 durch einen spielbaren, soloertauglichen Prototyp testbar machen.

## $meta
- **Version:** 0.2.0
- **Status:** Erster Entwurf + Wind-Matrix-Regel (180°) und verbindliche Level-Design-Regeln ergänzt
- **Erstellt:** 2026-04-17
- **Parent-Dokument:** `BALLON_GDD.md` §1.3 (Hypothese H1), §6 Etappen 0–4 (M1 Tech-MVP)
- **Engine:** Godot 4
- **Scope:** Solo spielbarer Prototyp (Coop-Mechaniken sind M2-Territorium)

---

## 1. Zweck und Scope

Dieses Dokument ist die **Implementierungs-taugliche Design-Spezifikation** für den ersten Meilenstein des Prototyps. Es destilliert die Design-Entscheidungen aus dem GDD und der vertiefenden Diskussion in konkrete Parameter, Mechaniken und Referenzen, so dass mit Godot 4 ohne weitere offene Grundsatzfragen begonnen werden kann.

### 1.1 Was dieses Dokument behandelt
- Kern-Navigationsmechanik (Ballon, Wind-Bänder, Brenner, Brennstoff)
- Visuelle Grundlagen (Wind-Viz, Kamera, HUD-Instrumente)
- Win-/Fail-Bedingungen
- Level-Architektur-Prinzipien in Godot 4

### 1.2 Was explizit **nicht** Bestandteil von M1 ist
Diese Elemente sind zwar im GDD vorgesehen, aber für **H1-Test irrelevant** — sie werden bewusst **in M2 oder Post-MVP** entwickelt:

- Multiplayer / Coop-Mechaniken (M2)
- Wolken als Fog-of-War (M2)
- Fernrohr-Station (M2)
- Propeller / Roguelite-Schleife (M2+)
- Seil-Abseilen, Greifarm (Post-MVP)
- Upgrade-Menüs (M2+)
- Gefahren (Berge, Gewitter) außer Bodenkollision (Post-MVP Etappe 12)
- Reparatur / Hüllen-Schaden (Post-MVP)
- Ventil zum aktiven Sinken (siehe §12)
- Ambient-Feedback (Audio/Visual-Lebendigkeit) (siehe §12)

---

## 2. Hypothese H1 und Validierungs-Kriterien

### 2.1 Hypothese H1 (Referenz: GDD §1.3)

> *Ist indirekte Steuerung über Höhenwechsel (Wind pro Höhenband) als Kern-Spielmechanik spaßig und nicht-trivial?*

### 2.2 Positive Validierungs-Signale (H1 bestätigt)

Wir suchen im Playtest nach:

- **Bewusste Höhen-Entscheidungen** — Spieler artikuliert oder demonstriert Strategie (*„Ich muss hoch, um nach Westen zu kommen"*)
- **Zufriedenheits-Moment** bei Zielerreichung — Erfolg fühlt sich *verdient* an, nicht zufällig oder trivial
- **Wiederhol-Wunsch** — nach Erfolg oder Scheitern beginnt Spieler freiwillig einen neuen Run
- **Aktive Nutzung des Wind-Instruments** — Spieler schaut auf die HUD-Anzeige und plant danach
- **Skill-Entwicklung sichtbar** — über 3–5 Runs hinweg verbessert sich das Brenner-Pulsen spürbar, Ankünfte werden präziser
- **Flow-Momente** — Phasen in denen Spieler konzentriert steuert, nicht ablenkend herumschaut

### 2.3 Negative Validierungs-Signale (H1 widerlegt oder fraglich)

Abbruch- bzw. Umdenken-Kriterien:

- **Random-Brenner-Drücken** ohne erkennbares Muster → Mechanik nicht lesbar
- **Frustrations-Abbruch** nach 1–2 Fehlschlägen ohne Wiederversuch
- **Beschreibungen wie „zäh", „langweilig", „nur warten"** in Post-Play-Interviews
- **Ignorieren des Wind-Instruments** → Info kommt nicht an oder ist nicht relevant empfunden
- **Passive Körperhaltung** während längerer Level-Phasen (keine Entscheidungen)
- **Unverständnis nach 2–3 Runs** was man tun sollte → Kern-Mechanik zu opak

### 2.4 Messmethode

- **3–5 Probands** unterschiedlicher Gaming-Erfahrung, einzeln
- **Think-aloud-Protokoll** während des Spielens
- **Strukturiertes Post-Play-Interview** (10 Min), Fokusfragen:
  - Was hast du versucht zu tun?
  - Woher wusstest du, welche Höhe du brauchst?
  - Wann fühlte es sich schwer/leicht an?
  - Würdest du nochmal spielen wollen? Warum/warum nicht?
- **Beobachtungs-Notizen** während Session: Engagement-Niveau, Blickrichtung, Frustrations-Marker
- **Keine Analytics/Metrics** — zu früh, nicht sinnvoll skalierbar

---

## 3. Mentales Modell — das Conveyor-Belt-Prinzip

### 3.1 Die Analogie

Das Kern-Spielgefühl entspricht dem Conveyor-Belt-Mechanismus aus **Chip's Challenge**: Der Spieler bewegt sich nicht aktiv in eine Richtung — er **wählt Transportwege** (Förderbänder), die ihn in bestimmte Richtungen tragen. Die Agentur liegt in der Wahl, nicht in der Lenkung.

Übertragen auf Mostly Hot Air:
- Die Wind-Höhenbänder sind die „Förderbänder"
- Der Brenner ist kein Gaspedal, sondern ein **Spur-Wechsler**
- Horizontal hat der Ballon keine Eigensteuerung — er bewegt sich mit dem Band, auf dem er gerade ist

### 3.2 Was das über das Spiel aussagt

- **Puzzle-Spiel, nicht Reaktions-Spiel.** Erfolg kommt aus Vorausplanung, nicht aus Reflex.
- **Langsame Tempo-DNA.** Entscheidungen haben Konsequenzen, die sich über Sekunden entfalten.
- **Wackelige Oberfläche.** Innerhalb der langsamen Tempo-Basis ist der Ballon kein Uhrwerk — Turbulenzen, Lags und Nachzündungen geben ihm Persönlichkeit.
- **Keine Zeitdruck-Pressure.** Brennstoff ist die einzige Ressource, die ausgeht.

### 3.3 Was das Spiel **nicht** ist — Anti-Pattern

Diese Design-Richtungen sind explizit **ausgeschlossen**, um H1 sauber zu testen:

- ❌ **Flight-Sim-Lenkung** mit direktem Ballon-Thrust in Weltrichtungen
- ❌ **Reflex-/Action-Mechanik** mit schnellen Reaktionen auf plötzliche Ereignisse
- ❌ **Zeit-limitiertes Gameplay** (Countdown, Ticker, Zeit-Fails)
- ❌ **Realistische Ballon-Physik** als Selbstzweck — Spielgefühl steht über Simulationstreue
- ❌ **Grid-basierte Bewegung** (Tiles, Hexes) — Bewegung ist kontinuierlich, auch wenn die mentale Struktur puzzle-artig ist

---

## 4. Spiel-Parameter

Alle Zahlen sind **Startwerte für Playtest**. Tatsächliche Feintuning-Werte ergeben sich erst aus iterativen Runs. Die hier genannten Größenordnungen geben den Rahmen vor.

### 4.1 Höhenbänder

| Parameter | Wert | Anmerkung |
|---|---|---|
| Anzahl Bänder | 3 | Fix in M1 |
| Bandbreite je Band | ~100 m | gleichmäßig verteilt |
| Übergangszone | 10–15 m pro Grenze | Weicher Wind-Vektor-Blend |
| Band-Stärke | Einheitlich | Richtung unterscheidet sich, Geschwindigkeit ist über alle Bänder gleich |
| Band-Grenzen pro Level | **Fix** über alle MVP-Level | kein Level-Varianten-Design in M1 |

**Band-Belegung pro Level-Level (Designer-Ebene):**
Jedes Level bekommt drei Windrichtungen zugewiesen, z.B. Band 1 = Ost, Band 2 = Nordost, Band 3 = Nord. Kombinationen müssen garantieren: **das Ziel ist erreichbar** mit mindestens einer Band-Sequenz.

### 4.2 Level-Dimensionen

| Parameter | Wert | Begründung |
|---|---|---|
| Länge (horizontal) | 1500–3000 m | Puzzle-Dichte, mindestens 3–4 nötige Band-Wechsel |
| Höhe (vertikal) | 300–400 m | 3 Bänder à 100 m + 2 Übergangszonen + Kopf-/Fuß-Puffer |
| Breite (seitlich) | 200–400 m | Out-of-Bounds seitlich |

### 4.3 Drift und Turbulenz

| Parameter | Wert | Wirkung |
|---|---|---|
| Basis-Drift je Band | 7–9 m/s | „Spürbar bewegt, aber planbar" — nicht meditativ-langsam, nicht hektisch |
| Turbulenz-Amplitude | ±15–25 % der Basis-Drift | Drift-Vektor fluktuiert niederfrequent |
| Turbulenz-Frequenz | ~0.3 Hz | Wellenlänge ~3 s — wahrnehmbar, aber nicht zappelig |
| Böen (Richtungsdrehung) | Optional pro Level | Dreht weich über 1–2 s, kündigt sich im Instrument an |

**Wichtig:** Die Lösbarkeit ist garantiert auch mit Turbulenz — Schwankungen sind klein genug, dass die Band-Grundrichtung dominiert.

### 4.4 Wind-Matrix-Regel (verbindlich)

Jedes Level hat drei Wind-Vektoren — einer pro Band — als Level-Daten gespeichert. Diese Vektoren bilden die **Wind-Matrix** des Levels.

**Regel (die 180°-Regel):** Die drei Wind-Vektoren müssen die horizontale Ebene **positiv aufspannen**. Bedingung:
> Die größte Winkellücke zwischen zwei benachbarten Wind-Vektoren (auf dem Kompass) muss **kleiner als 180°** sein.

**Konsequenz:** Jeder Punkt der Karte ist prinzipiell erreichbar (gegeben ausreichend Brennstoff). Ohne diese Regel existiert eine „blinde Stelle" — ein Bereich der Karte, der unabhängig vom Geschick des Spielers nicht erreichbar wäre.

**Validator — läuft beim Level-Laden:**

```gdscript
func validate_wind_matrix(v1: Vector2, v2: Vector2, v3: Vector2) -> bool:
    var angles = [atan2(v1.y, v1.x), atan2(v2.y, v2.x), atan2(v3.y, v3.x)]
    angles.sort()
    var gaps = [
        angles[1] - angles[0],
        angles[2] - angles[1],
        2 * PI - angles[2] + angles[0]   # wrap-around
    ]
    var max_gap: float = gaps.max()
    if max_gap >= PI:
        push_error("Level ungültig: größte Winkellücke %s°" %
            str(rad_to_deg(max_gap)))
        return false
    return true
```

Scheitert der Test → **Level lädt nicht**. Wird als Designer-Fehler behandelt, nicht als Spielsituation.

### 4.5 Level-Design-Regeln (verbindlich)

Diese Regeln **sind einzuhalten** bei jedem handgebauten Level. Verletzung führt zu ungültigen oder unbalancierten Levels. Sie waren ursprünglich als Empfehlungen formuliert — ab MVP-Scope gelten sie als harte Anforderungen.

| # | Regel | Geltungsbereich |
|---|---|---|
| **R1** | **Wind-Matrix besteht den 180°-Test** (§4.4) — keine blinden Stellen auf der Karte | Pflicht ab M1 |
| **R2** | **Ziel ist so platziert, dass mindestens 2–3 Band-Wechsel nötig sind** — das Ziel darf nicht in einem Wind direkt geradeaus liegen, sonst wird Navigation trivial | Pflicht ab M1 |
| **R3** | **Loot/Propeller erfordern 1–2 zusätzliche Band-Wechsel** — lohnender Umweg, nicht zufällig auf dem direkten Pfad | Pflicht ab M2 (Propeller sind M2-Feature) |
| **R4** | **Brennstoff-Vorrat = minimaler Pfad zum Ziel × 1.2–1.5** — Puffer für kleine Fehler und optional Umwege, aber nicht so groß, dass Brennstoff keine Rolle spielt | Pflicht ab M2 (Brennstoff-Tuning-Loop) |
| **R5** | **Landing Zone mindestens 20m Radius** — horizontale Drift während des Abstiegs ist unvermeidbar, Ziel muss großzügig getroffen werden können | Pflicht ab M1 |
| **R6** | **Alle drei Bänder müssen physisch erreichbar sein** — kein Band wird durch Terrain (Berge, Wolkendecken) auf der gesamten Level-Länge blockiert | Pflicht ab M1 |

**Rationale:**
- **R1, R6:** Garantieren die mathematische und physische Lösbarkeit jedes Levels
- **R2:** Sorgt dafür, dass H1 *tatsächlich* die Navigationsmechanik testet — ein Level ohne Band-Wechsel-Zwang testet nichts
- **R3, R4:** Machen die Loot-Routen (M2+) zu echten Trade-off-Entscheidungen statt Selbstläufern
- **R5:** Verhindert Frust durch unmögliches Punkt-Landen trotz korrekter Strategie

**Empfehlung für den Workflow:** Jedes neue Level durchläuft eine **Checkliste** vor Freigabe — R1 durch Validator, R2–R6 durch manuelle Prüfung des Level-Designers.

---

## 5. Ballon-Physik

### 5.1 Brenner

- **Input:** Binary (an/aus) — in M1 keine Modulation der Brenner-Intensität.
- **Lag bei Zündung:** 0.5–1 s bis spürbarer Auftrieb einsetzt.
- **Afterglow bei Loslassen:** Ballon steigt noch 1–2 s weiter, danach setzt passives Sinken ein.
- **Verbrauch:** Linear über Zeit, solange Brenner aktiv (siehe §6).
- **Visuelles Feedback:** Flamme schlägt aus Brenner, leichte Leucht-Färbung der Hüllen-Unterseite, klarer Sound (siehe §13).

### 5.2 Passiver Sink

- **Sink-Rate:** ~0.5 m/s — gemächlich, erlaubt Reaktion
- **Immer aktiv**, solange Brenner aus — **kein Schwebe-Zustand** (siehe §12 für Post-H1-Variante)
- **Aktive Steig-Rate unter Brenner:** ~1.5–2 m/s — merklich stärker als Sink, aber nicht raketenartig

Konsequenz: Höhe halten erfordert regelmäßige Brenner-Pulses. Das ist der **Kern-Skill**, den H1 testet.

### 5.3 Turbulenz-Layer (oberflächliche Chaos-Schicht)

Überlagert auf die Basis-Physik:

- **Drift-Noise:** ±15–25 % Schwankung um Basis-Drift-Wert, niederfrequent (~0.3 Hz)
- **Höhen-Microwobble:** Ballon schwankt leicht vertikal (~±5 cm), auch wenn kein Brenner aktiv, als Lebendigkeits-Indikator

### 5.4 Wackel-Feedback (rein visuell)

- **Korb-Schwingen:** Leichte Pendelbewegung des Korbs bei starker Drift-Änderung oder Brenner-Zündung (~±3°, gedämpft)
- **Hüllen-Atmung:** Die Ballon-Hülle pulsiert minimal, wie weiches Atmen, als Standby-Animation
- **Keine Gameplay-Wirkung** — reines Audio-Visual-Feedback zum Lebendigkeitsgefühl

---

## 6. Brennstoff-System

### 6.1 Vorrat-Modell

- **Ein einzelner Brennstoff-Pool** pro Level, fest zu Level-Start voll
- **Kein Nachfüllen im Flug**
- **Kein Tank-vs-Reserve-Split** (siehe §12, ist Post-MVP-Erweiterung)

### 6.2 Verbrauch

- **Rate:** Annahme 1 Einheit/Sekunde, solange Brenner aktiv (Tuning-Parameter)
- **Verbrauch nur unter Brenner** — passives Sinken kostet nichts
- **Kein Ineffizienz-Strafsystem** in M1 (z.B. Anheiz-Verlust bei vielen Short-Pulses) — wäre Post-MVP

### 6.3 Visualisierung — zweistufig

**Diegetisch (im Korb sichtbar):**
- Brennstoff-Fass oder Gastank mit sichtbarem Füllstand
- Reduziert visuell mit Verbrauch (halb, fast leer, leer)
- Gibt dem Korb Charakter und Leben

**HUD-Instrument (bottom-right, neben Wind-Instrument):**
- Messing-Anzeige im gleichen Stil wie Wind-Kompass
- Präzisere Info (z.B. vertikales Flüssigkeits-Rohr oder Zeiger-Manometer)
- Bei Niedrigstand: leichte farbliche Akzentuierung, kein Flackern

**Audio-Ebene (subtil):**
- Brenner-Sound variiert (Zischen), hilft beim Pulsen ohne hinzuschauen
- Leer-Sound (unterschwelliges Gurgeln) bei niedrigem Stand

### 6.4 Glide-to-Ground bei leerem Tank

Kein abruptes Game-Over bei Brennstoff=0. Stattdessen:
- Brenner zündet nicht mehr
- Ballon sinkt passiv weiter
- Spieler hat immer noch die Möglichkeit, mit Drift ins Ziel zu gleiten
- Erst Bodenkontakt schließt die Runde ab (siehe §7)

Dieser Gleitflug-Moment ist **design-kritisch** — er erzeugt dramatische Endphasen ohne künstlichen Fail-State.

---

## 7. Win- und Fail-Bedingungen

### 7.1 Win-Trigger — Landung in markierter Zone

- **Win-Zone:** Klar markierter Bodenbereich (Plattform, Wimpel, Landungs-Mat)
- **Bedingung:** Ballon berührt Boden innerhalb der Win-Zone
- **Zustand:** Ballon ist „gelandet" — kein weiterer Drift, keine Physik-Animation
- **Win-Feedback:** Landung wird bestätigt (visuell, später mit Audio); Level-Abschluss-Screen

### 7.2 Landung außerhalb der Zone (nicht-finaler Zwischenzustand)

- Ballon berührt Boden außerhalb Win-Zone → **Zustand: „gelandet"**
- **Spieler kann erneut abheben**, solange Brennstoff vorhanden:
  - Brenner zünden → Ballon steigt wieder
  - Sobald Höhe > Boden → normaler Flug-Zustand
- **Diese Retry-Möglichkeit ist zentral** für die „keine Zeitdruck-Pressure"-Philosophie

### 7.3 Fail-Zustände

Ein Run ist **erst dann gescheitert**, wenn:
- **Bodenkontakt außerhalb Win-Zone** UND
- **Brennstoff = 0**, keine Wiederaufstieg-Möglichkeit

Oder:
- **Seitliches Out-of-Bounds** — Ballon driftet aus den Level-Grenzen
- *(Optional in M1, kann auch als respawn behandelt werden — Entscheidung beim Prototyping)*

### 7.4 Nicht-Fail-Bedingungen in M1

Diese Zustände **scheitern den Run nicht**:
- Normale Bodenberührung mit Restbrennstoff
- Lange Spieldauer (kein Zeitlimit)
- Böen / kurzzeitig „falsche" Wind-Situation (Spieler kann warten)

---

## 8. Wind-Visualisierung

### 8.1 Diegetische Ebene (in der Welt)

**Primär — Nebelschleier an Bandgrenzen:**
- Dünne, durchscheinende horizontale Schleier an den zwei Bandgrenzen-Höhen
- Jeder Schleier driftet in die Richtung **seines eigenen** angrenzenden Bandes
- Dient gleichzeitig als **visuelle Markierung der Bandgrenzen**

> **Implementierungshinweis:** In Godot 4 wahrscheinlich als geschichtete `GPUParticles3D` oder einfache flache Mesh-Layer mit animiertem Textur-Offset. Finale Wahl bleibt im Prototyp zu klären — wichtig ist, dass die Lesbarkeit in der 45°-Schräg-Draufsicht funktioniert.

**Sekundär — Ambient-Partikel (pro Band):**
- Band 1 (unten): z.B. Blätter, Vögel nahe Boden
- Band 2 (mitte): z.B. kleine Insektenschwärme, Blütenblätter
- Band 3 (oben): z.B. Federn, Staubpartikel im Licht

**Tertiär — Brenner-Flamme und Rauchfahne:**
- Flamme/Rauch am Korb werden vom aktuellen Band-Wind abgelenkt
- Direktes Feedback „dieser Wind wirkt gerade auf mich"

### 8.2 HUD-Instrument (bottom-right)

- **Drei gestapelte Messing-Kompassringe**, je einer pro Band
- **Geschnitzter Pfeil pro Ring** zeigt Windrichtung
- **Aktueller Band-Zeiger:** Ein kleiner Messing-Pfeil an einer Vertikalschiene neben den Ringen, der mit der Ballonhöhe wandert und den aktiven Ring markiert
- **Böen-Verhalten:** Pfeile drehen sich weich über 1–2 s in die neue Richtung (keine sprunghaften Rotationen)
- **Fixe HUD-Position** unten rechts — camera-unabhängig, immer lesbar

### 8.3 Brennstoff-Instrument (direkt daneben)

Sitzt gleich neben dem Wind-Kompass, gleicher Messing-Stil. Siehe §6.3 Visualisierung.

### 8.4 Stilistische Vorgabe

Die HUD-Instrumente sollen wirken wie **Jules-Verne-Messinstrumente**, nicht wie moderne Videospiel-UI. Sie sind auf dem Bildschirm befestigt, nicht am Korb — aber stilistisch dieselbe Welt.

---

## 9. Kamera-Spezifikation

### 9.1 Grundposition

- **Perspektive:** 45°-Schräg-Draufsicht (gleiche Achse wie Moodboard)
- **Ballon auf Bildschirm:** Bei ~30 % von links (bei östlichem Ziel); zeigt ~70 % Look-ahead in Ziel-Richtung
- **Distanz/Zoom:** Ballon mit spürbarer Präsenz (~1/6 der Bildhöhe), sichtbarer Umgebungs-Radius ~300 m horizontal, ~200 m vertikal

### 9.2 Horizontale Ausrichtung — zielorientiert, nicht driftorientiert

Die Kamera-Orientierung richtet sich nach der **Ziel-Zone**, nicht nach der aktuellen Drift-Richtung:
- Stabil auch bei Rückwärts-Winden (Ziel bleibt im Blick)
- Kein „Schwimmen" der Kamera bei Böen oder Band-Wechsel

### 9.3 Vertikale Dämpfung

Die Kamera folgt Höhenänderungen **mit 1–2 Sekunden Lag**:
- Keine Ruckler bei kurzen Brenner-Pulses
- Band-Wechsel (~20–50 s Dauer) führen zu ruhigem Kamera-Nachziehen
- Ballon darf temporär leicht nach oben oder unten im Bild wandern — kehrt gedämpft zur Zielposition zurück

### 9.4 Visuelle Baseline-Referenz

Als **Kamera-Baseline-Moodboard** dient:

`references/moodboard_06_camera_cruise_golden.png`

Das Bild zeigt Framing, Schräg-Draufsicht-Winkel und Stimmung. Die konkrete Band-Visualisierung ist darin **nicht** dargestellt (Midjourney-Limitierung für stratifizierte Atmosphäre) — die Bänder werden in Godot direkt prototypisch umgesetzt.

Weitere Varianten derselben Kamera, die Stimmungs-Spektrum abbilden: `moodboard_07_camera_cruise_wide.png` bis `moodboard_10_camera_cruise_dawn.png`.

---

## 10. Level-Architektur (Godot 4)

### 10.1 Kein Tile/Grid-System

**Explizit ausgeschlossen** aus M1-Implementierung:
- Hexagonale Tiles
- Grid-basierte Bewegung
- Diskrete Zellen-Logik

Die Bewegung ist **kontinuierlich in 3D**. Die mentale „Conveyor-Belt"-Struktur wird durch Höhen-Zonen realisiert, nicht durch Tiles.

### 10.2 Szenen-Struktur (Vorschlag)

```
Level_01.tscn (Node3D)
├── Terrain.tscn
│   ├── Landschafts-Mesh (Hügel, Dorf, Fluss)
│   └── Landing Zone Marker (Area3D + visuelles Markup)
├── WindBands.tscn (optional, sonst nur in Balloon-Script)
│   ├── Band_Low (Area3D, y: 0–100m)
│   ├── Band_Mid (Area3D, y: 100–200m)
│   └── Band_High (Area3D, y: 200–300m)
├── StartPoint (Marker3D)
├── LevelBounds.tscn (unsichtbare Wände seitlich)
└── Atmosphere.tscn (Nebelschleier, Ambient-Partikel)

Balloon.tscn (separate Szene, instanziiert)
├── BalloonBody (CharacterBody3D)
├── BasketMesh
├── BurnerFlame (GPUParticles3D)
└── FuelTankMesh (Füllstand-Visualisierung)

Camera.tscn
└── Camera3D mit Follow-Script (vertikale Dämpfung + Ziel-Orientierung)

UI.tscn (CanvasLayer)
├── WindInstrument (3 Messing-Kompassringe + Band-Zeiger)
└── FuelInstrument
```

### 10.3 Wind-Band-Logik

Einfachste Implementation: Höhen-Check im Ballon-Script statt Area3D-Enter/Exit-Events.

```gdscript
# Pseudocode-Skizze
func compute_wind_vector(y: float) -> Vector3:
    var band_index = clamp(floor(y / band_height), 0, 2)
    var base_wind = level.band_winds[band_index]
    # Turbulenz addieren
    var noise_offset = turbulence_noise(time)
    # Übergangszone glätten
    if in_transition_zone(y):
        base_wind = lerp(base_wind, next_band_wind, transition_factor(y))
    return base_wind + noise_offset
```

Diese Logik läuft in `_physics_process` des Ballon-Nodes und appliziert den Vektor als Drift.

### 10.4 Level-Grenzen

- **Boden:** `StaticBody3D` mit Kollision — Ballon landet bei Kontakt
- **Seitliche Wände:** unsichtbare `StaticBody3D` als Out-of-Bounds-Stopper
- **Oberer Grenze:** Hart (Kollision) oder weich (Drift zurück nach unten) — Entscheidung beim Prototypen
- **Goal:** `Area3D` innerhalb der Win-Zone-Plattform, Bodenkontakt darin triggert Win

---

## 11. Controls (M1 Solo-Test)

- **Ein einzelner Spieler** bedient den Brenner
- **Eine primäre Aktion:** Brenner zünden (Taste halten oder Button)
- **Empfehlung:** Space (Tastatur) oder A-Button (Gamepad) — intuitiv für „impulsartige Aktion"
- **Kein Charakter-Movement** in M1 — Stationen werden per Taste erreicht, nicht durch Herumlaufen im Korb. Das ist bewusste Vereinfachung; Charakter-Movement im Korb kommt erst in M2 als Koop-Relevanz.

> **Hinweis:** GDD §6 Etappe 1 sieht Korb-Herumlaufen explizit vor. Für den reinen H1-Test ist das überdimensioniert — ein Spieler kann Brenner direkt ohne Raum-Navigation bedienen. Entscheidung ist fließend und während der Etappe-1-Implementierung noch änderbar.

---

## 12. Post-H1-Erweiterungen (bewusst verschoben)

Diese Design-Ideen wurden während der Diskussion aufgebracht, sind **gut und sinnvoll**, aber nicht im H1-Scope. Sie werden hier dokumentiert, damit sie bei Erfolg von H1 als Iterations-Kandidaten für M1-v2 oder M2 bereitliegen.

### 12.1 Band-Effizienz: höhere Bänder günstiger halten
- **Idee:** Brennstoff-Verbrauch pro Sekunde ist in Band 2 geringer als in Band 1, in Band 3 noch geringer.
- **Gameplay-Effekt:** Strategische Investitions-Entscheidung („Aufstieg zahlt sich über Zeit aus").
- **Warum verschoben:** Testet zwei Hypothesen gleichzeitig — macht H1-Signal unsauber. Als **Iteration 2 nach H1-Bestätigung** geplant.
- **Implementierung:** Trivial — Faktor pro Band.

### 12.2 Tank + Reserve-Lager
- **Idee:** Brenner-Tank (klein) muss manuell aus Reserve-Lager (groß) nachgefüllt werden.
- **Gameplay-Effekt:** Neue Station, Coop-relevante Rollenteilung.
- **Warum verschoben:** Wertlos im Solo-Test; gehört in M2 zur Coop-Entfaltung.

### 12.3 Ventil zum aktiven Sinken
- **Idee:** Eigene Station zum schnellen Abstieg (im Gegensatz zu passivem Sinken).
- **Warum verschoben:** Für H1 nicht nötig — passives Sinken deckt den Fall ab. Feature-Creep-Risiko.

### 12.4 Schwebe-Zustand (neutrale Höhe)
- **Idee:** Eine Höhe, in der Ballon weder steigt noch sinkt ohne Brenner.
- **Warum verschoben:** Nimmt den Druck vom Brenner-Pulsen, der der zentrale H1-Skill ist.

### 12.5 Ambient-Feedback-Layer
- **Idee:** Leichtes Schwingen, Hüllen-Atmung, Flackern, Sound-Teppich während M1-Test.
- **Warum verschoben:** Stilistisch gewünscht, aber nicht H1-relevant — fügen wir nach Validierung hinzu.

### 12.6 Turbulenz-Details
- **Offene Sub-Entscheidungen:** Noise-Funktion (Perlin, Sinus-Überlagerung), Frequenz-Spread, Höhen-Turbulenz zusätzlich zu Drift-Turbulenz?
- **Festgehalten in M1:** Drift-Noise ±15–25%, ~0.3 Hz. Alles andere kommt mit Playtest-Feedback.

---

## 13. Offene Punkte für Implementierung

Fragen, die **während des Prototyping** beantwortet werden, nicht vorab:

### 13.1 Konkrete Tuning-Zahlen
- Exakter Brennstoff-Startwert pro Level (Schätzung: 80–120 Einheiten bei 1500m-Level)
- Feinabstimmung Drift-Geschwindigkeit (7, 8 oder 9 m/s?)
- Band-Grenzen in absoluten Metern (fix zu wählen — z.B. 0–100 / 100–200 / 200–300)
- Turbulenz-Stärke feintunen im Playtest

### 13.2 Audio-Design (M1-Minimalset)
- Brenner-Zischen (variabel je nach Puls-Dauer)
- Wind-Atmosphäre je Band (anders klingend pro Höhe?)
- Niedriger-Brennstoff-Gurgeln (subtil)
- Win- / Fail-Sound
- Ambient-Landschafts-Sound (Vögel, ferner Bach, Dorf)
- **Nicht in M1:** Stimme, Musik, spezifische Event-Sounds

### 13.3 Biome-Varianten / Level-Design
- Wie viele Level-Biome für MVP (z.B. Wald, See, Gebirge)?
- Wiederverwendbare Terrain-Assets — Kit-Ansatz in Godot?
- Wie werden 3–5 MVP-Test-Levels konstruiert (handgebaut vs. generiert)?

### 13.4 Input / Controls
- Gamepad-Support oder nur Tastatur für M1?
- Brenner-Input exakt: Taste halten vs. Taste toggeln vs. Taste gedrückt lassen?
- Standard-Empfehlung: **Halten** (intuitiv, zwingt aktive Dosierung)

### 13.5 Nebelschleier-Technik in Godot 4
- `GPUParticles3D`? Mesh-Layer mit animierter Textur? Shader mit UV-Offset?
- Performance-Tradeoffs müssen im Prototyp gemessen werden

### 13.6 Kamera-Feintuning
- Genaue Lag-Werte für vertikale Dämpfung (Playtest-Tuning)
- Field-of-View und Tilt-Winkel exakt (45° ist Ausgangspunkt)

---

## 14. Referenzen

### 14.1 Projektinterne
- `BALLON_GDD.md` §1.3 — MVP-Hypothesen (H1, H2 und die Post-MVP-Hypothesen)
- `BALLON_GDD.md` §2 — Kernmechaniken (Ballon-Physik, Wolken, Fernrohr — letzteres nicht in M1)
- `BALLON_GDD.md` §6 — Entwicklungsetappen 0–4 (M1-Umsetzung)
- `references/moodboard_06_camera_cruise_golden.png` — Kamera-Baseline

### 14.2 Design-Analogien
- **Chip's Challenge (Epyx, 1989)** — Conveyor-Belt-Mechanik als mentales Modell für Band-Navigation
- **Passing By — A Tailwind Journey** — stilistische und emotionale Inspiration; nicht Gameplay-Referenz (Solo, ohne Chaos-Faktor)

### 14.3 Anti-Referenzen (das Gegenteil dessen, was wir wollen)
- **Flappy Bird / Geometry Dash** — Reflex-Spiele mit schnellen Zeitkonstanten
- **Ballon-Simulatoren** — realistische Physik-Treue als Selbstzweck

---

## 15. Änderungshistorie

- **2026-04-17 · v0.2.0** — §4.4 „Wind-Matrix-Regel (verbindlich)" hinzugefügt — 180°-Regel als mathematisch bewiesene Bedingung für Karten-Erreichbarkeit, inklusive Validator-Pseudocode. §4.5 „Level-Design-Regeln (verbindlich)" hinzugefügt — sechs harte Regeln (R1–R6) für handgebaute Level, vormals als Empfehlungen formuliert, jetzt verbindlich. Hintergrund: Diskussion zur Wind-Matrix, blinden Stellen und zum Verhältnis von Überflug-Erreichbarkeit vs. Präzisions-Landung.
- **2026-04-17 · v0.1.0** — Erster Entwurf aus Design-Diskussion 2026-04-17. Destilliert die Entscheidungen zu mentalem Modell (Conveyor-Belt), Wind-Bändern (3, gleich stark, weiche Übergänge, fixe Grenzen), Level-Dimensionen (1500–3000m × 300–400m), Drift (7–9 m/s + Turbulenz), Ballon-Physik (Binary-Brenner, Lag+Afterglow, passives Sinken), Brennstoff (Ein-Pool, Glide-to-Ground), Win/Fail (Landing-Zone mit Retry), Wind-Viz (Hybrid diegetisch + HUD), Kamera (Variante B, zielorientiert, vertikale Dämpfung), Level-Architektur (kontinuierliche 3D-Korridor in Godot 4). Post-H1-Erweiterungen und offene Implementierungspunkte explizit dokumentiert.
