# MVP Ceta — Tile-Laying Navigations-Design

> **Parallele Exploration.** Alternative DNA zum H1-Pfad. Bricht bewusst die Anti-Pattern-Regeln aus `H1_DESIGN.md` §3.3 und §10.1 (Grid/Tiles). Falls sich diese Richtung bestätigt, wird das GDD entsprechend überarbeitet.

## $meta
- **Version:** 0.1.0
- **Status:** Frühe Konzeption — Design-Diskussion offen
- **Erstellt:** 2026-04-19
- **Parent-Dokumente:** `BALLON_GDD.md` (Vision, Kernmechaniken §2), `H1_DESIGN.md` (Ausgangsbasis, Parameter)
- **Prototyp-Ordner:** `mvp_ceta/`
- **Engine:** Godot 4 (Prototyp-Stadium in Three.js/Browser wie mvp_beta)
- **Scope:** Zunächst Solo-Test der neuen Kern-Mechanik; Coop-Aspekte parallel mitgedacht

---

## 1. Warum diese Parallel-Exploration?

**Ausgangs-Frust:** mvp_beta testet das Conveyor-Belt-Modell (Spieler *wählt* zwischen fertigen Wind-Bändern). Erste Selbsttests ergaben: Navigation funktioniert, aber "kein Kick" — zu wenig Agentur, zu wenig Mikro-Entscheidungen pro Sekunde.

**Neue Kern-Hypothese:** Der Kick entsteht, wenn der Spieler die **Wind-Wege selbst legt**, während der Ballon fliegt — wie Schienen in *Unrailed*, wie Landschaftskacheln in *Dorfromantik*.

**Konsequenz:** Das Conveyor-Belt-Mentalmodell wird durch ein **Tile-Laying-Modell** ersetzt. Die Agentur verschiebt sich von *"welche Spur wähle ich?"* zu *"wie baue ich mir die Spur zum Ziel?"* — bei begrenzten Tiles und Brennstoff.

---

## 2. Kern-Idee (Stand Diskussion 2026-04-19)

- **Hex-Kacheln mit fixer Windrichtung** (N, NO, O, SO, S, SW, W, NW — 8 Himmelsrichtungen).
- **Zufallsstapel**: Spieler ziehen Tiles wie bei Dorfromantik; kein Umdrehen/Rotieren erlaubt (würde Funktion ändern, nicht nur Optik).
- **Platzieren im Flug**: Tiles werden vor/um den Ballon ausgelegt, bestimmen den Wind in der jeweiligen Zelle.
- **Ballon-Bewegung bleibt kontinuierlich**, nur das Windfeld ist zellbasiert.
- **Ziel muss erreichbar bleiben** — das ist harte Bedingung, nicht weiche Empfehlung.

---

## 3. Zu klärende Design-Fragen

Diese Fragen stehen offen und werden im Design-Gespräch geklärt:

### 3.1 Tile-Ökonomie
- Wie viele Tiles startet der Spieler mit? Nachschub durch was?
- Kostet Platzieren Brennstoff, oder ist Tile ≠ Brennstoff?
- Dürfen Tiles überschrieben werden?

### 3.2 Räumliche Struktur
- 2D-Karte (Hex-Gitter am Boden, Ballon driftet darüber) oder 3D (Hex-Schichten in verschiedenen Höhen)?
- Was passiert mit dem Höhen-Band-Konzept — ersetzt oder ergänzt?
- Wie groß sind die Hexes (Durchmesser in Metern)?

### 3.3 Platzierungs-Regeln
- Wo darf platziert werden? Überall auf der Karte, oder nur in Sichtweite/Radius um den Ballon?
- Müssen Tiles aneinander angrenzen (Dorfromantik-Regel)?
- Gibt es "leere" Zellen ohne Wind, oder ist default z.B. schwache Basisströmung?

### 3.4 Zufall vs. Kontrolle
- Vollständig zufälliger Stapel, oder Hand mit 3–5 sichtbaren Optionen?
- Mulligan / Nachziehen gegen Kosten?

### 3.5 Belohnungs-Schleifen
- Wodurch fühlt sich eine gute Tile-Platzierung *belohnend* an? (Visual, Audio, Scoring?)
- Gibt es Bonus-Tiles in der Welt, die Umwege wert sind?
- Was ist der Moment, in dem der Spieler stolz auf seine Route ist?

### 3.6 Fail-States & Erreichbarkeit-Garantie
- Wie garantieren wir, dass das Ziel immer erreichbar bleibt (analog §4.4 180°-Regel)?
- Sackgassen-Zustand: was, wenn alle verbleibenden Tiles die falsche Richtung zeigen?
- Graceful fail-over, Retry-Mechanik?

### 3.7 Coop-Implikation (vorausgedacht)
- Pilot (Brenner) vs. Tile-Placer — sind das strukturell zwei Rollen?
- Rutscht damit H2 (Coop-Kommunikations-Druck) in die Kern-Mechanik?
- Oder Solo-spielbar mit Rollenwechsel pro Aktion?

---

## 4. Brainstorm-Ideen (unsortiert, aus bisheriger Diskussion)

1. **Finite Tile-Ökonomie** als zweite Ressource neben Brennstoff — Verschwendung hat Folgen.
2. **Pre-placed Level-Infrastruktur** — Level kommt mit festen Tiles, Spieler füllt Lücken.
3. **Fuel-Cost pro Tile** — Platzieren kostet Brennstoff, verknüpft die zwei Ressourcen.
4. **Bonus-Tiles in der Welt** — Wild-Tiles versteckt, abholen kostet Umweg (Risk/Reward).
5. **Coop-Asymmetrie von Tag 1** — Pilot brennt, zweiter Spieler zieht & legt Tiles.

---

## 5. Bezug zu H1_DESIGN

- **Beibehalten:** Ballon-Physik (§5), Brenner-Lag/Afterglow, passives Sinken, Glide-to-Ground (§6.4), Kamera-Baseline (§9), Landing-Zone-Prinzip (§7), HUD-Stil Jules Verne (§8.4).
- **Ersetzt:** §3 Conveyor-Belt-Modell, §4 Wind-Matrix & 180°-Regel (wird durch neue Erreichbarkeits-Garantie ersetzt), §10.1 "kein Grid".
- **Offen:** Höhenband-Konzept — entfällt, bleibt als zweite Dimension, oder wird zu Schichten im Hex-Grid?

---

## 6. Änderungshistorie

- **2026-04-19 · v0.1.0** — Dokument erstellt als Scaffold für parallele Design-Exploration. Kern-Idee (Hex-Tiles mit fixen Windrichtungen, Zufallsstapel, Platzieren im Flug) notiert. Offene Fragen strukturiert für gemeinsame Diskussion. Bezug zu H1_DESIGN abgegrenzt.
