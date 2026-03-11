import Foundation

extension String {

    func damerauLevenshteinDistance(to other: String, limit: Int = 2) -> Int {
        let s = Array(self.lowercased())
        let t = Array(other.lowercased())
        let n = s.count
        let m = t.count
        
        if abs(n - m) > limit { return limit + 1 }
        
        var d = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        
        for i in 0...n { d[i][0] = i }
        for j in 0...m { d[0][j] = j }
        
        for i in 1...n {
            var minDistanceInRow = Int.max
            for j in 1...m {
                let cost = (s[i-1] == t[j-1]) ? 0 : 1
                
                d[i][j] = min(d[i-1][j] + 1,
                              min(d[i][j-1] + 1,
                                  d[i-1][j-1] + cost))
                
                if i > 1 && j > 1 && s[i-1] == t[j-2] && s[i-2] == t[j-1] {
                    d[i][j] = min(d[i][j], d[i-2][j-2] + cost)
                }
                
                minDistanceInRow = min(minDistanceInRow, d[i][j])
            }
            
            if minDistanceInRow > limit {
                return limit + 1
            }
        }
        return d[n][m]
    }
}
