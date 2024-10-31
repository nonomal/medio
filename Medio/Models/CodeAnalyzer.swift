import Foundation

final class CodeAnalyzer {
    static let keywords = Set([
        "import", "export", "default", "function", "class", "const", "let", "var",
        "return", "if", "else", "for", "while", "do", "switch", "case", "break",
        "continue", "try", "catch", "throw", "new", "delete", "typeof", "instanceof",
        "void", "this", "super", "extends", "static", "get", "set", "async", "await"
    ])
    
    static func detectCodeContent(_ text: String) -> Bool {
        let codeIndicators = [
            "^\\s*import\\s+[\\w.]+\\s*;?$",
            "^\\s*export\\s+",
            "^\\s*function\\s+\\w+\\s*\\(",
            "^\\s*class\\s+\\w+",
            "^\\s*const\\s+\\w+\\s*=",
            "^\\s*let\\s+\\w+\\s*=",
            "^\\s*var\\s+\\w+\\s*=",
            "^\\s*return\\s+",
            "^\\s*if\\s*\\(",
            "^\\s*for\\s*\\(",
            "^\\s*while\\s*\\("
        ]
        
        let combinedPattern = codeIndicators.joined(separator: "|")
        let regex = try? NSRegularExpression(pattern: combinedPattern)
        let nsRange = NSRange(text.startIndex..., in: text)
        return regex?.firstMatch(in: text, range: nsRange) != nil
    }
    
    static func normalizeCodeLine(_ line: String) -> String {
        line.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}
