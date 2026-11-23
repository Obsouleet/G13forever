// G13Device.swift
// Zugriff auf die Logitech G13 über IOKit HID, ohne Kernel-Treiber und ohne root.
//
// Der Ansatz (IOHIDManager, Feature-Reports 0x05/0x07, Output-Report 0x03
// mit 992 Byte für das LCD) folgt golgote/G13 (G13Device.swift, MIT,
// siehe THIRD_PARTY_NOTICES.md), das auf macOS mit echter Hardware läuft.
//
// Offene Frage für den ersten Hardwaretest: Linux-Treiber schicken vor jedem
// LCD-Frame einen "init"-Control-Transfer. golgote/G13 kommt auf macOS ohne
// ihn aus. Falls das Display bei uns leer bleibt, ist das die erste Spur.

#if canImport(IOKit)
import Foundation
import IOKit
import IOKit.hid

public enum G13Error: Error, CustomStringConvertible {
    case managerOpenFailed(IOReturn)
    case notFound
    case reportFailed(String, IOReturn)

    public var description: String {
        switch self {
        case .managerOpenFailed(let code):
            var text = String(localized: "The HID manager could not be opened (\(G13Error.hex(code))).")
            if code == G13Error.notPermitted {
                text += " " + String(localized: "macOS denies access: allow the app or your terminal under System Settings > Privacy & Security > Input Monitoring.")
            }
            return text
        case .notFound:
            return String(localized: "No Logitech G13 found (USB 046d:c21c). Is it plugged in?")
        case .reportFailed(let what, let code):
            return String(localized: "\(what) failed (\(G13Error.hex(code))).")
        }
    }

    /// kIOReturnNotPermitted; das C-Makro ist in Swift nicht verfügbar.
    static let notPermitted = IOReturn(bitPattern: 0xE000_02E2)

    static func hex(_ code: IOReturn) -> String {
        String(format: "0x%08X", UInt32(bitPattern: code))
    }
}

public final class G13Device {

    public static let vendorID = 0x046D
    public static let productID = 0xC21C

    public let hidDevice: IOHIDDevice
    /// Der Manager muss so lange leben wie das Gerät benutzt wird.
    private let manager: ManagerHandle

    private var inputHandler: ((G13InputReport) -> Void)?
    private var removalHandler: (() -> Void)?
    private let inputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)

    /// Schließt den gemeinsamen HID-Manager, sobald das letzte Gerät freigegeben ist.
    private final class ManagerHandle {
        let manager: IOHIDManager
        init(_ manager: IOHIDManager) { self.manager = manager }
        deinit { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }
    }

    private init(hidDevice: IOHIDDevice, manager: ManagerHandle) {
        self.hidDevice = hidDevice
        self.manager = manager
    }

    deinit {
        if inputHandler != nil {
            IOHIDDeviceUnscheduleFromRunLoop(hidDevice, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue)
        }
        inputBuffer.deallocate()
    }

    // MARK: Finden

    /// Sucht alle angeschlossenen G13 und öffnet sie.
    public static func findAll() throws -> [G13Device] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDVendorIDKey as String: vendorID,
            kIOHIDProductIDKey as String: productID,
        ] as CFDictionary)

        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else { throw G13Error.managerOpenFailed(result) }

        guard let set = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>, !set.isEmpty else {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            return []
        }
        let handle = ManagerHandle(manager)
        return set
            .map { G13Device(hidDevice: $0, manager: handle) }
            .sorted { $0.locationID < $1.locationID }
    }

    /// Die erste gefundene G13.
    public static func first() throws -> G13Device {
        guard let device = try findAll().first else { throw G13Error.notFound }
        return device
    }

    // MARK: Eigenschaften

    public var productName: String { property(kIOHIDProductKey) as? String ?? "G13" }
    public var manufacturer: String { property(kIOHIDManufacturerKey) as? String ?? "Logitech" }
    public var serialNumber: String? { property(kIOHIDSerialNumberKey) as? String }
    public var locationID: Int { property(kIOHIDLocationIDKey) as? Int ?? 0 }
    public var maxOutputReportSize: Int? { property(kIOHIDMaxOutputReportSizeKey) as? Int }
    public var maxFeatureReportSize: Int? { property(kIOHIDMaxFeatureReportSizeKey) as? Int }

    private func property(_ key: String) -> Any? {
        IOHIDDeviceGetProperty(hidDevice, key as CFString)
    }

    // MARK: Ausgabe

    /// Schickt einen Frame aufs Display.
    public func send(_ frame: LCDFrame) throws {
        try setReport(.output, id: LCDFrame.reportID, bytes: frame.reportBytes(), what: String(localized: "Sending the LCD frame"))
    }

    /// Setzt die RGB-Hintergrundbeleuchtung.
    public func setBacklight(red: UInt8, green: UInt8, blue: UInt8) throws {
        try setReport(.feature, id: 0x07, bytes: [0x07, red, green, blue, 0x00], what: String(localized: "Setting the backlight color"))
    }

    /// Schaltet die LEDs über M1/M2/M3/MR.
    public func setModeLEDs(_ leds: G13ModeLEDs) throws {
        try setReport(.feature, id: 0x05, bytes: [0x05, leds.rawValue, 0x00, 0x00, 0x00], what: String(localized: "Setting the M LEDs"))
    }

    enum ReportKind { case output, feature }

    private func setReport(_ kind: ReportKind, id: UInt8, bytes: [UInt8], what: String) throws {
        let type = kind == .output ? kIOHIDReportTypeOutput : kIOHIDReportTypeFeature
        let result = bytes.withUnsafeBufferPointer { buffer in
            IOHIDDeviceSetReport(hidDevice, type, CFIndex(id), buffer.baseAddress!, buffer.count)
        }
        guard result == kIOReturnSuccess else { throw G13Error.reportFailed(what, result) }
    }

    // MARK: Eingabe

    /// Meldet jeden Input-Report an `handler`. Läuft auf dem RunLoop des
    /// aufrufenden Threads, der danach laufen muss (z. B. `CFRunLoopRun()`).
    public func startInputMonitoring(_ handler: @escaping (G13InputReport) -> Void) {
        let first = inputHandler == nil
        inputHandler = handler
        guard first else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(hidDevice, inputBuffer, 64, g13InputReportCallback, context)
        IOHIDDeviceScheduleWithRunLoop(hidDevice, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue)
    }

    /// Wird aufgerufen, wenn die G13 abgezogen wird. Kommt über denselben
    /// RunLoop wie die Input-Reports, also `startInputMonitoring` ebenfalls aufrufen.
    public func onRemoval(_ handler: @escaping () -> Void) {
        let first = removalHandler == nil
        removalHandler = handler
        guard first else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterRemovalCallback(hidDevice, g13RemovalCallback, context)
    }

    /// Meldet Input-Reports und Abziehen nicht mehr.
    public func stopMonitoring() {
        if inputHandler != nil {
            IOHIDDeviceUnscheduleFromRunLoop(hidDevice, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue)
        }
        inputHandler = nil
        removalHandler = nil
    }

    fileprivate func handleRemoval() {
        removalHandler?()
    }

    fileprivate func handleInput(_ bytes: [UInt8]) {
        guard let report = G13InputReport(bytes: bytes) else { return }
        inputHandler?(report)
    }
}

private func g13RemovalCallback(context: UnsafeMutableRawPointer?, result: IOReturn, sender: UnsafeMutableRawPointer?) {
    guard let context else { return }
    Unmanaged<G13Device>.fromOpaque(context).takeUnretainedValue().handleRemoval()
}

private func g13InputReportCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    type: IOHIDReportType,
    reportID: UInt32,
    report: UnsafeMutablePointer<UInt8>,
    reportLength: CFIndex
) {
    guard let context else { return }
    let device = Unmanaged<G13Device>.fromOpaque(context).takeUnretainedValue()
    device.handleInput(Array(UnsafeBufferPointer(start: report, count: reportLength)))
}
#endif
