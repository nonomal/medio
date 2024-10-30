import Foundation

class StringUtils {
    static func normalizeString(_ str: String) -> String {
        return str.decomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func compareStrings(_ str1: String, _ str2: String) -> Bool {
        let str1Clean = normalizeString(str1)
        let str2Clean = normalizeString(str2)
        return str1Clean == str2Clean
    }
    
    static func tokenizeCode(_ text: String) -> [String] {
        // Split code into meaningful tokens while preserving special characters
        let pattern = "([a-zA-Z_][a-zA-Z0-9_]*|[{}()\\[\\].,;:]|\\s+|\".+?\"|'.+?'|=>|==|!=|>=|<=|\\+=|-=|\\*=|/=|&&|\\|\\||\\+\\+|--|//.*|/\\*.*?\\*/)"
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
        
        return matches.map { match in
            if let range = Range(match.range, in: text) {
                return String(text[range])
            }
            return ""
        }.filter { !$0.isEmpty }
    }
}
