import XCTest
@testable import GalaxyFit3Companion

final class HeartRateParserTests: XCTestCase {

    /// Standard 8-bit HR (flags=0x06: 8-bit, sensor contact supported & detected, no energy, no RR), BPM=72
    func testStandard8BitHRMeasurement() {
        // Flags: 0x06 = 0000 0110 (Bit0=0 -> 8-bit; Bit1=1, Bit2=1 -> Contact detected)
        let rawData = Data([0x06, 0x48]) // 0x48 = 72 BPM
        let sample = HeartRateSample(from: rawData)

        XCTAssertNotNil(sample)
        XCTAssertEqual(sample?.bpm, 72)
        XCTAssertTrue(sample?.sensorContact == true)
        XCTAssertNil(sample?.energyExpended)
        XCTAssertNil(sample?.rrIntervals)
    }

    /// 16-bit HR format (flags=0x07: 16-bit HR, sensor contact detected)
    func test16BitHRFormat() {
        // Flags: 0x07 = 0000 0111 (Bit0=1 -> 16-bit; Bit1=1, Bit2=1 -> Contact detected)
        // Value: 0x00E6 = 230 BPM (Little Endian: 0xE6, 0x00)
        let rawData = Data([0x07, 0xE6, 0x00])
        let sample = HeartRateSample(from: rawData)

        XCTAssertNotNil(sample)
        XCTAssertEqual(sample?.bpm, 230)
        XCTAssertTrue(sample?.sensorContact == true)
    }

    /// With Energy Expended field (flags=0x0E: 8-bit, contact detected, energy present)
    func testWithEnergyExpendedField() {
        // Flags: 0x0E = 0000 1110 (Bit3=1 -> Energy present)
        // BPM: 80 (0x50)
        // Energy: 1500 kJ (0x05DC -> 0xDC, 0x05)
        let rawData = Data([0x0E, 0x50, 0xDC, 0x05])
        let sample = HeartRateSample(from: rawData)

        XCTAssertNotNil(sample)
        XCTAssertEqual(sample?.bpm, 80)
        XCTAssertEqual(sample?.energyExpended, 1500)
        XCTAssertNil(sample?.rrIntervals)
    }

    /// With RR-Intervals field (flags=0x16: 8-bit, contact detected, RR present)
    func testWithRRIntervals() {
        // Flags: 0x16 = 0001 0110 (Bit4=1 -> RR present)
        // BPM: 65 (0x41)
        // RR: 1024 (1.0 sec) -> Little Endian 0x00, 0x04
        let rawData = Data([0x16, 0x41, 0x00, 0x04])
        let sample = HeartRateSample(from: rawData)

        XCTAssertNotNil(sample)
        XCTAssertEqual(sample?.bpm, 65)
        XCTAssertNotNil(sample?.rrIntervals)
        XCTAssertEqual(sample?.rrIntervals?.count, 1)
        XCTAssertEqual(sample?.rrIntervals?.first, 1.0)
    }

    /// With All Optional Fields Present (16-bit, contact detected, energy, multiple RR)
    func testWithAllOptionalFieldsPresent() {
        // Flags: 0x1F = 0001 1111 (Bit0=1 16-bit, Bit1-2=11 contact, Bit3=1 energy, Bit4=1 RR)
        // BPM: 120 (0x0078 -> 0x78, 0x00)
        // Energy: 250 (0x00FA -> 0xFA, 0x00)
        // RR1: 819 (0.8s) -> 0x0333 -> 0x33, 0x03
        // RR2: 1024 (1.0s) -> 0x0400 -> 0x00, 0x04
        let rawData = Data([0x1F, 0x78, 0x00, 0xFA, 0x00, 0x33, 0x03, 0x00, 0x04])
        let sample = HeartRateSample(from: rawData)

        XCTAssertNotNil(sample)
        XCTAssertEqual(sample?.bpm, 120)
        XCTAssertEqual(sample?.energyExpended, 250)
        XCTAssertEqual(sample?.rrIntervals?.count, 2)
        XCTAssertEqual(sample?.rrIntervals?[1], 1.0)
    }

    /// Empty data should fail gracefully and return nil
    func testEmptyDataFailsGracefully() {
        let rawData = Data()
        let sample = HeartRateSample(from: rawData)
        XCTAssertNil(sample)
    }

    /// Single byte should fail gracefully (missing HR measurement byte)
    func testSingleByteFailsGracefully() {
        let rawData = Data([0x06])
        let sample = HeartRateSample(from: rawData)
        XCTAssertNil(sample)
    }

    /// Maximum BPM values (255 for 8-bit, 65535 for 16-bit)
    func testMaxBPMValues() {
        let max8BitData = Data([0x00, 0xFF]) // 255 BPM
        let sample8 = HeartRateSample(from: max8BitData)
        XCTAssertEqual(sample8?.bpm, 255)

        let max16BitData = Data([0x01, 0xFF, 0xFF]) // 65535 BPM
        let sample16 = HeartRateSample(from: max16BitData)
        XCTAssertEqual(sample16?.bpm, 65535)
    }

    /// Zero BPM valid edge case
    func testZeroBPMEdgeCase() {
        let rawData = Data([0x00, 0x00])
        let sample = HeartRateSample(from: rawData)
        XCTAssertNotNil(sample)
        XCTAssertEqual(sample?.bpm, 0)
    }

    /// Sensor contact variations (bits 1 & 2)
    func testSensorContactFlagVariations() {
        // Flags 0x04: Contact supported, NOT detected (bit2=1, bit1=0)
        let noContactData = Data([0x04, 0x4B])
        let sampleNoContact = HeartRateSample(from: noContactData)
        XCTAssertEqual(sampleNoContact?.sensorContact, false)

        // Flags 0x06: Contact supported, DETECTED (bit2=1, bit1=1)
        let contactData = Data([0x06, 0x4B])
        let sampleContact = HeartRateSample(from: contactData)
        XCTAssertEqual(sampleContact?.sensorContact, true)

        // Flags 0x00: Contact not supported (bit2=0, bit1=0)
        let unsupportedData = Data([0x00, 0x4B])
        let sampleUnsupported = HeartRateSample(from: unsupportedData)
        XCTAssertEqual(sampleUnsupported?.sensorContact, false)
    }
}
