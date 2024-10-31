import Foundation

enum TokenType {
    case word
    case identifier
    case keyword
    case `operator`
    case bracket
    case whitespace
    case punctuation
    case other
}

struct TextToken {
    let text: String
    let normalized: String
    let type: TokenType
    var isCode: Bool
}
