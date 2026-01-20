import Foundation

/// Centralized time formatting utilities
struct TimeFormatter {
    
    /// Parse ISO 8601 date string from backend (e.g. "2025-12-30T01:33:19.756588")
    static func parseISO(_ isoString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        
        // Try with fractional seconds first
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        if let date = formatter.date(from: isoString) {
            return date
        }
        
        // Fallback: try without fractional seconds
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: isoString)
    }
    
    /// Format an ISO date string as relative time: "just now", "5m ago", "2h ago", "3d ago"
    static func timeAgo(from isoString: String) -> String {
        guard let date = parseISO(isoString) else {
            return "recently"
        }
        return timeAgo(from: date)
    }
    
    /// Format a date as relative time: "just now", "5m ago", "2h ago", "3d ago"
    static func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
    
    /// Format a time interval as relative time
    static func timeAgo(from interval: TimeInterval) -> String {
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}
