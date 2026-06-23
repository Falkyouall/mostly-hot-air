# H2 Design — Tense Shared-Vehicle Coordination Journey

> Detail-Spezifikation für Meilenstein **M2 (Produkt-MVP / Vertical Slice)** — GDD §6 Etappen 5–8.
> Zweck: Hypothese **H2** aus GDD §1.3 vorbereiten und ihre Vorbedingung — die *Kontention der Aufgaben* — durch einen **solo spielbaren, von 1 auf 4 Spieler skalierbaren** Prototyp testbar machen.

## $meta
- **Version:** 0.1.0
- **Status:** Erster Entwurf — Zielästhetik festgelegt, Navigationsbasis (mvp_delta) übernommen, Solo-Skalierungs-Konzept formuliert
- **Erstellt:** 2026-05-20
- **Parent-Dokumente:** `BALLON_GDD.md` §1.3 (Hypothese H2), §2 (Kernmechaniken), §6 Etappen 5–8 (M2)
- **Geschwister-Dokument:** `H1_DESIGN.md` (M1 — Navigations-Fun, abgeschlossene Spezifikation)
- **Verworfene Parallel-Exploration:** `MVP_CETA_DESIGN.md` (Tile-Laying — siehe §1.2)
- **Engine:** Godot 4 — der M2-Prototyp wird direkt in Godot gebaut (Entscheidung 2026-05-20). Die Navigationslogik aus `mvp_delta` (Three.js) wird in GDScript reimplementiert, nicht portiert.
- **Prototyp-Ordner:** `mvp_epsilon/` (Godot-4-Projekt)
- **Scope:** Ein-Spieler-Prototyp, der **alle Aufgaben auf einem Avatar bündelt** — Architektur jedoch von Tag 1 auf 1–4 Spieler ausgelegt.

---

## 1. Zweck und Scope

### 1.1 Was dieses Dokument behandelt

H2_DESIGN ist die implementierungstaugliche Spezifikation für den **zweiten Meilenstein**. Es destilliert die Designentscheidungen aus dem GDD, aus `H1_DESIGN.md` und aus der MDA-Analyse der drei Navigations-Prototypen (`mvp_beta`, `mvp_ceta`, `mvp_delta`) in ein konkretes Konzept für einen **„juicy"** Vertical-Slice-Prototyp.

Behandelt:
- Die festgelegte Zielästhetik **„Tense Shared-Vehicle Coordination Journey"** (§3)
- Das Skalierungs-Prinzip 1→4 Spieler und der Solo-Testfall (§4)
- Navigationsbasis aus `mvp_delta` (§5)
- Den H2-Kern: Wolken als Fog-of-War + Fernrohr (§6)
- Stations-Katalog, Korb-Raum, Spielerbewegung (§7–8)
- Soft-Pressure ohne Timer (§9) und den verbindlichen Juice-/Feedback-Layer (§10)
- Win/Fail, Solo-Steuerung, Validierungs-Kriterien, Level-Architektur (§11–14)

### 1.2 Verhältnis zu H1_DESIGN und den drei Navigations-Prototypen

M1 hat drei Navigationskerne erzeugt. Die MDA-Bewertung ergab:

| Prototyp | Modell | Befund |
|---|---|---|
| `mvp_beta` | Conveyor-Belt / Wind-Matrix (H1_DESIGN) | Entscheidungsdichte zu niedrig — *„kein Kick"*, passive Körperhaltung |
| `mvp_ceta` | Tile-Laying (MVP_CETA_DESIGN) | Engagiert, aber kognitiv gierig; Zufallsstapel = *„unfaire"* Sackgassen; in Coop ein Einzel-Locus → H2-Degeneration |
| `mvp_delta` | Stream-Navigation (kontinuierliches Strömungsfeld + Stoß + Berge) | **Beste Entscheidungsdichte bei niedrigster kognitiver Last** |

**Entscheidung:** `mvp_delta` ist die Navigationsbasis für M2. `mvp_ceta` wird stillgelegt — `MVP_CETA_DESIGN.md` bleibt als dokumentierte Sackgasse erhalten.

Begründung über reines Spielgefühl hinaus: Tile-Laying frisst genau das kognitive Budget, das **Coop-Kommunikation** braucht. Ein Spieler, der in Routenoptimierung versunken ist, ruft niemandem *„da rechts unten!"* zu. Die Navigation muss **lesbar und gut genug** sein — sie ist das *Substrat*, nicht die Hauptattraktion.

### 1.3 Was explizit **nicht** M2 ist

Aus dem GDD vorgesehen, aber bewusst auf Post-MVP verschoben — sie würden das H2-Signal verunreinigen oder den Scope sprengen:

- Online-Multiplayer
- Propeller-Roguelite-Schleife, Upgrade-Menüs (Post-MVP — der Slice endet nach **einem** Level)
- Seil-Abseilen, Greifarm (Post-MVP)
- Konvoi-Modus, Kampagne/Story
- Voller Gefahren-Katalog (Gewitter, Vögel, Funken) — M2 nutzt **nur Berge** als Gefahr
- Reparatur-Werkbank / detailliertes Hüllen-Schadensmodell (siehe §16 — als Stretch dokumentiert)
- Brennstoff-Tank-vs-Reserve-Split

---

## 2. Hypothese H2 — Reframing

### 2.1 H2 wie im GDD

> *Erzeugen Wolken als Fog-of-War + Fernrohr als geteiltes Sichtwerkzeug echten verbalen Austausch und gegenseitige Abhängigkeit — statt zu einer Einzelansage oder Solo-Operation zu degenerieren?*
>
> Risiko: **Hoch.** Das ist die eigentliche Produkt-Wette.

### 2.2 Das Solo-Test-Paradox und seine Auflösung

H2 spricht von **verbalem Austausch** — der setzt ≥ 2 Spieler voraus. Ein Solo-Prototyp kann H2 also **nicht direkt** validieren.

Was er **kann**: die *Vorbedingung* von H2 testen. Coop-Kommunikation entsteht nur, wenn die Aufgaben sich **echt um Aufmerksamkeit, Hände und Position streiten**. Wenn ein einzelner Spieler mühelos alles allein schafft, gibt es bei vier Spielern nichts zu verhandeln — H2 wäre schon vor dem ersten Coop-Test tot.

**Der Solo-Test stellt genau diese eine Frage:** *Erzeugt das Aufgaben-Set für eine einzelne Person spürbare, produktive Überforderung — den Wunsch nach einem zweiten Paar Hände?*

Dieser Wunsch **ist** der Coop-Hook. Ein Solo-Spieler, der hörbar oder sichtbar *„ich müsste jetzt an zwei Stellen gleichzeitig sein"* signalisiert, beweist, dass die Stationen-Kontention trägt. Das validiert die Vorbedingung von H2 — und nebenbei H3 (Stations-Enge, GDD §1.3).

### 2.3 Was der Solo-Prototyp validiert — und was nicht

**Validiert:**
- Die Aufgaben streiten sich echt (ein Körper, mehrere Stationen → erzwungene Triage)
- Der Kern-Loop aus Navigation + Fog-of-War + Stationen ist kohärent und „juicy"
- Das Zielgefühl **Tension ohne Timer** trägt (§9)
- Die Architektur skaliert sauber von 1 auf 4 Spieler (§4)

**Validiert NICHT — bleibt dem späteren Multiplayer-Build vorbehalten:**
- Ob der Austausch *verbal* und *aushandelnd* wird (echtes H2)
- Ob das Fernrohr-Loch geteilte Aufmerksamkeit erzeugt statt Einzelansage
- Gewichtsverteilung / Schräglage durch mehrere Spielerpositionen (GDD §2.1)

Das ist ein bewusstes, ehrliches Gate: **Solo grün → Multiplayer-Build → echter H2-Test.**

---

## 3. Designvision — Tense Shared-Vehicle Coordination Journey

### 3.1 Das Zielgefühl

M2 verfolgt **eine** klar gewählte Ästhetik. Aus der MDA-Analyse: der ehrliche Kern dieses Spiels ist die **angespannte Koordinationsreise in einem geteilten Fahrzeug** — näher an *Lovers in a Dangerous Spacetime* und *We Were Here* als an Overcooked.

> **Zielgefühl:** Eine warme, weite Reise, die ständig leicht **mehr verlangt, als bequem zu leisten ist**. Spannung kommt nicht aus Hektik, sondern daraus, dass die Welt nicht wartet und man immer ein wenig zu wenig weiß.

Drei Säulen (in MDA-Aesthetics-Begriffen):
- **Sensation & Discovery** — das Aufreißen der Wolkendecke, der Moment *„da unten ist es!"*
- **Challenge** — Triage: welche Station verdient meine nächsten zehn Sekunden?
- **Fellowship** (latent im Solo, manifest ab 2 Spielern) — die Aufgaben sind so verteilt, dass Teilen sich *natürlich* anfühlt.

### 3.2 Mentales Modell — „Ein Cockpit, zu wenig Hände"

H1 hatte das Conveyor-Belt-Modell. M2 ersetzt es **nicht**, sondern legt eine Schicht darüber:

> Der Korb ist ein Cockpit mit mehreren Instrumenten, die **alle gleichzeitig Aufmerksamkeit wollen**. Die Reise selbst ist ruhig; die Spannung entsteht aus der Lücke zwischen *„was die Stationen verlangen"* und *„wie viele Hände im Korb stehen"*.

Solo ist diese Lücke maximal — eine Person, alle Instrumente. Mit jedem zusätzlichen Spieler schrumpft die Lücke; sie verschwindet nie ganz (Level-Design hält sie offen, GDD §3).

### 3.3 Anti-Pattern — was M2 **nicht** ist

- ❌ **Overcooked-Hektik mit Zeitdruck** — kein Countdown, kein Ticker (übernimmt H1_DESIGN §3.3)
- ❌ **Reflex-Action** — Konsequenzen entfalten sich über Sekunden, nicht Frames
- ❌ **Fester-Rollen-Coop** — kein „du bist der Pilot, du der Späher" (siehe §4.1)
- ❌ **Strafende „unfaire" Fehlschläge** — Gefahren sind durch Scouting *vermeidbar*; Tod muss sich verdient anfühlen
- ❌ **Reine Stat-Überforderung** — Spannung kommt aus *unvollständiger Information*, nicht aus zu vielen Zahlen

---

## 4. Skalierungs-Prinzip 1–4 Spieler

### 4.1 Jede Station ist rollenlos

GDD-Säule §1.2: *„keine festen Rollen — Spezialisierung entsteht durch räumliche Knappheit."*

Konsequenz für die Architektur: **Jede Station ist ein Welt-Objekt, das jeder Spieler-Avatar benutzen kann**, indem er hinläuft und eine Taste hält. Es gibt keinen Code-Pfad, der eine Station an eine Spieler-ID oder „Rolle" bindet.

Spezialisierung entsteht **emergent**: weil der Korb eng ist und ein Avatar nur an einer Station gleichzeitig stehen kann, *einigt* sich eine Gruppe darauf, wer wo bleibt — sie wird nicht zugewiesen.

### 4.2 Kontention statt Chaos

Aus der MDA-Analyse: Kontention entsteht nur, wenn **gleichzeitig fordernde Aufgaben ≈ Spielerzahl**. Der Stations-Katalog (§7) ist deshalb so gebaut, dass er **zwei dauerhaft fordernde** Aufgaben (Brenner, Fernrohr) plus **zwei stoßweise** Aufgaben (Stoß-Ruder, Ballast) enthält. Bei 4 Spielern überlappen die Stoß-Spitzen mit den Dauerlasten — das erzeugt das Koordinationsgefühl, ohne dass jemand leerläuft.

Skalierungs-Hebel für späteres Level-Design (nicht M2-Prototyp): Wolkendichte, Bergdichte, Strömungs-Volatilität (§9.1). Mehr Spieler → dichteres Level, damit die Lücke aus §3.2 offen bleibt.

### 4.3 Der Solo-Fall

Im M2-Prototyp wird **genau ein** Avatar gespawnt. Derselbe Code, der bei 4 Spielern 4 Avatare erzeugt, erzeugt hier 1. Der Solo-Spieler:
- läuft physisch zwischen den Stationen
- kann **immer nur an einer Station** stehen → erzwungene Triage
- erlebt die Lücke aus §3.2 in Maximalform

Das ist kein „reduzierter" Modus — es ist der **schärfste Stresstest** des Stations-Designs. Übersteht das Aufgaben-Set den Solo-Test, ist es für Coop nur noch leichter.

---

## 5. Navigationsbasis — übernommen aus `mvp_delta`

### 5.1 Strömungsfeld (statt Höhenbänder)

- **Wind ist ein kontinuierliches 2D-Vektorfeld** über der Karte (`wind = f(x, z)`), erzeugt aus überlagerten Sinuswellen → wellenförmige, sich kreuzende „Ströme".
- **Höhe beeinflusst die Windrichtung NICHT** (Bruch mit H1 — bewusst, gemäß `mvp_delta`). Die horizontale Navigation hängt von der **Position im Feld** ab.
- Der Ballon driftet kontinuierlich mit dem lokalen Feldvektor.
- **Basis-Drift:** 7–9 m/s (übernommen aus H1_DESIGN §4.3), Turbulenz ±15–25 %.

### 5.2 Höhe als zweite, halb-unabhängige Achse

Höhe bleibt relevant — als **taktische Achse**, nicht als Lenkung:
- **Brenner** hebt; **passives Sinken** (~0.5 m/s) senkt (übernimmt H1_DESIGN §5).
- Höhe entscheidet: einen Berg **überfliegen** vs. ihn umschiffen; am Levelende kontrolliert in die Landezone **absinken**.
- Höhen-Dämpfung des Windes (aus `mvp_delta`): Der Drift wird mit zunehmender Höhe leicht schwächer — hoch fliegen = ruhiger, aber blinder (über den Wolken).

So entstehen **zwei semi-unabhängige Steuerachsen** (horizontal: Feld + Stoß; vertikal: Brenner) — mehr Oberfläche, um die Stationen darum konkurrieren zu lassen.

### 5.3 Stoß / Bash-Nudge

- **Diskreter Impuls senkrecht zur lokalen Strömung** (Unrailed-Stil), aus `mvp_delta`.
- Gebunden an die **Stoß-Ruder-Station** im Korb — kein freier Hotkey. Wer stößt, steht am Ruder.
- **Cooldown ~3–4 s** → Timing-Entscheidung statt Spam. Kein Brennstoff-Kosten (eine Ressource bleibt sauber, H1_DESIGN-Prinzip).
- Funktion: in einen Nachbarstrom wechseln, einem gerade gesichteten Berg ausweichen.

### 5.4 Berge

- **Hand-platzierte Gefahren** (aus `mvp_delta`) — die einzige Gefahr in M2.
- Organische Kegel; Kollision mit dem Gipfel = **Hüllen-Treffer**.
- **3 Treffer = Fail** (einfaches Schadensmodell; Reparatur-Station siehe §16 Stretch).
- Berge ragen hoch genug, um die Reiseflughöhe zu bedrohen, und sind **unter der Wolkendecke teilweise verborgen** (§6) — das verknüpft Navigation und Fog-of-War zu *einem* Problem.

---

## 6. Der H2-Kern — Wolken & Fernrohr

### 6.1 Wolkendecke als Fog-of-War

- Eine **Wolkenschicht** liegt knapp unter der Reiseflughöhe und verdeckt die Sicht nach unten und voraus.
- Verborgen darunter: **Berge, die Landezone, optionale Landmarken**.
- **Wolken driften** mit dem lokalen Strömungsfeld — die Verdeckung ist nicht statisch.
- **Wolkendichte** ist der zentrale Schwierigkeits- und Skalierungs-Hebel (GDD §2.2).
- Referenz-Niveau für Tiefenwirkung: Moodboard Bild 4 (`references/moodboard_04_3d_cloudlayered.png`).

Effekt: Der Ballon fliegt durch eine Welt, über die er **strukturell zu wenig weiß**. Das ist der Spannungsmotor (§9.3).

### 6.2 Fernrohr-Station

Übernimmt GDD §2.3 — hier konkretisiert:
- Eigene Station am Korbrand. Spieler steht dort und **hält die Interaktions-Taste**.
- Während gehalten: ein **Sichtfenster** öffnet sich, das mit einem **zweiten Input** (Stick/Maus) frei in einem Radius (~300 m) um den Ballon bewegt wird.
- Das Fenster reißt **lokal ein Loch in die Wolkendecke** (Richtwert: ~120–160 m Durchmesser).
- **Loch schließt sofort beim Loslassen.** Information ist flüchtig.
- Im Solo-Test ist das der **härteste Kontentions-Punkt**: Wer scoutet, hat die Hand **nicht** am Brenner.

### 6.3 Marker (Fernrohr-Upgrade, in M2 enthalten)

- Ein **persistenter Pin**, durch das Loch platzierbar, bleibt nach dem Schließen sichtbar.
- Ein neuer Marker überschreibt den alten (GDD §2.3).
- Im Solo-Test funktional zentral: der Marker ist das **Gedächtnis**, das den Solo-Spieler entlastet — er scoutet, setzt einen Pin, kehrt zum Brenner zurück und navigiert *zum Pin*. Bei Coop wird daraus ein geteilter Bezugspunkt.

### 6.4 Warum das im Solo-Test funktioniert

Der Solo-Spieler kann **nicht gleichzeitig** brennen, scouten und stoßen. Jede Sekunde am Fernrohr ist eine Sekunde, in der der Ballon ungesteuert sinkt und driftet. Das erzwingt den Kern-Konflikt von H2 schon mit einer Person:

> *„Fliege ich blind weiter — oder gebe ich Höhe und Position auf, um zu sehen, wohin ich überhaupt will?"*

Genau diese Frage wird bei 2–4 Spielern zur **Verhandlung** statt zur Selbstgespräch-Triage. Der Solo-Prototyp beweist, dass die Frage *existiert* und *Gewicht hat*.

---

## 7. Stations-Katalog M2

Minimal, aber mit der Kontentions-Profil-Vorgabe aus §4.2: **2 Dauerlast + 2 Stoßlast**.

| Station | Last-Typ | Aktion | Im Solo-Test |
|---|---|---|---|
| **Brenner** | Dauer | Taste halten = Auftrieb, verbraucht Brennstoff | Dauerpräsenz nötig, sonst sinkt der Ballon |
| **Fernrohr** | Dauer | Taste halten + zweiter Input = Wolkenloch | Direkter Konflikt mit Brenner |
| **Stoß-Ruder** | Stoß | Taste = Impuls senkrecht zur Strömung (Cooldown ~3–4 s) | Bursts bei Strom-/Bergwechsel |
| **Ballast** | Stoß | Sandsack abwerfen = Sofort-Aufstieg | Notfall-Höhe; begrenzte Anzahl an Bord |

**Bewusst NICHT in M2:** Ventil, Anker, Seil-Station, Reparatur-Werkbank, Brennstoff-Nachfüll-Station. Begründung: das Vier-Stationen-Set erzeugt bereits messbare Solo-Kontention; mehr verwässert das H2-Signal. Anker/Reparatur siehe §16.

Das **Marker-Setzen** ist eine Sub-Aktion der Fernrohr-Station, keine eigene Station.

---

## 8. Korb-Raum & Spielerbewegung

### 8.1 Charakter-Movement — jetzt notwendig

H1_DESIGN §11 hatte Korb-Herumlaufen für den reinen H1-Test **bewusst gestrichen** (ein Spieler, eine Station). Für M2 ist es **konstitutiv**: ohne räumliche Bewegung gibt es keine räumliche Knappheit, ohne Knappheit keine Kontention, ohne Kontention kein H2.

- Avatar bewegt sich frei im Korb (Stick / WASD).
- Interaktion mit einer Station: nahe stehen + Taste.
- Eine Station wird **belegt**, solange der Avatar interagiert; er kann sie jederzeit verlassen.

### 8.2 Stationen als Welt-Objekte

- Jede Station ist eine eigene Szene/Node mit einem Interaktions-Trigger (`Area3D`).
- Keine Bindung an Spieler-ID oder Rolle (§4.1).
- Multiplayer-fähig ab Tag 1: 1–4 Avatare teilen sich denselben Stations-Satz.

### 8.3 Korb-Layout

- Runder Korb mit **zentralem Element** (Brenner mittig) — zwingt Wege *um* die Mitte (GDD §4.3, Moodboard Bild 3).
- Die vier Stationen am Korbrand so verteilt, dass **kein Avatar zwei Dauerlast-Stationen ohne Laufweg erreicht** — der Laufweg Brenner↔Fernrohr ist die physische Manifestation der Triage.
- Layout-Tuning ist Playtest-Sache; das Prinzip ist verbindlich.

---

## 9. Soft-Pressure ohne Timer

Spannung **ohne** Countdown — gemäß §3.3 und H1_DESIGN §3.3. Vier Quellen, die sich überlagern:

### 9.1 Das wandernde Strömungsfeld

Das Vektorfeld aus §5.1 **verschiebt sich langsam über die Zeit** (langsame Phasendrift der Sinuswellen). Eine Route, die vor 15 s gültig war, zerfällt. Das ist Dringlichkeit **ohne Uhr** — die Welt wartet nicht, aber sie *bestraft* auch keinen festen Zeitpunkt.

### 9.2 Driftende Wolken

Wolken bewegen sich mit dem Feld (§6.1). Ein durchs Fernrohr gerissenes Loch bleibt nicht „an Ort" — die gesehene Lücke driftet, gesehene Information veraltet. Verstärkt den Wert des Markers (§6.3).

### 9.3 Verborgene Gefahren

Berge unter der Wolkendecke (§5.4 + §6.1). Wer nicht scoutet, fliegt in Gefahr, die er hätte sehen können. Der Fail fühlt sich **verdient** an (§3.3) — die Information war beschaffbar, der Spieler hat sie nicht beschafft.

### 9.4 Brennstoff

Ein einzelner Pool pro Level (übernimmt H1_DESIGN §6). Kein Nachfüllen im Flug. **Glide-to-Ground** bei leerem Tank bleibt erhalten — dramatische Endphase ohne künstlichen Fail-State.

Zusammenwirken: Der Spieler ist **immer leicht hinter der Information** und hat **immer knapp zu wenig Hände**. Das ist das namensgebende Gefühl.

---

## 10. Juice & Feedback-Layer (verbindlich, nicht verschoben)

> **Lehre aus der MDA-Analyse:** Ein Navigations-Prototyp, der allen Juice verschiebt, testet *immer* als flach. Der FEEDBACK-Schritt des Engagement-Loops ist hier **Teil des Experiments**, nicht Politur. H1_DESIGN §5.4 hatte ihn aufgeschoben — M2 holt ihn verbindlich ein.

**Ballon & Korb:**
- Korb-Schwingen (Pendel ~±3°, gedämpft) bei Drift-Änderung und Brenner-Zündung
- Hüllen-„Atmung" als Standby-Animation
- Höhen-Microwobble (Lebendigkeit)

**Brenner:**
- Ausschlagende Flamme, Leucht-Färbung der Hüllen-Unterseite
- Variabler Zisch-Sound je nach Puls-Dauer (hilft beim Dosieren ohne Hinsehen)

**Fernrohr:**
- Linsen-Vignette / Messing-Rahmen um das Sichtfenster (Jules-Verne-Stil, H1_DESIGN §8.4)
- Hör- und sichtbares „Aufreißen" der Wolke beim Öffnen, sanftes Schließen beim Loslassen
- Marker-Setzen mit klarem „Ping" (Audio + kurzer visueller Puls)

**Gefahr & Triage:**
- Dezenter Screen-Shake / Kamera-Tilt bei Beinahe-Bergkontakt
- Hüllen-Treffer: sichtbarer Riss + dumpfer Sound (Schadenszustand bleibt lesbar)
- Niedrig-Brennstoff: warme farbliche Akzentuierung des Messing-Instruments (kein Flackern)

**Ankunft:**
- Landung in der Zone: klare Bestätigung (visuell jetzt, Audio im selben Schritt) — der „verdiente" Moment aus §3.1

**HUD:** Messing-Instrumente unten rechts (Wind + Brennstoff), Stil aus H1_DESIGN §8 übernommen; ein dritter Anzeiger für den Hüllen-Schadenszustand.

---

## 11. Win- & Fail-Bedingungen

Übernimmt H1_DESIGN §7, ergänzt um Gefahren:

**Win:** Ballon berührt den Boden innerhalb der markierten Landezone (Radius ≥ 50 m, vgl. `mvp_delta` `GOAL_RADIUS`). Zustand „gelandet", Abschluss-Screen.

**Zwischenzustand:** Landung außerhalb der Zone mit Restbrennstoff → erneutes Abheben möglich (Retry-Philosophie, kein Zeitdruck).

**Fail:**
- Bodenkontakt außerhalb der Zone **und** Brennstoff = 0, oder
- **3 Hüllen-Treffer** durch Bergkollision, oder
- seitliches Out-of-Bounds (optional als Respawn behandelbar)

**Kein Fail:** lange Spieldauer, kurzzeitig ungünstiger Wind (Spieler kann warten), normale Bodenberührung mit Restbrennstoff.

---

## 12. Solo-Test-Spezifikation

### 12.1 Steuerung (ein Spieler, ein Avatar)

| Input | Aktion |
|---|---|
| Stick / WASD | Avatar im Korb bewegen |
| Interaktions-Taste (halten) | aktuelle Station bedienen (Brenner / Fernrohr / Stoß) |
| Zweiter Stick / Maus | **nur an der Fernrohr-Station:** Sichtfenster bewegen |
| Sekundär-Taste | Marker setzen (an Fernrohr), Sandsack abwerfen (an Ballast) |

Empfehlung: Gamepad, weil der zweite Stick fürs Fernrohr natürlich liegt. Tastatur+Maus als Fallback.

### 12.2 Der Kontentions-Moment (das Herz des Tests)

Der Test gelingt, wenn der Solo-Spieler regelmäßig in die Lage kommt:

> Der Ballon sinkt (Brenner unbedient), ein Berg ist voraus vermutet aber nicht gesehen, der Strom hat gedreht. Der Spieler **kann nur eine** der drei nötigen Stationen erreichen — und muss wählen.

Diese Wahl, mehrfach pro Level, **ist** die zu testende Erfahrung. Der Korb-Laufweg (§8.3) macht die Wahl körperlich spürbar.

---

## 13. Validierungs-Kriterien

### 13.1 Positive Signale (Kontentions-Substrat trägt)

- Spieler **triagiert hörbar/sichtbar** — *„erst Höhe, dann gucken"* — statt mechanisch abzuarbeiten
- Spieler äußert den **Wunsch nach Hilfe** — *„hier bräuchte ich jemanden"* (der direkte Coop-Hook)
- Der **Marker** wird strategisch genutzt (scouten → pinnen → zurück zum Brenner)
- Wiederhol-Wunsch nach Erfolg *und* nach Scheitern
- Der Fail fühlt sich **verdient** an — *„ich hätte scouten müssen"*, nicht *„unfair"*
- Phasen sichtbarer Konzentration (Flow), kein Leerlauf

### 13.2 Negative Signale (Umdenken nötig)

- **Dominante Ignorier-Strategie**: Spieler scoutet nie, brennt nur — und kommt trotzdem durch → Kontention zu schwach, Wolken/Berge zu harmlos
- Spieler fühlt sich **genervt statt angespannt** → Überforderung ist Frust, nicht produktiv (Stationen zu weit auseinander? Sink-Rate zu hart?)
- Fernrohr wird **gar nicht genutzt** → Information kommt nicht an oder ist irrelevant
- *„zäh", „chaotisch im schlechten Sinn", „ich weiß nie was los ist"* in Post-Play-Interviews
- Fails fühlen sich **zufällig** an → verborgene Gefahren sind nicht fair scoutbar

### 13.3 Messmethode

- 3–5 Probands unterschiedlicher Erfahrung, einzeln, Think-aloud
- Strukturiertes Post-Play-Interview (~10 Min). Fokusfragen:
  - Wann hast du dir gewünscht, an zwei Stellen gleichzeitig zu sein?
  - Woher wusstest du, wohin du fliegen musst?
  - Hat sich ein Fehlschlag fair angefühlt? Warum?
  - Würdest du das zu zweit/zu viert spielen wollen?
- Beobachtungs-Notizen: Triage-Verhalten, Laufwege, Frustrations- vs. Spannungs-Marker
- Keine Analytics — zu früh.

---

## 14. Level-Architektur (Godot 4 / Prototyp)

Kein Tile/Grid (übernimmt H1_DESIGN §10.1). Skizze, aufbauend auf der `mvp_delta`-Struktur:

```
Level_M2.tscn (Node3D)
├── Terrain.tscn          (Landschafts-Mesh, Landezone-Marker als Area3D)
├── WindField             (Vektorfeld-Logik: f(x,z), langsame Phasendrift §9.1)
├── Mountains/            (hand-platzierte Gefahr-Kegel, gemeinsame Footprint-Funktion §5.4)
├── CloudLayer.tscn       (driftende Wolkendecke, Fog-of-War §6.1)
├── StartPoint (Marker3D)
└── LevelBounds.tscn

Basket.tscn               (multiplayer-fähig: 1–4 Avatare, hier 1)
├── BasketMesh + Kollisionsgrenzen
├── Station_Brenner       (Area3D-Trigger, rollenlos)
├── Station_Fernrohr      (Area3D-Trigger)
├── Station_StossRuder    (Area3D-Trigger)
├── Station_Ballast       (Area3D-Trigger)
└── BurnerFlame, FuelTankMesh (Juice §10)

Player.tscn               (CharacterBody3D, instanziiert 1× — Spawn-Code 1..4-fähig)

Telescope.tscn            (Sichtfenster-Logik, Wolkenloch-Shader, Marker)

Camera.tscn               (45°-Schräg-Draufsicht, vertikale Dämpfung — H1_DESIGN §9)

UI.tscn (CanvasLayer)      (Messing-Instrumente: Wind, Brennstoff, Hüllen-Schaden)
```

**Architektur-Pflicht:** Der Avatar-Spawn liest eine Spielerzahl-Variable; im Prototyp fest = 1. Stationen sprechen **nie** eine Spieler-ID an. Damit ist der Sprung auf 2–4 Spieler eine Konfig-Änderung plus Input-Device-Zuordnung — kein Umbau.

---

## 15. Entwicklungsetappen M2 (Reframe von GDD §6 Etappen 5–8)

Die Adoption von `mvp_delta` und der Solo-Skalierungs-Ansatz verschieben die GDD-Reihenfolge. Jede Etappe bleibt **lauffähig und testbar** (GDD-Prinzip §6).

| Etappe | Inhalt | Testbar |
|---|---|---|
| **M2-E5** | Korb + Charakter-Movement + rollenloses Stations-System (Spawn 1..4-fähig, 1 Avatar) | Avatar läuft im Korb, belegt/verlässt Stationen |
| **M2-E6** | Strömungsfeld-Navigation aus `mvp_delta` portiert + Stoß-Ruder + Berge | Navigation durch ein kontinuierliches Windfeld, Bergausweichen |
| **M2-E7** | Wolkendecke als Fog-of-War, driftend | Fliegen mit strukturell eingeschränkter Sicht |
| **M2-E8** | Fernrohr-Station + Marker + Wolkenloch | Solo-Kontention messbar: brennen vs. scouten |
| **M2-E8.5** | Juice-/Feedback-Layer (§10) verbindlich integrieren | Prototyp fühlt sich „juicy" an — Voraussetzung für valides Playtesting |

Nach M2-E8.5: **Solo-Playtest** gemäß §13. Erst bei grünem Signal folgt der Multiplayer-Build (Etappe 5 der ursprünglichen GDD-Reihenfolge — lokaler Mehrspieler-Test) und damit der **echte H2-Test**.

---

## 16. Offene Punkte für die Implementierung

Während des Prototypings zu klären, nicht vorab:

- **Tuning:** Sink-Rate vs. Laufweg Brenner↔Fernrohr — wie lang darf der Ballon „unbeaufsichtigt" sein, damit Kontention spannend statt frustrierend wird?
- **Wolkenloch-Technik in Godot 4:** Shader-Maske, GPUParticles, Mesh-Layer? (Performance, Lesbarkeit in 45°-Sicht)
- **Strömungsfeld-Drift-Rate (§9.1):** wie schnell darf das Feld wandern, ohne unfair zu werden?
- **Wolkendichte-Startwert** für ein Solo-Level — dicht genug für echten Fog-of-War, licht genug für Fairness
- **Stretch — Anker-Station:** als fünfte Station denkbar (Notstopp, GDD §2.6). Erst aufnehmen, wenn der Solo-Test zeigt, dass vier Stationen *zu wenig* Kontention erzeugen.
- **Stretch — Reparatur-Station:** macht Hüllen-Schaden zu einer laufenden Aufgabe (gute zusätzliche Dauerlast für 4-Spieler-Skalierung). Bewusst aus dem Prototyp ausgeklammert, um den Solo-Test fokussiert zu halten.
- **Out-of-Bounds:** harter Fail oder Respawn — Entscheidung beim Prototypen.

---

## 17. Referenzen

### 17.1 Projektintern
- `BALLON_GDD.md` §1.3 (H2-Hypothese), §2 (Kernmechaniken), §6 Etappen 5–8
- `H1_DESIGN.md` — Geschwister-Spezifikation; M2 übernimmt §5 (Ballon-Physik), §6 (Brennstoff), §7 (Win/Fail), §8 (HUD-Stil), §9 (Kamera)
- `MVP_CETA_DESIGN.md` — verworfene Tile-Laying-Exploration
- `mvp_delta/` — Navigationsbasis (Strömungsfeld, Stoß, Berge)
- `references/moodboard_04_3d_cloudlayered.png` — Referenz-Niveau für Wolken-Tiefenwirkung
- `references/moodboard_06_camera_cruise_golden.png` — Kamera-Baseline

### 17.2 Design-Analogien
- **Lovers in a Dangerous Spacetime** — geteiltes Fahrzeug, rollenlose Stationen, Kontention statt Hektik
- **We Were Here** — Spannung aus geteilter, unvollständiger Information
- **Unrailed** — Stoß-Mechanik, Couch-Coop-Fairness, emergente Rollen

### 17.3 Anti-Referenzen
- **Overcooked** — Zeitdruck-getriebene Hektik; M2 sucht *Spannung*, nicht *Stress*
- **Flight-Sims / Ballon-Simulatoren** — Simulationstreue als Selbstzweck

---

## 18. Änderungshistorie

- **2026-05-20 · v0.1.0** — Erster Entwurf. Reframing von M2 auf die Zielästhetik „Tense Shared-Vehicle Coordination Journey" nach MDA-Analyse der drei Navigations-Prototypen. Navigationsbasis von Conveyor-Belt (H1) auf Stream-Navigation (`mvp_delta`) umgestellt; `mvp_ceta` (Tile-Laying) stillgelegt. Solo-Test-Paradox formuliert und aufgelöst: der Ein-Spieler-Prototyp validiert die *Vorbedingung* von H2 (echte Stations-Kontention), nicht H2 selbst. Stations-Katalog (2 Dauerlast + 2 Stoßlast), rollenlose Skalierungs-Architektur 1→4, Soft-Pressure-Konzept ohne Timer, verbindlicher Juice-/Feedback-Layer, Solo-Steuerung und Validierungs-Kriterien spezifiziert. Entwicklungsetappen M2-E5 bis M2-E8.5 als Reframe von GDD §6 Etappen 5–8. Engine-Entscheidung: M2-Prototyp wird direkt in Godot 4 gebaut (`mvp_epsilon/`), `mvp_delta`-Logik wird in GDScript reimplementiert.
