// Utils/StatementAnalyzer.swift
import Foundation

struct StatementPart {
    let text: String
    let range: NSRange
    let type: StatementPartType
}

enum StatementPartType {
    case keyword
    case identifier
    case separator
    case moduleSpecifier
    case destructuring
    case stringLiteral
    case other
}

class StatementAnalyzer {
    static func analyzeImportStatement(_ statement: String, startLocation: Int) -> [StatementPart] {
        var parts: [StatementPart] = []
        var currentLocation = startLocation
        
        // Regular expression to parse import statement
        // Matches: import <module>[, { <destructured> }] from '<path>'
        let pattern = try! NSRegularExpression(pattern: """
            (import\\s+)              # import keyword
            ([A-Za-z0-9_]+)          # main module
            (\\s*,\\s*)?             # optional comma
            (\\{[^}]*\\})?           # destructuring block
            (\\s+from\\s+)           # from keyword
            ('[^']+'|"[^"]+")        # module path
            (\\s*;?\\s*)             # optional semicolon and whitespace
            """, options: [.allowCommentsAndWhitespace])
        
        let nsString = statement as NSString
        let range = NSRange(location: 0, length: nsString.length)
        
        if let match = pattern.firstMatch(in: statement, options: [], range: range) {
            // Import keyword
            if let range = Range(match.range(at: 1), in: statement) {
                let text = String(statement[range])
                parts.append(StatementPart(
                    text: text,
                    range: NSRange(location: currentLocation, length: text.count),
                    type: .keyword
                ))
                currentLocation += text.count
            }
            
            // Main module
            if let range = Range(match.range(at: 2), in: statement) {
                let text = String(statement[range])
                parts.append(StatementPart(
                    text: text,
                    range: NSRange(location: currentLocation, length: text.count),
                    type: .identifier
                ))
                currentLocation += text.count
            }
            
            // Comma and spacing before destructuring
            if let range = Range(match.range(at: 3), in: statement) {
                let text = String(statement[range])
                parts.append(StatementPart(
                    text: text,
                    range: NSRange(location: currentLocation, length: text.count),
                    type: .separator
                ))
                currentLocation += text.count
            }
            
            // Destructuring block
            if let range = Range(match.range(at: 4), in: statement) {
                let text = String(statement[range])
                parts.append(StatementPart(
                    text: text,
                    range: NSRange(location: currentLocation, length: text.count),
                    type: .destructuring
                ))
                currentLocation += text.count
            }
            
            // From keyword
            if let range = Range(match.range(at: 5), in: statement) {
                let text = String(statement[range])
                parts.append(StatementPart(
                    text: text,
                    range: NSRange(location: currentLocation, length: text.count),
                    type: .keyword
                ))
                currentLocation += text.count
            }
            
            // Module path
            if let range = Range(match.range(at: 6), in: statement) {
                let text = String(statement[range])
                parts.append(StatementPart(
                    text: text,
                    range: NSRange(location: currentLocation, length: text.count),
                    type: .moduleSpecifier
                ))
                currentLocation += text.count
            }
            
            // Trailing semicolon and whitespace
            if let range = Range(match.range(at: 7), in: statement) {
                let text = String(statement[range])
                if !text.isEmpty {
                    parts.append(StatementPart(
                        text: text,
                        range: NSRange(location: currentLocation, length: text.count),
                        type: .separator
                    ))
                }
            }
        }
        
        return parts
    }
    
    static func compareImportStatements(_ source: String, _ target: String, sourceStartLocation: Int) -> [WordDiff] {
        let sourceParts = analyzeImportStatement(source, startLocation: sourceStartLocation)
        let targetParts = analyzeImportStatement(target, startLocation: sourceStartLocation)
        
        var diffs: [WordDiff] = []
        
        // Compare main module identifiers
        if let sourceModule = sourceParts.first(where: { $0.type == .identifier }),
           let targetModule = targetParts.first(where: { $0.type == .identifier }) {
            if sourceModule.text != targetModule.text {
                diffs.append(WordDiff(range: sourceModule.range, type: .modification))
            }
        }
        
        // Compare destructuring blocks
        if let sourceDestruct = sourceParts.first(where: { $0.type == .destructuring }) {
            if let targetDestruct = targetParts.first(where: { $0.type == .destructuring }) {
                if sourceDestruct.text != targetDestruct.text {
                    // Only highlight the destructuring block if it's different
                    diffs.append(WordDiff(range: sourceDestruct.range, type: .modification))
                }
            } else {
                // Highlight if source has destructuring but target doesn't
                diffs.append(WordDiff(range: sourceDestruct.range, type: .deletion))
            }
        } else if let targetDestruct = targetParts.first(where: { $0.type == .destructuring }) {
            // Find where the destructuring would have been in source
            if let sourceModule = sourceParts.first(where: { $0.type == .identifier }) {
                let destructRange = NSRange(
                    location: sourceModule.range.location + sourceModule.range.length,
                    length: 0
                )
                diffs.append(WordDiff(range: destructRange, type: .addition))
            }
        }
        
        // Compare module paths
        if let sourcePath = sourceParts.first(where: { $0.type == .moduleSpecifier }),
           let targetPath = targetParts.first(where: { $0.type == .moduleSpecifier }) {
            if sourcePath.text != targetPath.text {
                diffs.append(WordDiff(range: sourcePath.range, type: .modification))
            }
        }
        
        return diffs
    }
}
