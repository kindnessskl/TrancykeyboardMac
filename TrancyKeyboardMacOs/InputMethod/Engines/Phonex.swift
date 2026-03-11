import Foundation

struct Phonex {
    static func encode(_ text: String) -> String {
        if text.isEmpty { return "" }
        
        let input = text.uppercased()
        var name = input.replacingOccurrences(of: "[^A-Z]", with: "", options: .regularExpression)
        if name.isEmpty { return "" }
        
        while name.hasSuffix("S") {
            name.removeLast()
        }
        if name.isEmpty { return "" }
        
        if name.hasPrefix("KN") {
            name = "N" + name.dropFirst(2)
        } else if name.hasPrefix("PH") {
            name = "F" + name.dropFirst(2)
        } else if name.hasPrefix("WR") {
            name = "R" + name.dropFirst(2)
        }
        
        if name.hasPrefix("H") {
            name = String(name.dropFirst())
        }
        if name.isEmpty { return "" }
        
        let initials: [Set<Character>: Character] = [
            Set("AEIOUY"): "A",
            Set("BP"): "B",
            Set("VF"): "F",
            Set("KQC"): "C",
            Set("JG"): "G",
            Set("ZS"): "S"
        ]
        
        let firstChar = name.first!
        var code = String(firstChar)
        
        for (letters, replacement) in initials {
            if letters.contains(firstChar) {
                code = String(replacement)
                break
            }
        }
        
        let bSet: Set<Character> = Set("BPFV")
        let cSet: Set<Character> = Set("CSKGJQXZ")
        let vowels: Set<Character> = Set("AEIOUY")
        
        var lastEncoding = code
        let chars = Array(name)
        
        for i in 1..<chars.count {
            let letter = chars[i]
            let nextLetter = (i + 1 < chars.count) ? chars[i+1] : nil
            
            var encoding = "0"
            
            if bSet.contains(letter) {
                encoding = "1"
            } else if cSet.contains(letter) {
                encoding = "2"
            } else if letter == "D" || letter == "T" {
                if nextLetter != "C" {
                    encoding = "3"
                }
            } else if letter == "L" {
                if nextLetter == nil || vowels.contains(nextLetter!) {
                    encoding = "4"
                }
            } else if letter == "M" || letter == "N" {
                encoding = "5"
            } else if letter == "R" {
                if nextLetter == nil || vowels.contains(nextLetter!) {
                    encoding = "6"
                }
            }
            
            if encoding != "0" && encoding != lastEncoding {
                code.append(encoding)
                lastEncoding = encoding
            }
        }
        
        if name.count > 4 && code.count <= 1 {
            return ""
        }
        
        let hasVowel = name.contains { vowels.contains($0) }
        if name.count >= 3 && !hasVowel {
            return ""
        }
        
        return code
    }
}
