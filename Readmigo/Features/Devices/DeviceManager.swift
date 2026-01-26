import Foundation
import SwiftUI
import UIKit

@MainActor
class DeviceManager: ObservableObject {
    static let shared = DeviceManager()

    // MARK: - Published Properties

    @Published var devices: [Device] = []
    @Published var stats: DeviceStats?
    @Published var maxDevices: Int = 2
    @Published var canAddMore: Bool = true
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Current Device

    private(set) var currentDeviceId: String = ""
    private(set) var isCurrentDeviceLoggedOut = false

    // MARK: - Computed Properties

    var currentDevice: Device? {
        devices.first { $0.isCurrent }
    }

    var primaryDevice: Device? {
        devices.first { $0.isPrimary }
    }

    var otherDevices: [Device] {
        devices.filter { !$0.isCurrent }
    }

    var deviceCount: Int {
        devices.count
    }

    var isAtDeviceLimit: Bool {
        deviceCount >= maxDevices
    }

    // MARK: - Initialization

    private init() {
        // Get current device ID
        currentDeviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }

    // MARK: - API Methods

    /// Load all devices for current user
    func loadDevices() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response: DeviceListResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.devices,
                method: .get,
                headers: ["x-device-id": currentDeviceId]
            )

            devices = response.devices
            maxDevices = response.maxDevices
            canAddMore = response.canAddMore
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Load device statistics
    func loadStats() async {
        do {
            stats = try await APIClient.shared.request(
                endpoint: APIEndpoints.devicesStats,
                method: .get
            )
        } catch {
            // Stats are optional, don't show error
        }
    }

    /// Register current device
    func registerCurrentDevice(pushToken: String? = nil) async -> RegisterDeviceResponse? {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let request = RegisterDeviceRequest.current(pushToken: pushToken)
            let response: RegisterDeviceResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.devicesRegister,
                method: .post,
                body: request
            )

            // Update local state
            if response.loginAllowed {
                await loadDevices()
            } else {
                self.error = response.message
            }

            return response
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    /// Update device information
    func updateDevice(_ deviceId: String, request: UpdateDeviceRequest) async -> Device? {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let updated: Device = try await APIClient.shared.request(
                endpoint: APIEndpoints.device(deviceId),
                method: .put,
                body: request
            )

            // Refresh device list
            await loadDevices()
            return updated
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    /// Rename a device
    func renameDevice(_ deviceId: String, name: String) async -> Bool {
        let request = UpdateDeviceRequest(deviceName: name)
        return await updateDevice(deviceId, request: request) != nil
    }

    /// Set a device as primary
    func setPrimaryDevice(_ deviceId: String) async -> Bool {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let _: Device = try await APIClient.shared.request(
                endpoint: APIEndpoints.devicePrimary(deviceId),
                method: .post
            )

            await loadDevices()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    /// Logout a specific device
    func logoutDevice(_ deviceId: String) async -> Bool {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response: DeviceLogoutResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.deviceLogout(deviceId),
                method: .post
            )

            if response.success {
                await loadDevices()
            }
            return response.success
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    /// Logout all other devices
    func logoutOtherDevices() async -> Bool {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response: DeviceLogoutResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.devicesLogoutOthers,
                method: .post,
                headers: ["x-device-id": currentDeviceId]
            )

            if response.success {
                await loadDevices()
            }
            return response.success
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    /// Remove a device completely
    func removeDevice(_ deviceId: String) async -> Bool {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response: DeviceLogoutResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.device(deviceId),
                method: .delete
            )

            if response.success {
                await loadDevices()
            }
            return response.success
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    /// Check if current device has been logged out remotely
    func checkIfLoggedOut() async -> Bool {
        do {
            let response: CheckLogoutResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.devicesCheckLogout,
                method: .get,
                headers: ["x-device-id": currentDeviceId]
            )

            isCurrentDeviceLoggedOut = response.isLoggedOut
            return response.isLoggedOut
        } catch {
            return false
        }
    }

    /// Update push token for current device
    func updatePushToken(_ token: String) async {
        let request = UpdateDeviceRequest(pushToken: token)
        _ = await updateDevice(currentDeviceId, request: request)
    }
}
