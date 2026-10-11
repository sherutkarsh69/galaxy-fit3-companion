import Foundation

public struct HeartRateSample: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public let bpm: Int
    public let sensorContact: Bool
    public let energyExpended: Int?
    public let rrIntervals: [Double]?
    public let timestamp: Date
    public let source: String

    public init(
        id: UUID = UUID(),
        bpm: Int,
        sensorContact: Bool,
        energyExpended: Int? = nil,
        rrIntervals: [Double]? = nil,
        timestamp: Date = Date(),
        source: String = "Galaxy Fit3 (SM-R390)"
    ) {
        self.id = id
        self.bpm = bpm
        self.sensorContact = sensorContact
        self.energyExpended = energyExpended
        self.rrIntervals = rrIntervals
        self.timestamp = timestamp
        self.source = source
    }

    /// Parses a standard Bluetooth SIG Heart Rate Measurement (0x2A37) payload.
    /// Byte 0: Flags
    ///   - Bit 0: Heart Rate Value Format (0 = UINT8, 1 = UINT16)
    ///   - Bit 1-2: Sensor Contact Status:
    ///       00: Sensor Contact feature not supported
    ///       01: Sensor Contact feature not supported
    ///       10: Sensor Contact feature supported, contact not detected
    ///       11: Sensor Contact feature supported, contact detected
    ///   - Bit 3: Energy Expended Status (0 = Not Present, 1 = Present as UINT16)
    ///   - Bit 4: RR-Interval Status (0 = Not Present, 1 = One or more UINT16 values present, 1/1024s resolution)
    ///   - Bits 5-7: Reserved for future use
    public init?(from rawData: Data, source: String = "Galaxy Fit3 (SM-R390)", timestamp: Date = Date()) {
        guard rawData.count >= 2 else {
            return nil
        }

        let flags = rawData[0]
        let isHR16Bit = (flags & 0x01) != 0
        let sensorContactSupported = (flags & 0x04) != 0
        let sensorContactDetected = sensorContactSupported ? ((flags & 0x02) != 0) : false

        let hasEnergyExpended = (flags & 0x08) != 0
        let hasRRIntervals = (flags & 0x10) != 0

        var offset = 1

        let parsedBPM: Int
        if isHR16Bit {
            guard rawData.count >= offset + 2 else { return nil }
            let byte1 = UInt16(rawData[offset])
            let byte2 = UInt16(rawData[offset + 1])
            parsedBPM = Int(byte1 | (byte2 << 8))
            offset += 2
        } else {
            parsedBPM = Int(rawData[offset])
            offset += 1
        }

        var parsedEnergy: Int? = nil
        if hasEnergyExpended {
            if rawData.count >= offset + 2 {
                let byte1 = UInt16(rawData[offset])
                let byte2 = UInt16(rawData[offset + 1])
                parsedEnergy = Int(byte1 | (byte2 << 8))
                offset += 2
            }
        }

        var parsedRR: [Double]? = nil
        if hasRRIntervals {
            var rrList: [Double] = []
            while rawData.count >= offset + 2 {
                let byte1 = UInt16(rawData[offset])
                let byte2 = UInt16(rawData[offset + 1])
                let rawRR = UInt16(byte1 | (byte2 << 8))
                // Resolution is 1/1024 seconds, converted to seconds
                let rrSeconds = Double(rawRR) / 1024.0
                rrList.append(rrSeconds)
                offset += 2
            }
            if !rrList.isEmpty {
                parsedRR = rrList
            }
        }

        self.id = UUID()
        self.bpm = parsedBPM
        self.sensorContact = sensorContactDetected
        self.energyExpended = parsedEnergy
        self.rrIntervals = parsedRR
        self.timestamp = timestamp
        self.source = source
    }
}
