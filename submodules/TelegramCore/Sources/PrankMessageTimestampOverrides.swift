import Foundation
import Postbox

public struct PrankMessageTimeOverride: Codable, Equatable {
    public let hour: Int
    public let minute: Int
    
    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }
}

public struct PrankMessageDateOverride: Codable, Equatable {
    public let anchorTimestamp: Int32
    public let deltaSeconds: Int32
    
    public init(anchorTimestamp: Int32, deltaSeconds: Int32) {
        self.anchorTimestamp = anchorTimestamp
        self.deltaSeconds = deltaSeconds
    }
}

public enum PrankMessageTimestampOverrides {
    private static func debugLog(_ text: String) {
        NSLog("[PrankTimestamp] \(text)")
    }
    
    private static let timeOverridesKey = "PrankMessageTimestampOverrides.time.v1"
    private static let dateOverridesKey = "PrankMessageTimestampOverrides.date.v1"
    
    private static func key(for messageId: MessageId) -> String {
        return "\(messageId.peerId.toInt64()):\(messageId.namespace):\(messageId.id)"
    }
    
    private static func peerKey(for messageId: MessageId) -> String {
        return "\(messageId.peerId.toInt64())"
    }
    
    private static func loadTimeOverrides() -> [String: PrankMessageTimeOverride] {
        guard let data = UserDefaults.standard.data(forKey: self.timeOverridesKey) else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: PrankMessageTimeOverride].self, from: data)) ?? [:]
    }
    
    private static func storeTimeOverrides(_ values: [String: PrankMessageTimeOverride]) {
        if values.isEmpty {
            UserDefaults.standard.removeObject(forKey: self.timeOverridesKey)
        } else if let data = try? JSONEncoder().encode(values) {
            UserDefaults.standard.set(data, forKey: self.timeOverridesKey)
        }
    }
    
    private static func loadDateOverrides() -> [String: [PrankMessageDateOverride]] {
        guard let data = UserDefaults.standard.data(forKey: self.dateOverridesKey) else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: [PrankMessageDateOverride]].self, from: data)) ?? [:]
    }
    
    private static func storeDateOverrides(_ values: [String: [PrankMessageDateOverride]]) {
        if values.isEmpty {
            UserDefaults.standard.removeObject(forKey: self.dateOverridesKey)
        } else if let data = try? JSONEncoder().encode(values) {
            UserDefaults.standard.set(data, forKey: self.dateOverridesKey)
        }
    }
    
    public static func timeOverride(for messageId: MessageId) -> PrankMessageTimeOverride? {
        let result = self.loadTimeOverrides()[self.key(for: messageId)]
        if let result = result {
            self.debugLog("timeOverride hit hour=\(result.hour) minute=\(result.minute)")
        }
        return result
    }
    
    public static func setTimeOverride(messageId: MessageId, hour: Int, minute: Int) {
        self.debugLog("setTimeOverride begin hour=\(hour) minute=\(minute)")
        guard hour >= 0 && hour < 24 && minute >= 0 && minute < 60 else {
            self.debugLog("setTimeOverride invalid input")
            return
        }
        var values = self.loadTimeOverrides()
        values[self.key(for: messageId)] = PrankMessageTimeOverride(hour: hour, minute: minute)
        self.storeTimeOverrides(values)
        self.debugLog("setTimeOverride stored count=\(values.count)")
    }
    
    public static func clearTimeOverride(messageId: MessageId) {
        var values = self.loadTimeOverrides()
        values.removeValue(forKey: self.key(for: messageId))
        self.storeTimeOverrides(values)
    }
    
    public static func parseTime(_ text: String) -> PrankMessageTimeOverride? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ".", with: ":")
        let parts = normalized.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else {
            return nil
        }
        guard hour >= 0 && hour < 24 && minute >= 0 && minute < 60 else {
            return nil
        }
        return PrankMessageTimeOverride(hour: hour, minute: minute)
    }
    
    public static func setDateOverride(messageId: MessageId, timestamp: Int32, dateText: String) -> Bool {
        self.debugLog("setDateOverride begin timestamp=\(timestamp) text=\(dateText)")
        guard let targetComponents = self.parseDate(dateText) else {
            self.debugLog("setDateOverride parse failed")
            return false
        }
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let originalDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let originalComponents = calendar.dateComponents([.hour, .minute, .second], from: originalDate)
        var components = DateComponents()
        components.year = targetComponents.year
        components.month = targetComponents.month
        components.day = targetComponents.day
        components.hour = originalComponents.hour
        components.minute = originalComponents.minute
        components.second = originalComponents.second
        guard let targetDate = calendar.date(from: components) else {
            return false
        }
        let delta = Int32(targetDate.timeIntervalSince1970 - originalDate.timeIntervalSince1970)
        var values = self.loadDateOverrides()
        let key = self.peerKey(for: messageId)
        var overrides = values[key] ?? []
        overrides.removeAll(where: { $0.anchorTimestamp == timestamp })
        overrides.append(PrankMessageDateOverride(anchorTimestamp: timestamp, deltaSeconds: delta))
        overrides.sort(by: { $0.anchorTimestamp < $1.anchorTimestamp })
        values[key] = overrides
        self.storeDateOverrides(values)
        self.debugLog("setDateOverride stored peerOverrides=\(overrides.count) delta=\(delta)")
        return true
    }
    
    public static func effectiveTimestamp(messageId: MessageId, timestamp: Int32) -> Int32 {
        let key = self.peerKey(for: messageId)
        guard let overrides = self.loadDateOverrides()[key] else {
            return timestamp
        }
        var result = timestamp
        for override in overrides {
            if override.anchorTimestamp <= timestamp {
                result = timestamp + override.deltaSeconds
            } else {
                break
            }
        }
        return result
    }
    
    private static func parseDate(_ text: String) -> (year: Int, month: Int, day: Int)? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "/", with: ".").replacingOccurrences(of: "-", with: ".")
        let parts = normalized.split(separator: ".")
        guard parts.count == 3, let day = Int(parts[0]), let month = Int(parts[1]), let year = Int(parts[2]) else {
            return nil
        }
        guard year >= 2000 && year <= 2099 && month >= 1 && month <= 12 && day >= 1 && day <= 31 else {
            return nil
        }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components).flatMap { date in
            let verified = Calendar.current.dateComponents([.year, .month, .day], from: date)
            guard verified.year == year && verified.month == month && verified.day == day else {
                return nil
            }
            return (year, month, day)
        }
    }
}
