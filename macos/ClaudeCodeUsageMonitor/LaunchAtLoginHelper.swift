import Foundation
import ServiceManagement

public class LaunchAtLoginHelper {
    public static func isEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            if SMAppService.mainApp.status == .enabled {
                return true
            }
        }
        
        let script = "tell application \"System Events\" to get name of every login item"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            let result = appleScript.executeAndReturnError(&error)
            let count = result.numberOfItems
            if count > 0 {
                for i in 1...count {
                    if let name = result.atIndex(i)?.stringValue, name == "Claude Code Usage Monitor" {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    public static func setEnabled(_ enable: Bool) {
        if enable {
            var registeredViaSM = false
            if #available(macOS 13.0, *) {
                do {
                    try SMAppService.mainApp.register()
                    registeredViaSM = true
                } catch {
                    registeredViaSM = false
                }
            }
            if !registeredViaSM {
                let appPath = Bundle.main.bundlePath
                let script = """
                tell application "System Events"
                    if not (exists (login item "Claude Code Usage Monitor")) then
                        make login item at end with properties {path:"\(appPath)", hidden:false, name:"Claude Code Usage Monitor"}
                    end if
                end tell
                """
                if let appleScript = NSAppleScript(source: script) {
                    var error: NSDictionary?
                    appleScript.executeAndReturnError(&error)
                }
            }
        } else {
            if #available(macOS 13.0, *) {
                try? SMAppService.mainApp.unregister()
            }
            let script = """
            tell application "System Events"
                if exists (login item "Claude Code Usage Monitor") then
                    delete login item "Claude Code Usage Monitor"
                end if
            end tell
            """
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
            }
        }
    }
}
