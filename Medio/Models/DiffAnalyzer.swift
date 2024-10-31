import Foundation

struct TextToken {
    let text: String
    let normalized: String
    let type: TokenType
    var isCode: Bool
    
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
}

final class DiffAnalyzer {
    private let sourceText: String
    private let targetText: String
    private let sourceLines: [(String, NSRange)]
    private let targetLines: [(String, NSRange)]
    private let isCode: Bool
    
    private static let codeKeywords = Set([
        "import", "export", "default", "function", "class", "const", "let", "var",
        "return", "if", "else", "for", "while", "do", "switch", "case", "break",
        "continue", "try", "catch", "throw", "new", "delete", "typeof", "instanceof",
        "void", "this", "super", "extends", "static", "get", "set", "async", "await"
    ])
    
    init(sourceText: String, targetText: String) {
        self.sourceText = sourceText
        self.targetText = targetText
        self.sourceLines = Self.getLinesWithRanges(sourceText)
        self.targetLines = Self.getLinesWithRanges(targetText)
        self.isCode = Self.detectCodeContent(sourceText)
    }
    
    private static func getLinesWithRanges(_ text: String) -> [(String, NSRange)] {
        var currentLocation = 0
        return text.components(separatedBy: .newlines).map { line in
            let length = line.utf16.count
            let range = NSRange(location: currentLocation, length: length)
            currentLocation += length + 1  // +1 for newline
            return (line, range)
        }
    }
    
    private static func detectCodeContent(_ text: String) -> Bool {
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
    
    func computeDifferences() -> [LineDiff] {
        var processedTargetLines = Set<Int>()
        var lineMatchCache: [Int: Int] = [:]
        
        // First pass: exact matches for code
        if isCode {
            for (sourceIdx, sourceLine) in sourceLines.enumerated() {
                if let matchIdx = findExactCodeMatch(for: sourceLine.0,
                                                     in: targetLines,
                                                     processedLines: processedTargetLines) {
                    lineMatchCache[sourceIdx] = matchIdx
                    processedTargetLines.insert(matchIdx)
                }
            }
        }
        
        return sourceLines.enumerated().map { (lineIndex, lineInfo) -> LineDiff in
            let (sourceLine, lineRange) = lineInfo
            let wordDiffs = computeWordDiffs(
                sourceLine: sourceLine,
                lineRange: lineRange,
                processedTargetLines: &processedTargetLines,
                lineMatchCache: lineMatchCache,
                lineIndex: lineIndex
            )
            
            return LineDiff(
                range: lineRange,
                wordDiffs: wordDiffs,
                isDifferent: !wordDiffs.isEmpty,
                lineNumber: lineIndex
            )
        }
    }
    
    private func findExactCodeMatch(for sourceLine: String,
                                    in targetLines: [(String, NSRange)],
                                    processedLines: Set<Int>) -> Int? {
        let sourceNormalized = normalizeCodeLine(sourceLine)
        
        for (index, (targetLine, _)) in targetLines.enumerated() {
            guard !processedLines.contains(index) else { continue }
            let targetNormalized = normalizeCodeLine(targetLine)
            if sourceNormalized == targetNormalized {
                return index
            }
        }
        return nil
    }
    
    private func normalizeCodeLine(_ line: String) -> String {
        line.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
    
    private func computeWordDiffs(sourceLine: String,
                                  lineRange: NSRange,
                                  processedTargetLines: inout Set<Int>,
                                  lineMatchCache: [Int: Int],
                                  lineIndex: Int) -> [WordDiff] {
        let trimmedSource = sourceLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSource.isEmpty { return [] }
        
        // Use cached match for code
        if isCode, let matchIndex = lineMatchCache[lineIndex] {
            return compareLines(
                sourceLine: sourceLine,
                targetLine: targetLines[matchIndex].0,
                sourceStartLocation: lineRange.location,
                totalLength: lineRange.length
            )
        }
        
        if let matchIndex = findBestMatch(
            for: sourceLine,
            in: targetLines,
            processedLines: processedTargetLines
        ) {
            processedTargetLines.insert(matchIndex)
            return compareLines(
                sourceLine: sourceLine,
                targetLine: targetLines[matchIndex].0,
                sourceStartLocation: lineRange.location,
                totalLength: lineRange.length
            )
        }
        
        return [WordDiff(range: lineRange, type: .deletion)]
    }
    
    private func findBestMatch(for sourceLine: String,
                               in targetLines: [(String, NSRange)],
                               processedLines: Set<Int>) -> Int? {
        let sourceTokens = tokenize(sourceLine)
        var bestMatch: (index: Int, score: Double) = (-1, 0.0)
        let threshold = isCode ? 0.5 : 0.3
        
        for (index, (targetLine, _)) in targetLines.enumerated() {
            guard !processedLines.contains(index) else { continue }
            let targetTokens = tokenize(targetLine)
            let similarity = calculateSimilarity(source: sourceTokens, target: targetTokens)
            
            if similarity > bestMatch.score {
                bestMatch = (index, similarity)
            }
        }
        
        return bestMatch.score > threshold ? bestMatch.index : nil
    }
    
    private func calculateSimilarity(source: [TextToken], target: [TextToken]) -> Double {
        if isCode {
            return calculateCodeSimilarity(source: source, target: target)
        }
        
        let sourceWords = Set(source.filter { $0.type != .whitespace }.map { $0.normalized })
        let targetWords = Set(target.filter { $0.type != .whitespace }.map { $0.normalized })
        
        // Handle empty cases
        if sourceWords.isEmpty && targetWords.isEmpty {
            return 1.0
        }
        if sourceWords.isEmpty || targetWords.isEmpty {
            return 0.0
        }
        
        let intersection = sourceWords.intersection(targetWords)
        let union = sourceWords.union(targetWords)
        
        return Double(intersection.count) / Double(union.count)
    }
    
    private func calculateCodeSimilarity(source: [TextToken], target: [TextToken]) -> Double {
        let sourceStructure = source.filter { $0.type != .whitespace }.map { $0.normalized }
        let targetStructure = target.filter { $0.type != .whitespace }.map { $0.normalized }
        
        // Handle empty cases
        if sourceStructure.isEmpty && targetStructure.isEmpty {
            return 1.0
        }
        if sourceStructure.isEmpty || targetStructure.isEmpty {
            return 0.0
        }
        
        let lcs = longestCommonSubsequence(sourceStructure, targetStructure)
        let maxLength = Double(max(sourceStructure.count, targetStructure.count))
        
        return Double(lcs) / maxLength
    }
    
    private func longestCommonSubsequence(_ source: [String], _ target: [String]) -> Int {
        // Handle empty cases first
        guard !source.isEmpty && !target.isEmpty else {
            return 0
        }
        
        // Create DP matrix with safe dimensions
        var dp = Array(repeating: Array(repeating: 0, count: target.count + 1),
                       count: source.count + 1)
        
        // Safe iteration over valid ranges
        for i in 0..<source.count {
            for j in 0..<target.count {
                if source[i] == target[j] {
                    dp[i + 1][j + 1] = dp[i][j] + 1
                } else {
                    dp[i + 1][j + 1] = max(dp[i + 1][j], dp[i][j + 1])
                }
            }
        }
        
        return dp[source.count][target.count]
    }
    
    private func tokenize(_ text: String) -> [TextToken] {
        if isCode {
            return tokenizeCode(text)
        } else {
            return tokenizeText(text)
        }
    }
    
    private func tokenizeText(_ text: String) -> [TextToken] {
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
            
            let type: TextToken.TokenType
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
    
    private func tokenizeCode(_ text: String) -> [TextToken] {
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
            
            let type: TextToken.TokenType
            if match.range(at: 1).location != NSNotFound {
                type = Self.codeKeywords.contains(token) ? .keyword : .identifier
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
    
    private func normalizeToken(_ token: String, type: TextToken.TokenType) -> String {
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
    
    private func compareLines(sourceLine: String,
                              targetLine: String,
                              sourceStartLocation: Int,
                              totalLength: Int) -> [WordDiff] {
        // Guard against empty or invalid input
        guard !sourceLine.isEmpty && !targetLine.isEmpty && totalLength > 0 else {
            return []
        }
        
        let sourceTokens = tokenize(sourceLine)
        let targetTokens = tokenize(targetLine)
        
        // Guard against empty tokens
        guard !sourceTokens.isEmpty else {
            return []
        }
        
        var diffs: [WordDiff] = []
        var currentLocation = 0
        
        for sourceToken in sourceTokens {
            // Ensure we don't exceed bounds
            guard currentLocation < totalLength else { break }
            
            let tokenLength = min(sourceToken.text.utf16.count, totalLength - currentLocation)
            guard tokenLength > 0 else { continue }
            
            let tokenLocation = sourceStartLocation + currentLocation
            
            let matchFound = targetTokens.contains { targetToken in
                if isCode {
                    return sourceToken.normalized == targetToken.normalized &&
                    sourceToken.type == targetToken.type
                } else {
                    return sourceToken.normalized == targetToken.normalized
                }
            }
            
            if !matchFound && sourceToken.type != .whitespace {
                // Ensure range is valid
                let safeLength = min(tokenLength, totalLength - tokenLocation)
                guard safeLength > 0 else { continue }
                
                diffs.append(WordDiff(
                    range: NSRange(location: tokenLocation, length: safeLength),
                    type: .modification
                ))
            }
            
            currentLocation += tokenLength
        }
        
        return diffs
    }
}
