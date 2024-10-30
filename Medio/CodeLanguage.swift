import Foundation

enum CodeLanguage {
    case javascript
    case python
    case swift
    case unknown
    
    static func detect(from text: String) -> CodeLanguage {
        // Simple language detection based on common patterns
        if text.contains("import React") || text.contains("const ") || text.contains("function ") {
            return .javascript
        } else if text.contains("def ") || text.contains("import ") && text.contains(":") {
            return .python
        } else if text.contains("import SwiftUI") || text.contains("struct ") && text.contains("View") {
            return .swift
        }
        return .unknown
    }
    
    var keywords: Set<String> {
        switch self {
        case .javascript:
            return ["const", "let", "var", "function", "return", "import", "export", "default", "class", "extends", "static", "if", "else", "for", "while", "do", "switch", "case", "break", "continue", "try", "catch", "finally", "throw", "new", "this", "super", "instanceof", "typeof", "void", "delete", "null", "undefined"]
        case .python:
            return ["def", "class", "if", "else", "elif", "for", "while", "try", "except", "finally", "with", "as", "import", "from", "return", "yield", "break", "continue", "pass", "raise", "True", "False", "None", "and", "or", "not", "is", "in", "lambda"]
        case .swift:
            return ["class", "struct", "enum", "protocol", "extension", "func", "var", "let", "if", "else", "guard", "switch", "case", "break", "continue", "return", "throw", "try", "catch", "for", "while", "repeat", "import", "public", "private", "fileprivate", "internal", "static", "final", "override", "mutating", "nonmutating", "convenience", "weak", "unowned", "required", "optional", "nil"]
        case .unknown:
            return []
        }
    }
}
