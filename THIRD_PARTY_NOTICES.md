# Hinweise zu Fremdcode

G13forever steht unter der MIT-Lizenz (siehe `LICENSE`). Teile des Codes
stammen aus bzw. orientieren sich an den folgenden MIT-lizenzierten Projekten.
Deren Lizenztexte sind hier vollständig wiedergegeben.

Code aus GPL-lizenzierten Projekten (z. B. cavefish-dev/g13-driver) wird
bewusst **nicht** übernommen.

## golgote/G13

https://github.com/golgote/G13

Verwendet in:
- `Sources/G13Kit/LCD/BitmapFont.swift`: 5x7-Glyphen (Ziffern, Buchstaben, Satzzeichen)
- `Sources/G13Kit/LCD/LCDFrame.swift`: Page-Layout des LCD-Puffers
- `Sources/G13Kit/Device/G13Device.swift`: IOKit-HID-Ansatz, Report-IDs und -Formate für LCD, Hintergrundbeleuchtung und M-LEDs
- `Sources/G13Kit/Device/G13InputReport.swift`: Reihenfolge der Tasten-Bits

```
MIT License

Copyright (c) 2026 Bertrand Mansion

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## jonas-werner/g13-configurator

https://github.com/jonas-werner/g13-configurator

Verwendet in:
- `Sources/G13Kit/LCD/LCDFrame.swift`: Frame-Format (32-Byte-Header + 960 Byte, Report 0x03)
- `Sources/G13Kit/LCD/ImageLoader.swift`: Bild-/GIF-Aufbereitung (ein Frame pro GIF-Frame mit dessen Dauer)

Die Beispielgrafiken aus jenem Repository (Spiele-Artwork) sind **nicht** enthalten.

```
MIT License

Copyright (c) 2026 Jonas Werner

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
