import Foundation

/// General-purpose cache manager for file-based caching
class CacheManager {
    static let shared = CacheManager()
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        // Get app's cache directory
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("KingdomCache", isDirectory: true)
        
        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        print("📦 Cache directory: \(cacheDirectory.path)")
    }
    
    // MARK: - Generic Cache Operations
    
    /// Save Codable object to cache
    func save<T: Codable>(_ object: T, forKey key: String) {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(object)
            try data.write(to: fileURL, options: .atomic)
            print("💾 Cached: \(key) (\(data.count) bytes)")
        } catch {
            print("❌ Failed to cache \(key): \(error)")
        }
    }
    
    /// Load Codable object from cache
    func load<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("⚠️ Cache miss: \(key)")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let object = try decoder.decode(type, from: data)
            print("✅ Cache hit: \(key) (\(data.count) bytes)")
            return object
        } catch {
            print("❌ Failed to load cache \(key): \(error)")
            return nil
        }
    }
    
    /// Check if cache exists for key
    func exists(forKey key: String) -> Bool {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    /// Get cache age in seconds
    func cacheAge(forKey key: String) -> TimeInterval? {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        
        guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let modificationDate = attributes[.modificationDate] as? Date else {
            return nil
        }
        
        return Date().timeIntervalSince(modificationDate)
    }
    
    /// Check if cache is expired (older than maxAge seconds)
    func isExpired(forKey key: String, maxAge: TimeInterval) -> Bool {
        guard let age = cacheAge(forKey: key) else { return true }
        return age > maxAge
    }
    
    /// Remove cached item
    func remove(forKey key: String) {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        try? fileManager.removeItem(at: fileURL)
        print("🗑️ Removed cache: \(key)")
    }
    
    /// Clear all cache
    func clearAll() {
        guard let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        
        for fileURL in contents {
            try? fileManager.removeItem(at: fileURL)
        }
        
        print("🗑️ Cleared all cache")
    }
    
    /// Get total cache size in bytes
    func totalCacheSize() -> Int64 {
        guard let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        for fileURL in contents {
            if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let fileSize = attributes[.size] as? Int64 {
                totalSize += fileSize
            }
        }
        
        return totalSize
    }
    
    /// Format cache size as human-readable string
    func formattedCacheSize() -> String {
        let bytes = totalCacheSize()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

