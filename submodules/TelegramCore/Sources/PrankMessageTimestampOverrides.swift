import Foundation

public struct PrankMessageTimeOverride: Codable, Equatable {
    public let hour: Int
    public let minute: Int
    
    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }
}

public enum PrankMessageTimestampOverrides {
    private static let timeOverridesKey = "PrankMessageTimestampOverrides.time.v1"
    
    private static func key(for messageId: MessageId) -> String {
        return "\(messageId.peerId.toInt64()):\(messageId.namespace):\(messageId.id)"
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
    
    public static func timeOverride(for messageId: MessageId) -> PrankMessageTimeOverride? {
        return self.loadTimeOverrides()[self.key(for: messageId)]
    }
    
    public static func setTimeOverride(messageId: MessageId, hour: Int, minute: Int) {
        guard hour >= 0 && hour < 24 && minute >= 0 && minute < 60 else {
            return
        }
        var values = self.loadTimeOverrides()
        values[self.key(for: messageId)] = PrankMessageTimeOverride(hour: hour, minute: minute)
        self.storeTimeOverrides(values)
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
}
