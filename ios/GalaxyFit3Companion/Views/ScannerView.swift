import SwiftUI

public struct ScannerView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @State private var pulseAnimation: Bool = false

    public init(bluetoothManager: BluetoothManager) {
        self.bluetoothManager = bluetoothManager
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                // Background dark styling
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.07, blue: 0.12), Color(red: 0.02, green: 0.03, blue: 0.06)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Header radar animation area
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(Color(red: 0.0, green: 0.83, blue: 1.0).opacity(0.15), lineWidth: 2)
                                .frame(width: 140, height: 140)
                                .scaleEffect(pulseAnimation ? 1.3 : 0.8)
                                .opacity(pulseAnimation ? 0.0 : 0.6)

                            Circle()
                                .stroke(Color(red: 0.0, green: 0.83, blue: 1.0).opacity(0.3), lineWidth: 2)
                                .frame(width: 100, height: 100)
                                .scaleEffect(pulseAnimation ? 1.2 : 0.9)
                                .opacity(pulseAnimation ? 0.2 : 0.8)

                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [Color(red: 0.0, green: 0.83, blue: 1.0), Color(red: 0.0, green: 0.45, blue: 0.8)],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 36
                                    )
                                )
                                .frame(width: 68, height: 68)
                                .shadow(color: Color(red: 0.0, green: 0.83, blue: 1.0).opacity(0.4), radius: 12)

                            Image(systemName: "applewatch.radiowaves.left.and.right")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 16)

                        VStack(spacing: 6) {
                            Text(bluetoothManager.isScanning ? "Scanning for Galaxy Fit3..." : "Device Discovery")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)

                            Text("Keep your Samsung Galaxy Fit3 nearby and awake")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Discovered Devices List
                    if bluetoothManager.discoveredDevices.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary.opacity(0.6))

                            Text("No devices found yet")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)

                            if !bluetoothManager.isScanning {
                                Button(action: {
                                    bluetoothManager.startScanning()
                                }) {
                                    Label("Start Scanning", systemImage: "arrow.clockwise")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(Color(red: 0.0, green: 0.83, blue: 1.0))
                                        .clipShape(Capsule())
                                }
                            }
                            Spacer()
                        }
                    } else {
                        List {
                            ForEach(bluetoothManager.discoveredDevices) { device in
                                Button(action: {
                                    bluetoothManager.connect(to: device)
                                }) {
                                    HStack(spacing: 16) {
                                        ZStack {
                                            Circle()
                                                .fill(device.isGalaxyFit3 ? Color(red: 0.0, green: 0.83, blue: 1.0).opacity(0.2) : Color.white.opacity(0.08))
                                                .frame(width: 44, height: 44)

                                            Image(systemName: device.isGalaxyFit3 ? "applewatch" : "dot.radiowaves.left.and.right")
                                                .foregroundColor(device.isGalaxyFit3 ? Color(red: 0.0, green: 0.83, blue: 1.0) : .secondary)
                                        }

                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 8) {
                                                Text(device.displayName)
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(.white)

                                                if device.isGalaxyFit3 {
                                                    Text("Fit3")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundColor(.black)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(Color(red: 0.0, green: 0.83, blue: 1.0))
                                                        .clipShape(Capsule())
                                                }
                                            }

                                            Text("UUID: \(device.id.uuidString.prefix(8))...")
                                                .font(.system(size: 12, design: .monospaced))
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 6) {
                                            SignalStrengthView(rssi: device.rssi)
                                            Text("\(device.rssi) dBm")
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundColor(.secondary)
                                        }

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.secondary.opacity(0.6))
                                    }
                                    .padding(.vertical, 8)
                                }
                                .listRowBackground(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color(red: 0.10, green: 0.12, blue: 0.18).opacity(0.8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(device.isGalaxyFit3 ? Color(red: 0.0, green: 0.83, blue: 1.0).opacity(0.3) : Color.white.opacity(0.05), lineWidth: 1)
                                        )
                                        .padding(.vertical, 4)
                                )
                                .listRowSeparator(.hidden)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }

                    // Bottom controls
                    HStack(spacing: 16) {
                        Button(action: {
                            if bluetoothManager.isScanning {
                                bluetoothManager.stopScanning()
                            } else {
                                bluetoothManager.startScanning()
                            }
                        }) {
                            HStack {
                                Image(systemName: bluetoothManager.isScanning ? "stop.fill" : "arrow.clockwise")
                                Text(bluetoothManager.isScanning ? "Stop Scanning" : "Scan Again")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                bluetoothManager.isScanning
                                ? Color.red.opacity(0.8)
                                : Color(red: 0.0, green: 0.83, blue: 1.0)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("Find Your Fit3")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(red: 0.05, green: 0.07, blue: 0.12), for: .navigationBar)
            .onAppear {
                pulseAnimation = true
                if !bluetoothManager.isScanning {
                    bluetoothManager.startScanning()
                }
            }
        }
    }
}
