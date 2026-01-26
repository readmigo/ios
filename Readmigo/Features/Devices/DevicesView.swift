import SwiftUI

struct DevicesView: View {
    @StateObject private var manager = DeviceManager.shared
    @State private var showingLogoutAllAlert = false
    @State private var showingLogoutDeviceAlert = false
    @State private var showingRemoveDeviceAlert = false
    @State private var showingRenameSheet = false
    @State private var selectedDevice: Device?
    @State private var newDeviceName = ""

    var body: some View {
        List {
            // Header section with device count
            Section {
                deviceCountHeader
            }

            // Current device
            if let current = manager.currentDevice {
                Section {
                    DeviceRow(device: current, isCurrent: true)
                        .swipeActions(edge: .trailing) {
                            Button {
                                selectedDevice = current
                                newDeviceName = current.deviceName ?? current.deviceModel ?? ""
                                showingRenameSheet = true
                            } label: {
                                Label("device.rename".localized, systemImage: "pencil")
                            }
                            .tint(.blue)

                            if !current.isPrimary {
                                Button {
                                    Task {
                                        await manager.setPrimaryDevice(current.deviceId)
                                    }
                                } label: {
                                    Label("device.setPrimary".localized, systemImage: "star")
                                }
                                .tint(.orange)
                            }
                        }
                } header: {
                    Text("device.thisDevice".localized)
                } footer: {
                    if current.isPrimary {
                        Text("device.primaryDevice".localized)
                    }
                }
            }

            // Other devices
            if !manager.otherDevices.isEmpty {
                Section {
                    ForEach(manager.otherDevices) { device in
                        DeviceRow(device: device, isCurrent: false)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    selectedDevice = device
                                    showingLogoutDeviceAlert = true
                                } label: {
                                    Label("device.logout".localized, systemImage: "rectangle.portrait.and.arrow.right")
                                }

                                Button(role: .destructive) {
                                    selectedDevice = device
                                    showingRemoveDeviceAlert = true
                                } label: {
                                    Label("device.remove".localized, systemImage: "trash")
                                }
                                .tint(.red)
                            }
                            .swipeActions(edge: .leading) {
                                if !device.isPrimary {
                                    Button {
                                        Task {
                                            await manager.setPrimaryDevice(device.deviceId)
                                        }
                                    } label: {
                                        Label("device.setPrimary".localized, systemImage: "star")
                                    }
                                    .tint(.orange)
                                }
                            }
                    }
                } header: {
                    Text("device.otherDevices".localized)
                } footer: {
                    if manager.otherDevices.count > 0 {
                        Text("device.swipeHint".localized)
                    }
                }
            }

            // Logout all section
            if manager.otherDevices.count > 0 {
                Section {
                    Button(role: .destructive) {
                        showingLogoutAllAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                            Text("device.logoutAllOther".localized)
                        }
                    }
                } footer: {
                    Text("device.logoutAllOtherHint".localized)
                }
            }
        }
        .navigationTitle("device.title".localized)
        .refreshable {
            await manager.loadDevices()
        }
        .overlay {
            if manager.isLoading && manager.devices.isEmpty {
                ProgressView()
            }
        }
        .alert("device.logoutAllTitle".localized, isPresented: $showingLogoutAllAlert) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("device.logoutAll".localized, role: .destructive) {
                Task {
                    await manager.logoutOtherDevices()
                }
            }
        } message: {
            Text("device.logoutAllMessage".localized)
        }
        .alert("device.logoutDeviceTitle".localized, isPresented: $showingLogoutDeviceAlert) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("device.logout".localized, role: .destructive) {
                if let device = selectedDevice {
                    Task {
                        await manager.logoutDevice(device.deviceId)
                    }
                }
            }
        } message: {
            if let device = selectedDevice {
                Text("device.logoutDeviceMessage".localized(with: device.displayName))
            }
        }
        .alert("device.removeTitle".localized, isPresented: $showingRemoveDeviceAlert) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("device.remove".localized, role: .destructive) {
                if let device = selectedDevice {
                    Task {
                        await manager.removeDevice(device.deviceId)
                    }
                }
            }
        } message: {
            if let device = selectedDevice {
                Text("device.removeMessage".localized(with: device.displayName))
            }
        }
        .sheet(isPresented: $showingRenameSheet) {
            RenameDeviceSheet(
                deviceName: $newDeviceName,
                isPresented: $showingRenameSheet
            ) {
                if let device = selectedDevice {
                    Task {
                        await manager.renameDevice(device.deviceId, name: newDeviceName)
                    }
                }
            }
        }
        .task {
            await manager.loadDevices()
        }
    }

    private var deviceCountHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(manager.deviceCount)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))

                    Text("device.ofMaxDevices".localized(with: manager.maxDevices))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Device limit indicator
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 8)

                    Circle()
                        .trim(from: 0, to: CGFloat(manager.deviceCount) / CGFloat(manager.maxDevices))
                        .stroke(
                            manager.isAtDeviceLimit ? Color.orange : Color.accentColor,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    Image(systemName: "laptopcomputer.and.iphone")
                        .font(.title2)
                        .foregroundStyle(manager.isAtDeviceLimit ? .orange : .accentColor)
                }
                .frame(width: 80, height: 80)
            }

            if manager.isAtDeviceLimit {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("device.limitReached".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Device Row

struct DeviceRow: View {
    let device: Device
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Device icon
            ZStack {
                Circle()
                    .fill(isCurrent ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: deviceIcon)
                    .font(.title3)
                    .foregroundStyle(isCurrent ? .accentColor : .secondary)
            }

            // Device info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(device.displayName)
                        .font(.headline)

                    if device.isPrimary {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if isCurrent {
                        Text("device.thisDeviceBadge".localized)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundStyle(.accentColor)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 8) {
                    if let version = device.osVersion {
                        Text(version)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !isCurrent {
                        Text("•")
                            .foregroundStyle(.secondary)

                        if device.isActiveNow {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 6, height: 6)
                                Text("device.activeNow".localized)
                            }
                            .font(.caption)
                            .foregroundStyle(.green)
                        } else {
                            Text(device.lastActiveFormatted)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // Platform icon
            Image(systemName: device.platform.icon)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var deviceIcon: String {
        switch device.platform {
        case .ios:
            if let model = device.deviceModel?.lowercased() {
                if model.contains("ipad") {
                    return "ipad"
                }
            }
            return "iphone"
        case .android:
            return "smartphone"
        case .web:
            return "globe"
        }
    }
}

// MARK: - Rename Device Sheet

struct RenameDeviceSheet: View {
    @Binding var deviceName: String
    @Binding var isPresented: Bool
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("device.namePlaceholder".localized, text: $deviceName)
                        .textInputAutocapitalization(.words)
                } footer: {
                    Text("device.renameHint".localized)
                }
            }
            .navigationTitle("device.renameTitle".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save".localized) {
                        onSave()
                        isPresented = false
                    }
                    .disabled(deviceName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.height(200)])
    }
}
