import Foundation

public struct ClaudeCredential: Sendable {
    public let token: String
    public let source: String
    public let expiresAt: Date?
}

public class CredentialManager {
    public static func getCredential(customToken: String = "") -> ClaudeCredential? {
        // 1. Check custom user token
        let trimmedCustom = customToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCustom.isEmpty {
            return ClaudeCredential(token: trimmedCustom, source: "Manual Custom Token", expiresAt: nil)
        }
        
        // 2. Check macOS Keychain
        if let keychainCred = getFromKeychain() {
            return keychainCred
        }
        
        // 3. Check File Storage
        if let fileCred = getFromFile() {
            return fileCred
        }
        
        return nil
    }
    
    private static func getFromKeychain() -> ClaudeCredential? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let rawOutput = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !rawOutput.isEmpty {
                    return parseCredentialString(rawOutput, source: "macOS Keychain")
                }
            }
        } catch {
            // Keychain lookup failed
        }
        return nil
    }
    
    private static func getFromFile() -> ClaudeCredential? {
        let fileManager = FileManager.default
        let homeDir = fileManager.homeDirectoryForCurrentUser
        
        var candidatePaths: [URL] = []
        
        // Environment variable override
        if let customDir = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"], !customDir.isEmpty {
            candidatePaths.append(URL(fileURLWithPath: customDir).appendingPathComponent(".credentials.json"))
            candidatePaths.append(URL(fileURLWithPath: customDir).appendingPathComponent("credentials.json"))
        }
        
        // Default standard locations
        candidatePaths.append(homeDir.appendingPathComponent(".claude/.credentials.json"))
        candidatePaths.append(homeDir.appendingPathComponent(".claude/credentials.json"))
        candidatePaths.append(homeDir.appendingPathComponent(".claude.json"))
        candidatePaths.append(homeDir.appendingPathComponent("Library/Application Support/Claude/credentials.json"))
        
        for url in candidatePaths {
            if fileManager.fileExists(atPath: url.path),
               let data = try? Data(contentsOf: url),
               let content = String(data: data, encoding: .utf8) {
                if let cred = parseCredentialString(content, source: url.path) {
                    return cred
                }
            }
        }
        
        return nil
    }
    
    private static func parseCredentialString(_ raw: String, source: String) -> ClaudeCredential? {
        // Check if raw string is already a direct sk-ant token
        if raw.starts(with: "sk-ant-") {
            return ClaudeCredential(token: raw, source: source, expiresAt: nil)
        }
        
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        // Check claudeAiOauth block
        if let oauth = json["claudeAiOauth"] as? [String: Any] {
            if let token = (oauth["accessToken"] as? String) ?? (oauth["access_token"] as? String) {
                var expDate: Date? = nil
                if let expMs = oauth["expiresAt"] as? Double {
                    expDate = Date(timeIntervalSince1970: expMs / 1000.0)
                }
                return ClaudeCredential(token: token, source: source, expiresAt: expDate)
            }
        }
        
        // Check top-level token fields
        if let token = (json["accessToken"] as? String) ?? (json["access_token"] as? String) {
            return ClaudeCredential(token: token, source: source, expiresAt: nil)
        }
        
        return nil
    }
}
