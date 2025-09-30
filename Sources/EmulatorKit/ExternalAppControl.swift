import Foundation
import AppKit
import Combine

/// External App Control API
/// Allows other applications to control the Nintendo Emulator
@MainActor
public class ExternalAppControl: ObservableObject {
    public static let shared = ExternalAppControl()

    // MARK: - Published Properties
    @Published public private(set) var isControlEnabled = true
    @Published public private(set) var connectedApps: Set<String> = []

    // MARK: - Control Interface
    private let notificationCenter = DistributedNotificationCenter.default()
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupExternalControlListeners()
        setupLocalNotificationForwarding()

        // Enable external app control by default
        enableExternalControl()
    }

    // MARK: - Public API

    /// Enable external app control
    public func enableExternalControl() {
        isControlEnabled = true
        NSLog("🔗 External app control enabled")

        // Post notification that control is available
        notificationCenter.postNotificationName(
            NSNotification.Name("com.nintendoemulator.control.available"),
            object: nil,
            userInfo: ["status": "enabled"]
        )
    }

    /// Disable external app control
    public func disableExternalControl() {
        isControlEnabled = false
        connectedApps.removeAll()
        NSLog("🔗 External app control disabled")

        // Post notification that control is no longer available
        notificationCenter.postNotificationName(
            NSNotification.Name("com.nintendoemulator.control.available"),
            object: nil,
            userInfo: ["status": "disabled"]
        )
    }

    /// Get current emulator status for external apps
    public func getEmulatorStatus() -> [String: Any] {
        return [
            "controlEnabled": isControlEnabled,
            "connectedApps": Array(connectedApps),
            "timestamp": Date().timeIntervalSince1970,
            "version": "1.0.0"
        ]
    }

    // MARK: - External Control Listeners

    private func setupExternalControlListeners() {
        // Listen for external app control requests
        notificationCenter.addObserver(
            forName: NSNotification.Name("com.nintendoemulator.control.request"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleExternalControlRequest(notification)
            }
        }

        // Listen for external app connections
        notificationCenter.addObserver(
            forName: NSNotification.Name("com.nintendoemulator.app.connect"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleAppConnection(notification)
            }
        }

        // Listen for external app disconnections
        notificationCenter.addObserver(
            forName: NSNotification.Name("com.nintendoemulator.app.disconnect"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleAppDisconnection(notification)
            }
        }
    }

    private func setupLocalNotificationForwarding() {
        // Forward local notifications to external apps
        let localNotifications = [
            NSNotification.Name("GameStarted"),
            NSNotification.Name("GameStopped"),
            NSNotification.Name("EmulatorStart"),
            NSNotification.Name("EmulatorPause"),
            NSNotification.Name("EmulatorStop")
        ]

        for notificationName in localNotifications {
            NotificationCenter.default.addObserver(
                forName: notificationName,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor in
                    self?.forwardNotificationToExternalApps(notification)
                }
            }
        }
    }

    private func handleExternalControlRequest(_ notification: Notification) {
        guard isControlEnabled else {
            NSLog("🔗 External control request denied - control disabled")
            return
        }

        guard let userInfo = notification.userInfo,
              let command = userInfo["command"] as? String,
              let appID = userInfo["appID"] as? String else {
            NSLog("🔗 Invalid external control request")
            return
        }

        NSLog("🔗 External control request: \(command) from \(appID)")

        // Execute the command
        executeExternalCommand(command, parameters: userInfo, fromApp: appID)
    }

    private func handleAppConnection(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let appID = userInfo["appID"] as? String else { return }

        connectedApps.insert(appID)
        NSLog("🔗 App connected: \(appID)")

        // Send status back to connecting app
        notificationCenter.postNotificationName(
            NSNotification.Name("com.nintendoemulator.status"),
            object: nil,
            userInfo: getEmulatorStatus()
        )
    }

    private func handleAppDisconnection(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let appID = userInfo["appID"] as? String else { return }

        connectedApps.remove(appID)
        NSLog("🔗 App disconnected: \(appID)")
    }

    private func executeExternalCommand(_ command: String, parameters: [AnyHashable: Any], fromApp appID: String) {
        switch command.lowercased() {
        case "start", "play":
            if let romPath = parameters["romPath"] as? String {
                let url = URL(fileURLWithPath: romPath)
                NotificationCenter.default.post(name: NSNotification.Name("EmulatorOpenROM"), object: url)
            } else {
                NotificationCenter.default.post(name: NSNotification.Name("EmulatorStart"), object: nil)
            }

        case "pause":
            NotificationCenter.default.post(name: NSNotification.Name("EmulatorPause"), object: nil)

        case "stop":
            NotificationCenter.default.post(name: NSNotification.Name("EmulatorStop"), object: nil)

        case "stream_start":
            let title = parameters["title"] as? String ?? "External Stream"
            let category = parameters["category"] as? String ?? "Gaming"
            NotificationCenter.default.post(
                name: .startStreaming,
                object: nil,
                userInfo: ["title": title, "category": category]
            )

        case "stream_stop":
            NotificationCenter.default.post(name: .stopStreaming, object: nil)

        case "status":
            // Send current status back to requesting app
            var status = getEmulatorStatus()
            status["requestedBy"] = appID
            notificationCenter.postNotificationName(
                NSNotification.Name("com.nintendoemulator.status.response"),
                object: nil,
                userInfo: status
            )

        default:
            NSLog("🔗 Unknown external command: \(command)")
            notificationCenter.postNotificationName(
                NSNotification.Name("com.nintendoemulator.command.error"),
                object: nil,
                userInfo: [
                    "error": "Unknown command",
                    "command": command,
                    "appID": appID
                ]
            )
        }
    }

    private func forwardNotificationToExternalApps(_ notification: Notification) {
        guard !connectedApps.isEmpty else { return }

        // Convert local notification to external notification
        let externalNotificationName = "com.nintendoemulator.event." + notification.name.rawValue

        var userInfo: [String: Any] = [
            "eventName": notification.name.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ]

        // Add any additional info from the original notification
        if let originalUserInfo = notification.userInfo {
            for (key, value) in originalUserInfo {
                if let stringKey = key as? String {
                    userInfo[stringKey] = value
                }
            }
        }

        // Add object if present and serializable
        if let object = notification.object {
            if let stringObject = object as? String {
                userInfo["object"] = stringObject
            } else if let urlObject = object as? URL {
                userInfo["object"] = urlObject.path
            }
        }

        NSLog("🔗 Forwarding event to \(connectedApps.count) connected apps: \(notification.name.rawValue)")

        notificationCenter.postNotificationName(
            NSNotification.Name(externalNotificationName),
            object: nil,
            userInfo: userInfo
        )
    }
}

// MARK: - External Control Notifications

public extension Notification.Name {
    static let startStreaming = Notification.Name("startStreaming")
    static let stopStreaming = Notification.Name("stopStreaming")
}

// MARK: - External App Control Helper

public struct ExternalControlAPI {

    /// Command structure for external apps to control the emulator
    public struct ControlCommand {
        public let command: String
        public let parameters: [String: Any]
        public let appID: String

        public init(command: String, parameters: [String: Any] = [:], appID: String) {
            self.command = command
            self.parameters = parameters
            self.appID = appID
        }

        /// Send this command to Nintendo Emulator
        public func send() {
            let notificationCenter = DistributedNotificationCenter.default()

            var userInfo = parameters
            userInfo["command"] = command
            userInfo["appID"] = appID

            notificationCenter.postNotificationName(
                NSNotification.Name("com.nintendoemulator.control.request"),
                object: nil,
                userInfo: userInfo
            )
        }
    }

    /// Connect to Nintendo Emulator for external control
    public static func connect(appID: String) {
        let notificationCenter = DistributedNotificationCenter.default()

        notificationCenter.postNotificationName(
            NSNotification.Name("com.nintendoemulator.app.connect"),
            object: nil,
            userInfo: ["appID": appID]
        )
    }

    /// Disconnect from Nintendo Emulator
    public static func disconnect(appID: String) {
        let notificationCenter = DistributedNotificationCenter.default()

        notificationCenter.postNotificationName(
            NSNotification.Name("com.nintendoemulator.app.disconnect"),
            object: nil,
            userInfo: ["appID": appID]
        )
    }

    /// Request current status from Nintendo Emulator
    public static func requestStatus(appID: String) {
        let command = ControlCommand(command: "status", appID: appID)
        command.send()
    }
}
