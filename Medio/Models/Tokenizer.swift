import Foundation

final class Tokenizer {
    static func tokenize(_ text: String, isCode: Bool) -> [TextToken] {
        isCode ? tokenizeCode(text) : tokenizeText(text)
    }
    
    private static func tokenizeText(_ text: String) -> [TextToken] {
        let pattern = """
            (?x)
            ([\\p{L}\\p{N}]+[-'']*[\\p{L}\\p{N}]+) | # Words with contractions/hyphens
            ([\\p{L}\\p{N}]+) |                       # Simple words
            ([\\s]+) |                                 # Whitespace
            ([.,!?;:—–-]) |                           # Punctuation
            (.)                                        # Any other character
            """
        
        let regex = try! NSRegularExpression(pattern: pattern)
        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: nsRange)
        
        return matches.compactMap { match -> TextToken? in
            guard let range = Range(match.range, in: text) else { return nil }
            let token = String(text[range])
            
            let type: TokenType
            if match.range(at: 1).location != NSNotFound || match.range(at: 2).location != NSNotFound {
                type = .word
            } else if match.range(at: 3).location != NSNotFound {
                type = .whitespace
            } else if match.range(at: 4).location != NSNotFound {
                type = .punctuation
            } else {
                type = .other
            }
            
            return TextToken(
                text: token,
                normalized: normalizeToken(token, type: type),
                type: type,
                isCode: false
            )
        }
    }
    
    private static func tokenizeCode(_ text: String) -> [TextToken] {
        let pattern = """
            (?x)
            ([a-zA-Z_][a-zA-Z0-9_]*) |                # Identifiers
            ([{}()\\[\\].,;:]) |                      # Brackets/Punctuation
            (=>|==|!=|>=|<=|\\+=|-=|\\*=|/=|&&|\\|\\||\\+\\+|--|=|\\+|-|\\*|/) | # Operators
            ("[^"]*"|'[^']*') |                       # Strings
            ([\\s]+) |                                # Whitespace
            (.)                                        # Other
            """
        
        let regex = try! NSRegularExpression(pattern: pattern)
        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: nsRange)
        
        return matches.compactMap { match -> TextToken? in
            guard let range = Range(match.range, in: text) else { return nil }
            let token = String(text[range])
            
            let type: TokenType
            if match.range(at: 1).location != NSNotFound {
                type = CodeAnalyzer.keywords.contains(token) ? .keyword : .identifier
            } else if match.range(at: 2).location != NSNotFound {
                type = .bracket
            } else if match.range(at: 3).location != NSNotFound {
                type = .operator
            } else if match.range(at: 4).location != NSNotFound {
                type = .other
            } else if match.range(at: 5).location != NSNotFound {
                type = .whitespace
            } else {
                type = .other
            }
            
            return TextToken(
                text: token,
                normalized: normalizeToken(token, type: type),
                type: type,
                isCode: true
            )
        }
    }
    
    private static func normalizeToken(_ token: String, type: TokenType) -> String {
        switch type {
        case .word:
            return token.lowercased()
                .trimmingCharacters(in: CharacterSet(charactersIn: "-'"))
        case .identifier, .keyword:
            return token
        case .whitespace:
            return " "
        default:
            return token
        }
    }
}
