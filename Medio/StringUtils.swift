import Foundation

final class StringUtils {
    private static let tokenPattern = "([a-zA-Z_][a-zA-Z0-9_]*|[{}()\\[\\].,;:]|\\s+|\".+?\"|'.+?'|=>|==|!=|>=|<=|\\+=|-=|\\*=|/=|&&|\\|\\||\\+\\+|--|//.*|/\\*.*?\\*/)"
    private static let tokenRegex = try! NSRegularExpression(pattern: tokenPattern, options: [])
    
    static func normalizeString(_ str: String) -> String {
        str.decomposedStringWithCanonicalMapping.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func compareStrings(_ str1: String, _ str2: String) -> Bool {
        normalizeString(str1) == normalizeString(str2)
    }
    
    static func tokenizeCode(_ text: String) -> [String] {
        let matches = tokenRegex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        }
    }
}
