import Foundation
import CoreBluetooth

public struct KnownGATTLookup {
    public static let services: [String: String] = [
        "1800": "Generic Access",
        "1801": "Generic Attribute",
        "180A": "Device Information",
        "180D": "Heart Rate",
        "180F": "Battery Service",
        "1802": "Immediate Alert",
        "1803": "Link Loss",
        "1804": "Tx Power",
        "1805": "Current Time Service",
        "1806": "Reference Time Update",
        "1808": "Glucose",
        "1809": "Health Thermometer",
        "1812": "Human Interface Device",
        "1814": "Running Speed and Cadence",
        "181A": "Environmental Sensing",
        "181C": "User Data",
        "181D": "Weight Scale",
        "1A1A": "Samsung Control / Security (Proprietary)",
        "FD69": "Samsung Wearable Discovery SCS (Proprietary)",
        "EEDD5E73-6AA8-4673-8219-398A489DA87C": "Samsung Auth / SAP Crypto (Proprietary)",
        "1B7E8251-2877-41C3-B46E-CF057C562023": "Samsung SAP Transport Pipe (Proprietary)"
    ]

    public static let characteristics: [String: String] = [
        "2A00": "Device Name",
        "2A01": "Appearance",
        "2A02": "Peripheral Privacy Flag",
        "2A04": "Peripheral Preferred Connection Parameters",
        "2A05": "Service Changed",
        "2AA6": "Central Address Resolution",
        "2B29": "Client Supported Features",
        "2B3A": "Server Supported Features",
        "2A19": "Battery Level",
        "2A23": "System ID",
        "2A24": "Model Number String",
        "2A25": "Serial Number String",
        "2A26": "Firmware Revision String",
        "2A27": "Hardware Revision String",
        "2A28": "Software Revision String",
        "2A29": "Manufacturer Name String",
        "2A2A": "IEEE 11073-20601 Regulatory Cert.",
        "2A50": "PnP ID",
        "2A37": "Heart Rate Measurement",
        "2A38": "Body Sensor Location",
        "2A39": "Heart Rate Control Point",
        "797AE4E9-2E58-4FE8-B48D-B5C79599FB9B": "Samsung Encrypted Notify Stream",
        "63E30BAD-4206-4596-839F-E47CBF7A4B5D": "Samsung Control Command Point",
        "4AF351BB-D6F7-4612-A8E3-8DCE6CA13E7B": "Samsung Discovery Flag 1",
        "853BD048-B043-4DCD-B073-DE49569E1194": "Samsung Discovery Flag 2",
        "66AEEA2F-1EDF-445B-BCFB-7EF330268073": "Samsung Discovery Flag 3",
        "50F98BFD-158C-4EFA-ADD4-0A70C2F5DF5D": "Samsung Crypto Suite Specifier",
        "A12BE31C-5B38-4773-9B9D-3D5735233A7C": "Samsung Auth Nonce / Challenge",
        "4EBE81F6-B952-465E-9ECE-5CA39D4E8955": "Samsung Auth Response Point",
        "8AC32D3F-5CB9-4D44-BEC2-EE689169F626": "Samsung SAP Bidirectional Transport"
    ]

    public static func resolveServiceName(_ uuid: CBUUID) -> String {
        let key = uuid.uuidString.uppercased()
        return services[key] ?? "Custom Service (\(key))"
    }

    public static func resolveCharacteristicName(_ uuid: CBUUID) -> String {
        let key = uuid.uuidString.uppercased()
        return characteristics[key] ?? "Custom Characteristic (\(key))"
    }
}

@MainActor
public final class GATTServiceManager: ObservableObject {
    @Published public private(set) var discoveredServices: [GATTServiceModel] = []

    public init() {}

    public func reset() {
        discoveredServices.removeAll()
    }

    public func discoverCharacteristics(for service: CBService, on peripheral: CBPeripheral) {
        peripheral.discoverCharacteristics(nil, for: service)
    }

    public func updateServices(from peripheralServices: [CBService]) {
        var updated: [GATTServiceModel] = []
        for svc in peripheralServices {
            let svcName = KnownGATTLookup.resolveServiceName(svc.uuid)
            var charModels: [GATTCharacteristicModel] = []
            if let characteristics = svc.characteristics {
                for char in characteristics {
                    let charName = KnownGATTLookup.resolveCharacteristicName(char.uuid)
                    let props = formatProperties(char.properties)
                    let strVal = formatStringValue(char.value)
                    charModels.append(GATTCharacteristicModel(
                        serviceUUID: svc.uuid,
                        characteristicUUID: char.uuid,
                        serviceName: svcName,
                        characteristicName: charName,
                        properties: props,
                        rawValue: char.value,
                        stringValue: strVal,
                        lastUpdated: char.value != nil ? Date() : nil
                    ))
                }
            }
            updated.append(GATTServiceModel(
                serviceUUID: svc.uuid,
                serviceName: svcName,
                isPrimary: svc.isPrimary,
                characteristics: charModels
            ))
        }
        self.discoveredServices = updated
    }

    public func updateCharacteristicValue(_ characteristic: CBCharacteristic) {
        let svcUUID = characteristic.service?.uuid
        for sIdx in 0..<discoveredServices.count {
            if discoveredServices[sIdx].serviceUUID == svcUUID {
                for cIdx in 0..<discoveredServices[sIdx].characteristics.count {
                    if discoveredServices[sIdx].characteristics[cIdx].characteristicUUID == characteristic.uuid {
                        discoveredServices[sIdx].characteristics[cIdx].rawValue = characteristic.value
                        discoveredServices[sIdx].characteristics[cIdx].stringValue = formatStringValue(characteristic.value)
                        discoveredServices[sIdx].characteristics[cIdx].lastUpdated = Date()
                        return
                    }
                }
            }
        }
    }

    public func readAllReadableCharacteristics(peripheral: CBPeripheral) {
        guard let services = peripheral.services else { return }
        for svc in services {
            guard let characteristics = svc.characteristics else { continue }
            for char in characteristics {
                if char.properties.contains(.read) {
                    peripheral.readValue(for: char)
                }
            }
        }
    }

    private func formatProperties(_ props: CBCharacteristicProperties) -> [String] {
        var list: [String] = []
        if props.contains(.broadcast) { list.append("Broadcast") }
        if props.contains(.read) { list.append("Read") }
        if props.contains(.writeWithoutResponse) { list.append("WriteWithoutResp") }
        if props.contains(.write) { list.append("Write") }
        if props.contains(.notify) { list.append("Notify") }
        if props.contains(.indicate) { list.append("Indicate") }
        if props.contains(.authenticatedSignedWrites) { list.append("SignedWrite") }
        if props.contains(.extendedProperties) { list.append("Extended") }
        return list
    }

    private func formatStringValue(_ data: Data?) -> String? {
        guard let data = data, !data.isEmpty else { return nil }
        if let utf8 = String(data: data, encoding: .utf8), utf8.allSatisfy({ $0.isASCII && !$0.isNewline }) {
            return utf8
        }
        return data.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
