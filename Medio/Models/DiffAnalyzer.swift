import Foundation
import Differ

final class DiffAnalyzer {
    private let sourceText: String
    private let targetText: String
    private let isCode: Bool
    private let sourceLines: [Line]
    private let targetLines: [Line]
    
    init(sourceText: String, targetText: String) {
        self.sourceText = sourceText
        self.targetText = targetText
        self.isCode = CodeAnalyzer.detectCodeContent(sourceText)
        self.sourceLines = Self.getLinesWithRanges(text: sourceText)
        self.targetLines = Self.getLinesWithRanges(text: targetText)
    }
    
    private static func getLinesWithRanges(text: String) -> [Line] {
        var currentLocation = 0
        return text.components(separatedBy: .newlines).map { line in
            let length = line.utf16.count
            let range = NSRange(location: currentLocation, length: length)
            currentLocation += length + 1
            return Line(text: line, range: range)
        }
    }
    
    func computeDifferences() -> [LineDiff] {
        let sourceLinesText = sourceLines.map { $0.text }
        let targetLinesText = targetLines.map { $0.text }
        
        // Use extended diff to catch moves as well
        let patches = extendedPatch(from: sourceLinesText, to: targetLinesText)
        var lineDiffs: [LineDiff] = []
        var processedIndices = Set<Int>()
        
        for (sourceIdx, sourceLine) in sourceLines.enumerated() {
            if processedIndices.contains(sourceIdx) { continue }
            
            let diff: LineDiff
            
            // Check if this line is part of a patch
            if let patch = patches.first(where: {
                if case .deletion(let at) = $0 { return at == sourceIdx }
                return false
            }) {
                // Find the best matching target line
                if let (targetLine, similarity) = findBestMatch(
                    sourceLine: sourceLine.text,
                    in: targetLinesText,
                    threshold: isCode ? 0.5 : 0.3
                ) {
                    diff = createLineDiff(
                        sourceLine: sourceLine,
                        targetLine: targetLine,
                        lineNumber: sourceIdx,
                        similarity: similarity
                    )
                } else {
                    // No match found - pure deletion
                    diff = LineDiff(
                        range: sourceLine.range,
                        wordDiffs: [WordDiff(range: sourceLine.range, type: .deletion)],
                        isDifferent: true,
                        lineNumber: sourceIdx
                    )
                }
            } else {
                // Line wasn't part of any patch - check if it's unchanged
                if targetLinesText.contains(sourceLine.text) {
                    diff = LineDiff(
                        range: sourceLine.range,
                        wordDiffs: [],
                        isDifferent: false,
                        lineNumber: sourceIdx
                    )
                } else {
                    // Try to find a similar line
                    if let (targetLine, similarity) = findBestMatch(
                        sourceLine: sourceLine.text,
                        in: targetLinesText,
                        threshold: isCode ? 0.5 : 0.3
                    ) {
                        diff = createLineDiff(
                            sourceLine: sourceLine,
                            targetLine: targetLine,
                            lineNumber: sourceIdx,
                            similarity: similarity
                        )
                    } else {
                        diff = LineDiff(
                            range: sourceLine.range,
                            wordDiffs: [WordDiff(range: sourceLine.range, type: .deletion)],
                            isDifferent: true,
                            lineNumber: sourceIdx
                        )
                    }
                }
            }
            
            processedIndices.insert(sourceIdx)
            lineDiffs.append(diff)
        }
        
        return lineDiffs.sorted { $0.lineNumber < $1.lineNumber }
    }
    
    private func createLineDiff(
        sourceLine: Line,
        targetLine: String,
        lineNumber: Int,
        similarity: Double
    ) -> LineDiff {
        let wordDiffs = computeWordDiffs(
            sourceLine: sourceLine,
            targetLine: targetLine,
            similarity: similarity
        )
        
        return LineDiff(
            range: sourceLine.range,
            wordDiffs: wordDiffs,
            isDifferent: !wordDiffs.isEmpty,
            lineNumber: lineNumber
        )
    }
    
    private func findBestMatch(
        sourceLine: String,
        in targetLines: [String],
        threshold: Double
    ) -> (line: String, similarity: Double)? {
        var bestMatch: (line: String, similarity: Double) = ("", 0)
        
        for targetLine in targetLines {
            let similarity = calculateSimilarity(
                source: sourceLine,
                target: targetLine
            )
            
            if similarity > bestMatch.similarity {
                bestMatch = (targetLine, similarity)
            }
        }
        
        return bestMatch.similarity >= threshold ? bestMatch : nil
    }
    
    private func calculateSimilarity(source: String, target: String) -> Double {
        let sourceTokens = tokenize(source)
        let targetTokens = tokenize(target)
        
        // Handle empty cases
        guard !sourceTokens.isEmpty && !targetTokens.isEmpty else {
            return sourceTokens.isEmpty && targetTokens.isEmpty ? 1.0 : 0.0
        }
        
        if isCode {
            return calculateCodeSimilarity(sourceTokens, targetTokens)
        } else {
            return calculateTextSimilarity(sourceTokens, targetTokens)
        }
    }
    
    private func calculateCodeSimilarity(
        _ sourceTokens: [Token],
        _ targetTokens: [Token]
    ) -> Double {
        // Filter out whitespace and normalize tokens
        let source = sourceTokens.filter { $0.type != .whitespace }.map { $0.normalized }
        let target = targetTokens.filter { $0.type != .whitespace }.map { $0.normalized }
        
        let patches = patch(from: source, to: target)
        let changes = patches.count
        let maxLength = Double(max(source.count, target.count))
        
        return 1.0 - (Double(changes) / maxLength)
    }
    
    private func calculateTextSimilarity(
        _ sourceTokens: [Token],
        _ targetTokens: [Token]
    ) -> Double {
        let source = Set(sourceTokens.filter { $0.type != .whitespace }.map { $0.normalized })
        let target = Set(targetTokens.filter { $0.type != .whitespace }.map { $0.normalized })
        
        let intersection = source.intersection(target)
        let union = source.union(target)
        
        return Double(intersection.count) / Double(union.count)
    }
    
    private func computeWordDiffs(
            sourceLine: Line,
            targetLine: String,
            similarity: Double
        ) -> [WordDiff] {
            let sourceTokenLocations = getTokenLocations(text: sourceLine.text, startingAt: sourceLine.range.location)
            let targetTokenLocations = getTokenLocations(text: targetLine, startingAt: sourceLine.range.location)
            
            // Create mapping of normalized tokens to their original tokens and locations
            var sourceMap: [String: [(token: Token, range: NSRange)]] = [:]
            for loc in sourceTokenLocations {
                sourceMap[loc.token.normalized, default: []].append((loc.token, loc.range))
            }
            
            var targetMap: [String: [(token: Token, range: NSRange)]] = [:]
            for loc in targetTokenLocations {
                targetMap[loc.token.normalized, default: []].append((loc.token, loc.range))
            }
            
            var wordDiffs: [WordDiff] = []
            var processedSourceLocations = Set<Int>()
            
            // Process source tokens
            for sourceLocation in sourceTokenLocations {
                guard sourceLocation.token.type != .whitespace else { continue }
                
                let sourceNormalized = sourceLocation.token.normalized
                
                // Skip if we've already processed this location
                guard !processedSourceLocations.contains(sourceLocation.range.location) else { continue }
                processedSourceLocations.insert(sourceLocation.range.location)
                
                // Check if this token exists in the target
                if let targetMatches = targetMap[sourceNormalized], !targetMatches.isEmpty {
                    // Token exists in both source and target - check if it's in the same position
                    let sourcePosRatio = Double(sourceLocation.range.location - sourceLine.range.location) /
                                       Double(sourceLine.range.length)
                    
                    var bestMatch: (ratio: Double, match: (token: Token, range: NSRange))?
                    for targetMatch in targetMatches {
                        let targetPosRatio = Double(targetMatch.range.location - sourceLine.range.location) /
                                           Double(targetLine.utf16.count)
                        let posDiff = abs(sourcePosRatio - targetPosRatio)
                        
                        if bestMatch == nil || posDiff < bestMatch!.ratio {
                            bestMatch = (posDiff, targetMatch)
                        }
                    }
                    
                    // If position difference is significant, mark as modification
                    if let best = bestMatch, best.ratio > 0.3 {
                        wordDiffs.append(WordDiff(
                            range: sourceLocation.range,
                            type: .modification
                        ))
                    }
                } else {
                    // Token doesn't exist in target - it's a deletion or modification
                    wordDiffs.append(WordDiff(
                        range: sourceLocation.range,
                        type: .modification
                    ))
                }
            }
            
            // Handle code-specific cases
            if isCode {
                // For code, we want to be more precise about operator and punctuation changes
                let sourceOperators = Set(sourceTokenLocations
                    .filter { $0.token.type == .operator || $0.token.type == .punctuation }
                    .map { $0.token.normalized })
                
                let targetOperators = Set(targetTokenLocations
                    .filter { $0.token.type == .operator || $0.token.type == .punctuation }
                    .map { $0.token.normalized })
                
                // Add operator/punctuation differences
                for sourceLocation in sourceTokenLocations where
                    (sourceLocation.token.type == .operator || sourceLocation.token.type == .punctuation) {
                    if !targetOperators.contains(sourceLocation.token.normalized) {
                        wordDiffs.append(WordDiff(
                            range: sourceLocation.range,
                            type: .modification
                        ))
                    }
                }
            }
            
            return wordDiffs.sorted { $0.range.location < $1.range.location }
        }
}

extension DiffAnalyzer {
    private struct TokenLocation {
        let token: Token
        let range: NSRange
    }
    
    // Remove the duplicate computeWordDiffs and use this updated version
    
    private func getTokenLocations(text: String, startingAt: Int) -> [TokenLocation] {
        var locations: [TokenLocation] = []
        var currentLocation = startingAt
        
        let tokens = tokenize(text)
        
        for token in tokens {
            let length = token.text.utf16.count
            locations.append(TokenLocation(
                token: token,
                range: NSRange(location: currentLocation, length: length)
            ))
            currentLocation += length
        }
        
        return locations
    }
    
    private func tokenize(_ text: String) -> [Token] {
        if isCode {
            return tokenizeCode(text)
        } else {
            return tokenizeText(text)
        }
    }
    
    private func tokenizeCode(_ text: String) -> [Token] {
        var tokens: [Token] = []
        var currentToken = ""
        var currentType: TokenType?
        var index = text.startIndex
        
        func appendCurrentToken() {
            guard !currentToken.isEmpty else { return }
            tokens.append(createToken(currentToken, currentType ?? .other))
            currentToken = ""
            currentType = nil
        }
        
        while index < text.endIndex {
            let char = text[index]
            
            // Handle string literals
            if char == "\"" || char == "'" {
                appendCurrentToken()
                var stringLiteral = String(char)
                index = text.index(after: index)
                
                while index < text.endIndex {
                    let nextChar = text[index]
                    stringLiteral.append(nextChar)
                    index = text.index(after: index)
                    if nextChar == char { break }
                }
                
                tokens.append(createToken(stringLiteral, .string))
                continue
            }
            
            // Handle whitespace
            if char.isWhitespace {
                appendCurrentToken()
                currentToken = String(char)
                currentType = .whitespace
                appendCurrentToken()
            }
            // Handle operators and punctuation
            else if "=><&|+-*/%!~^.,:;(){}[]".contains(char) {
                appendCurrentToken()
                currentToken = String(char)
                currentType = .operator
                appendCurrentToken()
            }
            // Handle identifiers and keywords
            else {
                if currentType == nil {
                    currentType = .word
                }
                currentToken.append(char)
            }
            
            index = text.index(after: index)
        }
        
        appendCurrentToken()
        return tokens
    }
    
    private func tokenizeText(_ text: String) -> [Token] {
        var tokens: [Token] = []
        var currentWord = ""
        var scalars = text.unicodeScalars.makeIterator()
        
        // Helper function to check if scalar is punctuation
        func isPunctuation(_ scalar: Unicode.Scalar) -> Bool {
            switch scalar.properties.generalCategory {
            case .openPunctuation, .closePunctuation,
                    .initialPunctuation, .finalPunctuation,
                    .connectorPunctuation, .dashPunctuation,
                    .otherPunctuation:
                return true
            default:
                return false
            }
        }
        
        // Helper function to check if scalar is emoji
        func isEmoji(_ scalar: Unicode.Scalar) -> Bool {
            scalar.properties.generalCategory == .otherSymbol ||
            (scalar.properties.generalCategory == .otherLetter &&
             scalar.value >= 0x1F3FB && scalar.value <= 0x1F3FF)
        }
        
        func appendWord() {
            if !currentWord.isEmpty {
                tokens.append(createToken(currentWord, .word))
                currentWord = ""
            }
        }
        
        while let scalar = scalars.next() {
            if isEmoji(scalar) {
                appendWord()
                tokens.append(createToken(String(scalar), .emoji))
            }
            else if scalar.properties.isWhitespace {
                appendWord()
                tokens.append(createToken(String(scalar), .whitespace))
            }
            else if isPunctuation(scalar) {
                appendWord()
                tokens.append(createToken(String(scalar), .punctuation))
            }
            else {
                currentWord.append(Character(scalar))
            }
        }
        
        appendWord()
        return tokens
    }
    
    private func createToken(_ text: String, _ type: TokenType) -> Token {
        Token(
            text: text,
            normalized: normalizeToken(text, type),
            type: type
        )
    }
    
    private func normalizeToken(_ text: String, _ type: TokenType) -> String {
        switch type {
        case .word:
            return text.lowercased()
        case .emoji, .punctuation, .operator, .string:
            return text
        case .whitespace:
            return " "
        default:
            return text
        }
    }
}
