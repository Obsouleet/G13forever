// g13ctl – Kommandozeilen-Prototyp für die Logitech G13 unter macOS.
//
//   g13ctl info                      Gefundene G13 anzeigen
//   g13ctl pattern                   Testbild aufs Display
//   g13ctl text "Hello World"         Text aufs Display
//   g13ctl image bild.png|anim.gif   Bild/GIF aufs Display
//   g13ctl preview bild.png          Bild nur im Terminal anzeigen (ohne G13)
//   g13ctl clear                     Display leeren
//   g13ctl backlight R G B           Hintergrundfarbe (0–255)
//   g13ctl keys                      Tastendrücke und Joystick mitlesen

import Foundation
import G13Kit

let usage = """
Usage: g13ctl <command> [options]

Commands:
  info                         Show connected G13s
  pattern                      Send a test pattern to the display
  text "<text>"                Show centered text (up to 5 lines)
  image <file>                 Show PNG/JPEG/GIF, animated GIFs loop
  preview <file> | --text "<text>" | --pattern
                               Show the result in the terminal only, no G13 needed
  clear                        Clear the display
  backlight <R> <G> <B>        Set the backlight color (0–255 each)
  keys                         Watch keys and joystick (Ctrl-C to quit)

Options for image/preview:
  --fit | --fill | --stretch   Scaling to 160x43 (default: --fit)
  --threshold <0-255>          Fixed threshold instead of dithering
  --invert                     Light up dark instead of light pixels
  --once                       Play an animation only once
  --invert-display             Invert the finished frame (also for text/pattern)
"""

struct Options {
    var positional: [String] = []
    var scale: ScaleModeOption = .fit
    var threshold: UInt8?
    var invert = false
    var invertDisplay = false
    var once = false
    var previewText: String?
    var previewPattern = false

    enum ScaleModeOption: String { case fit, fill, stretch }
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(1)
}

func parse(_ args: ArraySlice<String>) -> Options {
    var options = Options()
    var it = args.makeIterator()
    while let arg = it.next() {
        switch arg {
        case "--fit": options.scale = .fit
        case "--fill": options.scale = .fill
        case "--stretch": options.scale = .stretch
        case "--invert": options.invert = true
        case "--invert-display": options.invertDisplay = true
        case "--once": options.once = true
        case "--pattern": options.previewPattern = true
        case "--threshold":
            guard let value = it.next(), let number = UInt8(value) else { fail("--threshold needs a number from 0 to 255") }
            options.threshold = number
        case "--text":
            guard let value = it.next() else { fail("--text needs a text") }
            options.previewText = value
        case "-h", "--help": print(usage); exit(0)
        default:
            if arg.hasPrefix("--") { fail("Unknown option: \(arg)\n\n\(usage)") }
            options.positional.append(arg)
        }
    }
    return options
}

func finish(_ frame: LCDFrame, _ options: Options) -> LCDFrame {
    var frame = frame
    if options.invertDisplay { frame.invert() }
    return frame
}

#if canImport(IOKit) && canImport(ImageIO)

func loadFrames(_ path: String, _ options: Options) -> [AnimationFrame] {
    let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    let scale: ScaleMode
    switch options.scale {
    case .fit: scale = .fit
    case .fill: scale = .fill
    case .stretch: scale = .stretch
    }
    let mode: MonochromeMode = options.threshold.map { .threshold($0) } ?? .floydSteinberg
    do {
        return try ImageLoader.load(url, scale: scale, mode: mode, invert: options.invert)
            .map { AnimationFrame(frame: finish($0.frame, options), duration: $0.duration) }
    } catch {
        fail("\(error)")
    }
}

func openDevice() -> G13Device {
    do { return try G13Device.first() } catch { fail("\(error)") }
}

func send(_ frame: LCDFrame, to device: G13Device) {
    do { try device.send(frame) } catch { fail("\(error)") }
}

let arguments = CommandLine.arguments.dropFirst()
guard let command = arguments.first else { print(usage); exit(0) }
let options = parse(arguments.dropFirst())

switch command {
case "info":
    let devices: [G13Device]
    do { devices = try G13Device.findAll() } catch { fail("\(error)") }
    if devices.isEmpty { fail(G13Error.notFound.description) }
    for (index, device) in devices.enumerated() {
        print("[\(index)] \(device.manufacturer) \(device.productName)")
        print("    Serial number: \(device.serialNumber ?? "–")")
        print("    Location-ID:   0x\(String(device.locationID, radix: 16))")
        print("    Max. output report:  \(device.maxOutputReportSize.map { String($0) } ?? "?") bytes (LCD needs \(LCDFrame.reportSize))")
        print("    Max. feature report: \(device.maxFeatureReportSize.map { String($0) } ?? "?") bytes")
    }

case "pattern":
    send(finish(.testPattern(), options), to: openDevice())
    print("Test pattern sent.")

case "text":
    guard !options.positional.isEmpty else { fail("Usage: g13ctl text \"<text>\"") }
    send(finish(.text(options.positional.joined(separator: " ")), options), to: openDevice())
    print("Text sent.")

case "clear":
    send(LCDFrame(), to: openDevice())
    print("Display cleared.")

case "image":
    guard let path = options.positional.first else { fail("Usage: g13ctl image <file>") }
    let frames = loadFrames(path, options)
    let device = openDevice()
    if frames.count == 1 {
        send(frames[0].frame, to: device)
        print("Image sent.")
    } else {
        print("Animation with \(frames.count) frames\(options.once ? "" : ", Ctrl-C to quit").")
        repeat {
            for item in frames {
                send(item.frame, to: device)
                Thread.sleep(forTimeInterval: item.duration)
            }
        } while !options.once
    }

case "preview":
    let frame: LCDFrame
    if options.previewPattern {
        frame = finish(.testPattern(), options)
    } else if let text = options.previewText {
        frame = finish(.text(text), options)
    } else if let path = options.positional.first {
        let frames = loadFrames(path, options)
        if frames.count > 1 { print("Animation with \(frames.count) frames, the preview shows frame 1.") }
        frame = frames[0].frame
    } else {
        fail("Usage: g13ctl preview <file> | --text \"<text>\" | --pattern")
    }
    print(frame.asciiPreview())

case "backlight":
    let values = options.positional.compactMap { UInt8($0) }
    guard values.count == 3 else { fail("Usage: g13ctl backlight <R> <G> <B>  (0–255 each)") }
    do { try openDevice().setBacklight(red: values[0], green: values[1], blue: values[2]) } catch { fail("\(error)") }
    print("Backlight color set.")

case "keys":
    let device = openDevice()
    var previous = G13InputReport()
    print("Watching keys, Ctrl-C to quit.")
    device.startInputMonitoring { report in
        let (pressed, released) = report.changes(since: previous)
        for key in pressed.sorted(by: { $0.bitIndex < $1.bitIndex }) { print("▼ \(key.rawValue)") }
        for key in released.sorted(by: { $0.bitIndex < $1.bitIndex }) { print("▲ \(key.rawValue)") }
        if report.joystickX != previous.joystickX || report.joystickY != previous.joystickY {
            print("Joystick x=\(report.joystickX) y=\(report.joystickY)")
        }
        previous = report
    }
    CFRunLoopRun()

case "-h", "--help", "help":
    print(usage)

default:
    fail("Unknown command: \(command)\n\n\(usage)")
}

#else

// Ohne IOKit/ImageIO (z. B. Linux) bleibt nur die Text-Vorschau.
let arguments = CommandLine.arguments.dropFirst()
let options = parse(arguments.dropFirst())
switch arguments.first {
case "preview"? where options.previewPattern:
    print(finish(.testPattern(), options).asciiPreview())
case "preview"? where options.previewText != nil:
    print(finish(.text(options.previewText!), options).asciiPreview())
default:
    fail("Only `preview --text` and `preview --pattern` work on this platform.")
}

#endif
