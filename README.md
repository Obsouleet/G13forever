# G13forever

macOS-Treiber für die Logitech G13 in Swift, mit Bildern und GIFs auf dem
160x43-Display. Läuft ohne Kernel-Treiber und ohne root über IOKit HID.

> **Stand:** Grundgerüst mit Display-Prototyp. Noch nicht mit echter
> Hardware getestet. Die Menüleisten-App mit Profilen und Tastenbelegung
> folgt in den nächsten Schritten.

## Aufbau

| Teil | Inhalt |
| --- | --- |
| `Sources/G13Kit/LCD` | `LCDFrame` (160x43-Framebuffer, 992-Byte-Report), 5x7-Schrift, Graustufen→1 Bit (Schwellwert oder Floyd-Steinberg), `ImageLoader` für PNG/JPEG/GIF |
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

## Ausprobieren

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
statt Dithering, `--invert` für hell-auf-dunkel gestaltete Grafiken,
`--invert-display` kehrt den fertigen Frame um, `--once` spielt ein GIF nur
einmal ab.

Grafiken in genau 160x43 Pixeln sehen am besten aus.

### Falls der Zugriff verweigert wird

macOS kann den Zugriff auf HID-Geräte blockieren. Dann unter
**Systemeinstellungen > Datenschutz & Sicherheit > Eingabeüberwachung** das
Terminal (bzw. später die App) erlauben und den Befehl erneut starten.

## Was beim ersten Hardwaretest geprüft wird

1. `g13ctl info` findet die G13 und meldet einen Output-Report von mindestens 992 Byte.
2. `g13ctl pattern` zeigt das Testbild richtig herum (gefülltes Quadrat oben links).
3. Ob gesetzte Pixel dunkel oder hell erscheinen. Danach richtet sich der Standard für `--invert`.
4. Linux-Treiber schicken vor jedem Frame einen USB-"init"-Control-Transfer.
   golgote/G13 kommt auf macOS ohne aus. Bleibt das Display leer, ist das die erste Spur.

## Herkunft und Lizenzen

MIT-Lizenz, siehe `LICENSE`. Teile basieren auf
[golgote/G13](https://github.com/golgote/G13) und
[jonas-werner/g13-configurator](https://github.com/jonas-werner/g13-configurator)
(beide MIT), Details in `THIRD_PARTY_NOTICES.md`. Code aus GPL-Projekten wird
nicht übernommen.
