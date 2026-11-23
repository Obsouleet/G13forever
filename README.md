# G13forever

macOS-Treiber für die Logitech G13 in Swift, mit Bildern und GIFs auf dem
160x43-Display. Läuft ohne Kernel-Treiber und ohne root über IOKit HID.

> **Stand:** Menüleisten-App mit Profilen, Tastenbelegung und Bild/GIF pro
> Profil. Dazu das Kommandozeilen-Werkzeug `g13ctl` zum Ausprobieren.

## Aufbau

| Teil | Inhalt |
| --- | --- |
| `Sources/G13Kit/LCD` | `LCDFrame` (160x43-Framebuffer, 992-Byte-Report), 5x7-Schrift, Graustufen→1 Bit (Schwellwert oder Floyd-Steinberg), `ImageLoader` für PNG/JPEG/GIF |
| `Sources/G13Kit/Profiles` | `G13Profile`/`ProfileLibrary` (JSON), `KeyCombo` und `KeyCodes` (Tastenkürzel), `BindingEngine` (Tasten → Aktionen), `ProfileRenderer` |
| `Sources/G13Kit/Input` | `KeyInjector`: schickt Tastendrücke und Text über CGEvent an macOS |
| `Sources/G13Kit/Artwork`, `Sources/G13Kit/Resources` | Bild der G13 (`g13.svg`) und die Klickflächen der Tasten (`g13-keys.svg`) |
| `Sources/G13App` | Menüleisten-App (SwiftUI) |
| `Sources/G13Kit/Device` | `G13Device` (IOKit HID: finden, LCD-Frame senden, Hintergrundfarbe, M-LEDs, Tasten mitlesen), `G13InputReport` |
| `Sources/g13ctl` | Kommandozeilen-Werkzeug zum Ausprobieren |
| `Tests/G13KitTests` | Tests für Bitlayout, Schrift, Dithering und Tasten-Reports |

## Voraussetzungen

- macOS 14 oder neuer
- Xcode 15 oder neuer (oder die Command Line Tools mit Swift 5.9+)

## Bauen und testen

```sh
swift build
swift test
```

## Menüleisten-App

```sh
scripts/build-app.sh          # baut build/G13forever.app
open build/G13forever.app
```

Zum schnellen Testen geht auch `swift run G13App`, dann gelten die
Freigaben aber für das Terminal statt für die App.

Oben in der Menüleiste erscheint ein Tastatur-Symbol. Dort wählt man das
aktive Profil, öffnet **Profile bearbeiten …** und kann den Autostart
einschalten. Pro Profil lassen sich einstellen:

- **Name und Hintergrundfarbe** der G13
- **Bild oder GIF** fürs Display, mit Vorschau, Skalierung, Dithering oder
  Schwellwert und Invertieren. Ohne Bild steht der Profilname auf dem Display.
- **Joystick**: aus, Pfeiltasten oder W/A/S/D
- **Tastenbelegung** für G1–G22, die Daumentasten, den Stick, BD, L1–L4 und
  M1–M3/MR: Tastenkürzel (z. B. `cmd+shift+4`, `f5`, `space` oder per
  „Aufnehmen“), Text tippen, zu einem Profil wechseln, nächstes/vorheriges Profil.
  Tastenkürzel bleiben gedrückt, solange die G13-Taste gedrückt ist, das passt
  auch für Spiele. Die Taste wählt man im Bild der G13 per Klick oder durch
  Drücken auf der G13, ihre Einstellungen stehen direkt darunter.

M1, M2 und M3 wechseln standardmäßig zu Profil 1, 2 und 3, die passende LED
leuchtet. Beim Wechsel blendet das Display kurz den Profilnamen ein.

Die Profile liegen in `~/Library/Application Support/G13forever/profiles.json`,
die Bilder daneben im Ordner `Images`.

### Freigaben

- **Bedienungshilfen** (Systemeinstellungen > Datenschutz & Sicherheit):
  nötig, damit die App Tastendrücke senden darf. Die App fragt beim ersten
  Start danach.
- **Eingabeüberwachung**: nur falls macOS den Zugriff auf die G13 verweigert.

Weil `build-app.sh` ad-hoc signiert, will macOS die Freigabe nach jedem neuen
Build eventuell erneut. Mit einem eigenen Zertifikat bleibt sie erhalten:
`SIGN_IDENTITY="Apple Development: …" scripts/build-app.sh`.

## Ausprobieren mit g13ctl

Ohne G13 (nur Vorschau im Terminal):

```sh
swift run g13ctl preview --pattern
swift run g13ctl preview --text "Hallo G13"
swift run g13ctl preview ~/Bilder/logo.png --fill
```

Mit angeschlossener G13:

```sh
swift run g13ctl info                       # wird die G13 gefunden?
swift run g13ctl pattern                    # Testbild: Rahmen, Ecke oben links, Schachbrett
swift run g13ctl text "Hallo Hank"
swift run g13ctl image ~/Bilder/animation.gif
swift run g13ctl backlight 255 80 0         # Orange
swift run g13ctl keys                       # Tasten und Joystick mitlesen
```

Bildoptionen: `--fit` (Standard), `--fill`, `--stretch`, `--threshold 128`
statt Dithering, `--invert`, wenn dunkle statt helle Bildteile leuchten sollen,
`--invert-display` kehrt den fertigen Frame um, `--once` spielt ein GIF nur
einmal ab.

Grafiken in genau 160x43 Pixeln sehen am besten aus.

### Falls der Zugriff verweigert wird (g13ctl)

macOS kann den Zugriff auf HID-Geräte blockieren. Dann unter
**Systemeinstellungen > Datenschutz & Sicherheit > Eingabeüberwachung** das
Terminal (bzw. später die App) erlauben und den Befehl erneut starten.

## Hardware-Erkenntnisse

- `g13ctl info` meldet einen Output-Report von 992 Byte, genau ein LCD-Frame.
- Gesetzte Pixel leuchten hell. Bilder werden deshalb so umgesetzt, dass helle
  Bildteile leuchten (wie auf einem Bildschirm).
- Der USB-"init"-Control-Transfer der Linux-Treiber ist auf macOS nicht nötig:
  Frames per HID-Output-Report 0x03 kommen direkt an.

## Herkunft und Lizenzen

MIT-Lizenz, siehe `LICENSE`. Teile basieren auf
[golgote/G13](https://github.com/golgote/G13) und
[jonas-werner/g13-configurator](https://github.com/jonas-werner/g13-configurator)
(beide MIT), Details in `THIRD_PARTY_NOTICES.md`. Code aus GPL-Projekten wird
nicht übernommen.
