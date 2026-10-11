import Foundation
import CoreBluetooth

/**
 ProprietaryProtocol
 
 Samsung Authenticated GATT Service observer for Galaxy Fit3 (SM-R390).
 All UUIDs confirmed from real device GATT enumeration (2026-10-11).
 
 Discovered Proprietary Services:
 - eedd5e73-6aa8-4673-8219-398a489da87c  → Samsung Auth/Crypto
 - 00001a1a-0000-1000-8000-00805f9b34fb  → Samsung Data Channel (encrypted)
 - 0000fd69-0000-1000-8000-00805f9b34fb  → Samsung Find Device
 - 1b7e8251-2877-41c3-b46e-cf057c562023  → Samsung SAP Transport
 
 WARNING:
 This is EXPERIMENTAL and research-only.
 The cipher key and proprietary handshake algorithms are undocumented.
 This implementation NEVER sends writes or attempts authentication.
 It only safely reads advertised characteristics to confirm hardware presence.
 */
@MainActor
public final class ProprietaryProtocol: ObservableObject {
    // MARK: - Confirmed Service UUIDs (from live GATT enumeration)
    public static let authServiceUUID    = CBUUID(string: "eedd5e73-6aa8-4673-8219-398a489da87c")
    public static let dataChannelUUID    = CBUUID(string: "00001a1a-0000-1000-8000-00805f9b34fb")
    public static let findDeviceUUID     = CBUUID(string: "0000fd69-0000-1000-8000-00805f9b34fb")
    public static let sapTransportUUID   = CBUUID(string: "1b7e8251-2877-41c3-b46e-cf057c562023")

    // MARK: - Confirmed Auth Characteristic UUIDs
    public static let cipherCharUUID         = CBUUID(string: "50f98bfd-158c-4efa-add4-0a70c2f5df5d")
    public static let nonceCharUUID          = CBUUID(string: "a12be31c-5b38-4773-9b9d-3d5735233a7c")
    public static let encryptedNonceCharUUID = CBUUID(string: "4ebe81f6-b952-465e-9ece-5ca39d4e8955")

    // MARK: - Confirmed Data Channel Characteristic UUIDs
    public static let dataReadCharUUID  = CBUUID(string: "797ae4e9-2e58-4fe8-b48d-b5c79599fb9b")
    public static let dataWriteCharUUID = CBUUID(string: "63e30bad-4206-4596-839f-e47cbf7a4b5d")

    // MARK: - Confirmed Find Device Characteristic UUIDs
    public static let findChar1UUID = CBUUID(string: "4af351bb-d6f7-4612-a8e3-8dce6ca13e7b")
    public static let findChar2UUID = CBUUID(string: "853bd048-b043-4dcd-b073-de49569e1194")
    public static let findChar3UUID = CBUUID(string: "66aeea2f-1edf-445b-bcfb-7ef330268073")

    // MARK: - SAP Transport Characteristic UUID
    public static let sapChannelCharUUID = CBUUID(string: "8ac32d3f-5cb9-4d44-bec2-ee689169f626")

    // MARK: - Published Properties
    @Published public private(set) var authServiceFound: Bool = false
    @Published public private(set) var dataChannelFound: Bool = false
    @Published public private(set) var findDeviceFound: Bool = false
    @Published public private(set) var sapTransportFound: Bool = false
    @Published public private(set) var supportedCipher: String? = nil
    @Published public private(set) var lastNonce: String? = nil
    @Published public private(set) var proprietaryCharacteristics: [String] = []

    public init() {}

    public func configure(peripheral: CBPeripheral, service: CBService) {
        let serviceUUID = service.uuid

        if serviceUUID == Self.authServiceUUID {
            self.authServiceFound = true
            LogStore.shared.log(
                level: .warning,
                category: "ProprietaryProtocol",
                message: "Discovered Samsung Auth Service (EEDD5E73). READ-ONLY mode."
            )
        } else if serviceUUID == Self.dataChannelUUID {
            self.dataChannelFound = true
            LogStore.shared.log(
                level: .info,
                category: "ProprietaryProtocol",
                message: "Discovered Samsung Data Channel (0x1A1A). Requires encryption."
            )
        } else if serviceUUID == Self.findDeviceUUID {
            self.findDeviceFound = true
            LogStore.shared.log(
                level: .info,
                category: "ProprietaryProtocol",
                message: "Discovered Samsung Find Device (0xFD69)."
            )
        } else if serviceUUID == Self.sapTransportUUID {
            self.sapTransportFound = true
            LogStore.shared.log(
                level: .info,
                category: "ProprietaryProtocol",
                message: "Discovered Samsung SAP Transport (1B7E8251)."
            )
        } else {
            return
        }

        if let characteristics = service.characteristics {
            for char in characteristics {
                let uuidStr = char.uuid.uuidString
                if !proprietaryCharacteristics.contains(uuidStr) {
                    proprietaryCharacteristics.append(uuidStr)
                }
                // Only READ if property permits; NEVER write or trigger handshakes
                if char.properties.contains(.read) {
                    peripheral.readValue(for: char)
                }
            }
        }
    }

    public func handleValueUpdate(characteristic: CBCharacteristic) {
        guard let data = characteristic.value else { return }
        let hexString = data.map { String(format: "%02X", $0) }.joined(separator: " ")

        if characteristic.uuid == Self.cipherCharUUID {
            let cipherText = String(data: data, encoding: .utf8) ?? hexString
            self.supportedCipher = cipherText
            LogStore.shared.log(
                level: .info,
                category: "ProprietaryProtocol",
                message: "Cipher: \(cipherText)",
                rawData: data
            )
        } else if characteristic.uuid == Self.nonceCharUUID {
            self.lastNonce = hexString
            LogStore.shared.log(
                level: .info,
                category: "ProprietaryProtocol",
                message: "Nonce (16 bytes): \(hexString)",
                rawData: data
            )
        } else {
            LogStore.shared.log(
                level: .info,
                category: "ProprietaryProtocol",
                message: "Proprietary Char \(characteristic.uuid.uuidString): \(hexString)",
                rawData: data
            )
        }
    }

    public func reset() {
        self.authServiceFound = false
        self.dataChannelFound = false
        self.findDeviceFound = false
        self.sapTransportFound = false
        self.supportedCipher = nil
        self.lastNonce = nil
        self.proprietaryCharacteristics.removeAll()
    }
}
