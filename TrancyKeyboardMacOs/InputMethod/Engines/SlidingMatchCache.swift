import Foundation

class SlidingMatchCache {
    static let shared = SlidingMatchCache()
    
    private var cache: [String: (syllable: String, score: Double)?] = [:]
    private let maxCacheSize = 1000
    
    private init() {}
    
    func get(_ noisyPart: String) -> (syllable: String, score: Double)?? {
        return cache[noisyPart]
    }
    
    func set(_ noisyPart: String, result: (syllable: String, score: Double)?) {
        if cache.count >= maxCacheSize {
            // Simple eviction: remove the first key
            if let firstKey = cache.keys.first {
                cache.removeValue(forKey: firstKey)
            }
        }
        cache[noisyPart] = result
    }
    
    func clear() {
        cache.removeAll()
    }
}
