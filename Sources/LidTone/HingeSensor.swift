import Foundation
import IOKit.hid
import LidToneCore

final class HingeSensor {
    private var manager: IOHIDManager?
    private var device: IOHIDDevice?

    func connect() throws {
        close()
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        // Match ONLY the built-in Apple hinge orientation sensor, never keyboards or mice.
        let match: [String: Any] = [kIOHIDVendorIDKey: 0x05ac, kIOHIDPrimaryUsagePageKey: 0x20, kIOHIDPrimaryUsageKey: 0x8a]
        IOHIDManagerSetDeviceMatching(manager, match as CFDictionary)
        let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []
        guard let device = devices.first else { throw SensorError.missing }
        let result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else { throw SensorError.access(result) }
        self.manager = manager; self.device = device
        do { _ = try read() }
        catch { close(); throw error }
    }

    func read() throws -> Double {
        guard let device else { throw SensorError.missing }
        var report = [UInt8](repeating: 0, count: 8)
        var length = report.count
        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &report, &length)
        guard result == kIOReturnSuccess else { throw SensorError.read(result) }
        guard let angle = HingeReport.decode(Array(report.prefix(length))) else { throw SensorError.invalid }
        return angle
    }

    func close() {
        if let device { IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)) }
        device = nil; manager = nil
    }
    deinit { close() }
}

enum SensorError: LocalizedError {
    case missing, access(IOReturn), read(IOReturn), invalid
    var errorDescription: String? {
        switch self {
        case .missing: return "This Mac does not expose a supported hinge-angle sensor. Motion preview still works."
        case .access(let code): return String(format:"Hinge sensor access failed (0x%08x).",code)
        case .read(let code): return String(format:"Hinge sensor stopped responding (0x%08x).",code)
        case .invalid: return "The hinge sensor returned an unsupported report."
        }
    }
}
