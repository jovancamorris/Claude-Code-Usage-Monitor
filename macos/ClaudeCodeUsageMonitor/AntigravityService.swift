import Foundation

public struct AntigravityCredentials {
    public var accessToken: String
    public var refreshToken: String?
    public var expiry: Date?
    public var source: String
}

public class AntigravityService {
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    
    private static let fallbackIsoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    
    private static let userAgent = "antigravity/cli/1.4.0"
    
    public static func getCredentials() -> AntigravityCredentials? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let tokenFile = home.appendingPathComponent(".gemini/jetski-standalone-oauth-token")
        
        guard FileManager.default.fileExists(atPath: tokenFile.path),
              let data = try? Data(contentsOf: tokenFile),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokenDict = json["token"] as? [String: Any],
              let accessToken = tokenDict["access_token"] as? String else {
            return nil
        }
        
        let refreshToken = tokenDict["refresh_token"] as? String
        var expiryDate: Date? = nil
        if let expiryStr = tokenDict["expiry"] as? String {
            expiryDate = isoFormatter.date(from: expiryStr) ?? fallbackIsoFormatter.date(from: expiryStr)
        }
        
        return AntigravityCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiry: expiryDate,
            source: "~/.gemini/jetski-standalone-oauth-token"
        )
    }
    
    public static func getFreshAccessToken(creds: inout AntigravityCredentials) async throws -> String {
        let now = Date()
        // If token expires in less than 60 seconds, refresh it
        if let exp = creds.expiry, exp.timeIntervalSince(now) <= 60, let refreshToken = creds.refreshToken {
            return try await refreshAccessToken(refreshToken: refreshToken)
        }
        return creds.accessToken
    }
    
    public static func refreshAccessToken(refreshToken: String) async throws -> String {
        let clients = extractOAuthClientsFromInstalledBinary()
        if clients.isEmpty {
            throw NSError(domain: "AntigravityOAuth", code: 404, userInfo: [NSLocalizedDescriptionKey: "Could not find local Antigravity binary to resolve OAuth client."])
        }
        
        for (clientId, clientSecret) in clients {
            let url = URL(string: "https://oauth2.googleapis.com/token")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            let bodyParams = [
                "client_id": clientId,
                "client_secret": clientSecret,
                "refresh_token": refreshToken,
                "grant_type": "refresh_token"
            ]
            req.httpBody = bodyParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)
            
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let newToken = json["access_token"] as? String {
                    return newToken
                }
            } catch {
                continue
            }
        }
        
        throw NSError(domain: "AntigravityOAuth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Failed to refresh Google OAuth token with available client credentials."])
    }
    
    private static func extractOAuthClientsFromInstalledBinary() -> [(String, String)] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidatePaths = [
            home.appendingPathComponent(".gemini/bin/agy"),
            home.appendingPathComponent(".gemini/antigravity/bin/language_server"),
            home.appendingPathComponent(".gemini/antigravity-ide/resources/bin/language_server")
        ]
        
        for url in candidatePaths {
            guard FileManager.default.fileExists(atPath: url.path),
                  let data = try? Data(contentsOf: url) else {
                continue
            }
            
            let text = String(decoding: data, as: UTF8.self)
            guard let cidRegex = try? NSRegularExpression(pattern: "[0-9]+-[a-z0-9]+\\.apps\\.googleusercontent\\.com"),
                  let secretRegex = try? NSRegularExpression(pattern: "GOCSPX-[A-Za-z0-9_-]{28}") else {
                continue
            }
            
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            let cidMatches = cidRegex.matches(in: text, range: nsRange)
            let secretMatches = secretRegex.matches(in: text, range: nsRange)
            
            var cids: [String] = []
            for m in cidMatches {
                if let r = Range(m.range, in: text) {
                    let s = String(text[r])
                    if !cids.contains(s) { cids.append(s) }
                }
            }
            
            var secrets: [String] = []
            for m in secretMatches {
                if let r = Range(m.range, in: text) {
                    let s = String(text[r])
                    if !secrets.contains(s) { secrets.append(s) }
                }
            }
            
            if !cids.isEmpty && !secrets.isEmpty {
                var pairs: [(String, String)] = []
                for cid in cids {
                    for sec in secrets {
                        pairs.append((cid, sec))
                    }
                }
                return pairs
            }
        }
        
        return []
    }
    
    public static func fetchUsage() async throws -> AntigravityUsageData {
        guard var creds = getCredentials() else {
            throw NSError(domain: "Antigravity", code: 404, userInfo: [NSLocalizedDescriptionKey: "No Antigravity credentials found at ~/.gemini/jetski-standalone-oauth-token"])
        }
        
        var token: String
        do {
            token = try await getFreshAccessToken(creds: &creds)
        } catch {
            if let rf = creds.refreshToken {
                token = try await refreshAccessToken(refreshToken: rf)
            } else {
                throw error
            }
        }
        
        // 1. loadCodeAssist to obtain companion project
        let project = try await loadProject(token: token)
        
        // 2. retrieveUserQuotaSummary
        let groups = try await fetchQuotaSummary(token: token, project: project)
        
        return AntigravityUsageData(
            groups: groups,
            lastUpdated: Date(),
            status: .success,
            credentialSource: creds.source,
            project: project
        )
    }
    
    private static func loadProject(token: String) async throws -> String {
        let url = URL(string: "https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["metadata": ["ideType": "ANTIGRAVITY"]])
        
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpResp = response as? HTTPURLResponse else {
            throw NSError(domain: "Antigravity", code: -1, userInfo: [NSLocalizedDescriptionKey: "No HTTP response"])
        }
        
        if httpResp.statusCode == 401 || httpResp.statusCode == 403 {
            throw NSError(domain: "Antigravity", code: httpResp.statusCode, userInfo: [NSLocalizedDescriptionKey: "Antigravity authentication expired"])
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let project = json["cloudaicompanionProject"] as? String, !project.isEmpty else {
            return "aicode-consumers" // Fallback project
        }
        
        return project
    }
    
    private static func fetchQuotaSummary(token: String, project: String) async throws -> [AntigravityGroupQuota] {
        let url = URL(string: "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["project": project])
        
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawGroups = json["groups"] as? [[String: Any]] else {
            throw NSError(domain: "Antigravity", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to retrieve quota summary"])
        }
        
        var resultGroups: [AntigravityGroupQuota] = []
        
        for g in rawGroups {
            let name = (g["displayName"] as? String) ?? "Unknown Model"
            var icon = "sparkles"
            let lower = name.lowercased()
            if lower.contains("claude") || lower.contains("gpt") {
                icon = "brain.head.profile"
            } else if lower.contains("argon") {
                icon = "bolt.fill"
            }
            
            var fiveHourBucket: UsageBucket? = nil
            var weeklyBucket: UsageBucket? = nil
            
            if let buckets = g["buckets"] as? [[String: Any]] {
                for b in buckets {
                    let window = (b["window"] as? String)?.lowercased() ?? ""
                    let remFraction = (b["remainingFraction"] as? Double) ?? 1.0
                    let usedFraction = max(0.0, min(1.0, 1.0 - remFraction))
                    let resetStr = b["resetTime"] as? String
                    let resetDate = resetStr.flatMap { isoFormatter.date(from: $0) ?? fallbackIsoFormatter.date(from: $0) }
                    
                    let bucket = UsageBucket(utilization: usedFraction, resetsAt: resetDate, rawResetsAt: resetStr)
                    if window == "5h" {
                        fiveHourBucket = bucket
                    } else if window == "weekly" {
                        weeklyBucket = bucket
                    }
                }
            }
            
            resultGroups.append(AntigravityGroupQuota(
                displayName: name,
                iconName: icon,
                fiveHour: fiveHourBucket,
                weekly: weeklyBucket
            ))
        }
        
        return resultGroups
    }
}
