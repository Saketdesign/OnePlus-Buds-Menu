import Combine
import ServiceManagement

@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published private(set) var errorMessage: String?

    private(set) var needsSystemApproval = false

    init() {
        isEnabled = false
        refreshStatus()
    }

    var accessibilityStatus: String {
        if let errorMessage {
            return errorMessage
        }

        return isEnabled ? "Enabled" : "Disabled"
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }

            refreshStatus()
        } catch {
            refreshStatus()
            errorMessage = "Could not update launch at login: \(error.localizedDescription)"
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private func refreshStatus() {
        switch SMAppService.mainApp.status {
        case .enabled:
            isEnabled = true
            needsSystemApproval = false
            errorMessage = nil
        case .requiresApproval:
            isEnabled = false
            needsSystemApproval = true
            errorMessage = "Approve OnePlus Buds Menu in Login Items to finish enabling it."
        case .notRegistered:
            isEnabled = false
            needsSystemApproval = false
            errorMessage = nil
        case .notFound:
            isEnabled = false
            needsSystemApproval = false
            errorMessage = "Launch on login is unavailable for this copy of the app."
        @unknown default:
            isEnabled = false
            needsSystemApproval = false
            errorMessage = "Launch on login status is unavailable."
        }
    }
}
