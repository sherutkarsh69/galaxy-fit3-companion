import SwiftUI

public struct DeviceDetailView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @State private var showingForgetConfirmation: Bool = false

    public init(bluetoothManager: BluetoothManager) {
        self.bluetoothManager = bluetoothManager
    }

    private var devInfo: DeviceInfoService {
        bluetoothManager.deviceInfoService
    }

    private var proprietary: ProprietaryProtocol {
        bluetoothManager.proprietaryProtocol
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.04, green: 0.05, blue: 0.09)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Device Header Card
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(red: 0.0, green: 0.83, blue: 1.0).opacity(0.15))
                                    .frame(width: 60, height: 60)

                                Image(systemName: "applewatch")
                                    .font(.system(size: 30))
                                    .foregroundColor(Color(red: 0.0, green: 0.83, blue: 1.0))
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(bluetoothManager.connectedDevice?.displayName ?? "Galaxy Fit3")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)

                                Text("Status: \(bluetoothManager.connectionState.statusText)")
                                    .font(.system(size: 13))
                                    .foregroundColor(bluetoothManager.connectionState.statusColor)

                                HStack(spacing: 6) {
                                    SignalStrengthView(rssi: bluetoothManager.rssi)
                                    Text("\(bluetoothManager.rssi) dBm")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(18)
                        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Standard Device Information Card (0x180A)
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label("Device Information (0x180A)", systemImage: "info.circle")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                                if devInfo.isServiceDiscovered {
                                    Text("Verified GATT")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Color(red: 0.30, green: 0.69, blue: 0.31))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(red: 0.30, green: 0.69, blue: 0.31).opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }

                            Divider().background(Color.white.opacity(0.08))

                            infoRow(label: "Manufacturer", value: devInfo.manufacturerName ?? "Samsung Electronics Co., Ltd.")
                            infoRow(label: "Model Number", value: devInfo.modelNumber ?? "SM-R390")
                            infoRow(label: "Firmware Revision", value: devInfo.firmwareRevision ?? "R390XXU0AXA1")
                            infoRow(label: "Hardware Revision", value: devInfo.hardwareRevision ?? "REV0.1")
                            infoRow(label: "Serial Number", value: devInfo.serialNumber ?? "RFXXXXXXXXX")
                            infoRow(label: "Peripheral UUID", value: bluetoothManager.connectedDevice?.id.uuidString ?? "--")
                        }
                        .padding(18)
                        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Proprietary Protocol Status Card (Samsung SAP)
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label("Samsung Auth Service", systemImage: "lock.shield")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("EXPERIMENTAL")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(red: 1.0, green: 0.57, blue: 0.0))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(red: 1.0, green: 0.57, blue: 0.0).opacity(0.15))
                                    .clipShape(Capsule())
                            }

                            Divider().background(Color.white.opacity(0.08))

                            infoRow(label: "UUID", value: "eedd5e73-6aa8-4673-8219-398a489da87c")
                            infoRow(label: "Service Status", value: proprietary.authServiceFound ? "Detected on Device" : "Not Detected / Paired")
                            infoRow(label: "Cipher Support", value: proprietary.supportedCipher ?? "Protected / Key Required")
                            infoRow(label: "Last Nonce", value: proprietary.lastNonce ?? "None")

                            Text("Note: The proprietary Samsung encryption key is not published. For data security, this app only interacts with open Bluetooth SIG standard profiles.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineSpacing(2)
                                .padding(.top, 4)
                        }
                        .padding(18)
                        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Disconnect / Forget Button
                        Button(role: .destructive, action: {
                            showingForgetConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Forget Galaxy Fit3")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(red: 1.0, green: 0.35, blue: 0.35))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(red: 1.0, green: 0.35, blue: 0.35).opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(red: 1.0, green: 0.35, blue: 0.35).opacity(0.3), lineWidth: 1)
                            )
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Device Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(red: 0.04, green: 0.05, blue: 0.09), for: .navigationBar)
            .confirmationDialog("Forget Device?", isPresented: $showingForgetConfirmation, titleVisibility: .visible) {
                Button("Forget Device", role: .destructive) {
                    bluetoothManager.disconnect()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will disconnect and clear automatic reconnection preferences.")
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
        }
    }
}
