import SwiftUI

public struct DiagnosticsView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var logStore = LogStore.shared

    @State private var selectedLevel: DiagnosticLevel? = nil
    @State private var searchQuery: String = ""
    @State private var showingExportSheet: Bool = false
    @State private var exportedDataString: String = ""

    public init(bluetoothManager: BluetoothManager) {
        self.bluetoothManager = bluetoothManager
    }

    private var filteredLogs: [DiagnosticLog] {
        logStore.logs.filter { log in
            let matchesLevel = (selectedLevel == nil || log.level == selectedLevel)
            let matchesQuery = searchQuery.isEmpty
                || log.message.localizedCaseInsensitiveContains(searchQuery)
                || log.category.localizedCaseInsensitiveContains(searchQuery)
            return matchesLevel && matchesQuery
        }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.04, green: 0.05, blue: 0.09)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Section 1: GATT Tree Explorer
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label("Discovered GATT Tree", systemImage: "network")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(bluetoothManager.gattServiceManager.discoveredServices.count) Services")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }

                            if bluetoothManager.gattServiceManager.discoveredServices.isEmpty {
                                HStack {
                                    Spacer()
                                    Text("Connect a device to inspect live GATT profile")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                        .padding(.vertical, 16)
                                    Spacer()
                                }
                            } else {
                                ForEach(bluetoothManager.gattServiceManager.discoveredServices) { svc in
                                    DisclosureGroup {
                                        VStack(alignment: .leading, spacing: 10) {
                                            ForEach(svc.characteristics) { char in
                                                VStack(alignment: .leading, spacing: 4) {
                                                    HStack {
                                                        Text(char.characteristicName)
                                                            .font(.system(size: 13, weight: .semibold))
                                                            .foregroundColor(.white)
                                                        Spacer()
                                                        Text("0x\(char.characteristicUUID.uuidString)")
                                                            .font(.system(size: 11, design: .monospaced))
                                                            .foregroundColor(Color(red: 0.0, green: 0.83, blue: 1.0))
                                                    }

                                                    HStack {
                                                        Text("Props: \(char.properties.joined(separator: ", "))")
                                                            .font(.system(size: 11))
                                                            .foregroundColor(.secondary)
                                                        Spacer()
                                                    }

                                                    if let raw = char.rawValue {
                                                        Text("Value: \(char.hexString)")
                                                            .font(.system(size: 11, design: .monospaced))
                                                            .foregroundColor(.green)
                                                            .lineLimit(2)
                                                    }
                                                }
                                                .padding(10)
                                                .background(Color.white.opacity(0.04))
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            }
                                        }
                                        .padding(.top, 8)
                                    } label: {
                                        HStack {
                                            Image(systemName: "folder.fill")
                                                .foregroundColor(Color(red: 0.0, green: 0.83, blue: 1.0))
                                            Text(svc.serviceName)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.white)
                                            Spacer()
                                            Text("0x\(svc.serviceUUID.uuidString)")
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(12)
                                    .background(Color.white.opacity(0.03))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                        .padding(18)
                        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Section 2: Real-time BLE Event Logs
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label("BLE Diagnostics Log", systemImage: "terminal.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Button(action: {
                                    logStore.clear()
                                }) {
                                    Text("Clear")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }

                            // Filter Chips
                            HStack(spacing: 8) {
                                filterChip(title: "ALL", level: nil)
                                filterChip(title: "INFO", level: .info)
                                filterChip(title: "WARN", level: .warning)
                                filterChip(title: "ERR", level: .error)
                                Spacer()
                            }

                            // Search bar
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                TextField("Search log messages...", text: $searchQuery)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white)
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            // Log items
                            if filteredLogs.isEmpty {
                                HStack {
                                    Spacer()
                                    Text("No log records")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                        .padding(.vertical, 20)
                                    Spacer()
                                }
                            } else {
                                LazyVStack(spacing: 8) {
                                    ForEach(filteredLogs.prefix(100)) { log in
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(log.level.rawValue)
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(.black)
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 2)
                                                    .background(log.level.color)
                                                    .clipShape(Capsule())

                                                Text(log.category)
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundColor(Color(red: 0.0, green: 0.83, blue: 1.0))

                                                Spacer()

                                                Text(log.timestamp.formatted(date: .omitted, time: .standard))
                                                    .font(.system(size: 10, design: .monospaced))
                                                    .foregroundColor(.secondary)
                                            }

                                            Text(log.message)
                                                .font(.system(size: 12))
                                                .foregroundColor(.white)

                                            if let raw = log.rawData {
                                                Text("HEX: \(raw)")
                                                    .font(.system(size: 10, design: .monospaced))
                                                    .foregroundColor(Color(red: 0.30, green: 0.69, blue: 0.31))
                                            }
                                        }
                                        .padding(10)
                                        .background(Color.white.opacity(0.03))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }

                            // Export Button
                            Button(action: {
                                exportedDataString = logStore.exportJSON()
                                showingExportSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Export Diagnostics (JSON)")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .padding(18)
                        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(red: 0.04, green: 0.05, blue: 0.09), for: .navigationBar)
            .sheet(isPresented: $showingExportSheet) {
                ShareSheet(activityItems: [exportedDataString])
            }
        }
    }

    private func filterChip(title: String, level: DiagnosticLevel?) -> some View {
        Button(action: {
            selectedLevel = level
        }) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(selectedLevel == level ? .black : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(selectedLevel == level ? Color.white : Color.white.opacity(0.08))
                .clipShape(Capsule())
        }
    }
}

public struct ShareSheet: UIViewControllerRepresentable {
    public var activityItems: [Any]
    public var applicationActivities: [UIActivity]? = nil

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
