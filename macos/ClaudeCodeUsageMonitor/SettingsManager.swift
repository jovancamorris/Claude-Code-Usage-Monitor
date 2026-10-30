import Foundation
import Combine
import ServiceManagement

@MainActor
public final class SettingsManager: ObservableObject, @unchecked Sendable {
    @Published public var refreshInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval")
        }
    }
    
    @Published public var displayDirection: DisplayDirection {
        didSet {
            UserDefaults.standard.set(displayDirection.rawValue, forKey: "displayDirection")
        }
    }
    
    @Published public var menuBarDisplayMode: MenuBarDisplayMode {
        didSet {
            UserDefaults.standard.set(menuBarDisplayMode.rawValue, forKey: "menuBarDisplayMode")
        }
    }
    
    @Published public var customToken: String {
        didSet {
            UserDefaults.standard.set(customToken, forKey: "customToken")
        }
    }
    
    @Published public var demoMode: Bool {
        didSet {
            UserDefaults.standard.set(demoMode, forKey: "demoMode")
        }
    }
    
    public init() {
        let interval = UserDefaults.standard.double(forKey: "refreshInterval")
        self.refreshInterval = interval > 0 ? interval : 900.0 // Default 15 minutes
        
        let directionStr = UserDefaults.standard.string(forKey: "displayDirection") ?? DisplayDirection.used.rawValue
        self.displayDirection = DisplayDirection(rawValue: directionStr) ?? .used
        
        let modeStr = UserDefaults.standard.string(forKey: "menuBarDisplayMode") ?? MenuBarDisplayMode.full.rawValue
        self.menuBarDisplayMode = MenuBarDisplayMode(rawValue: modeStr) ?? .full
        
        self.customToken = UserDefaults.standard.string(forKey: "customToken") ?? ""
        self.demoMode = UserDefaults.standard.bool(forKey: "demoMode")
    }
}
