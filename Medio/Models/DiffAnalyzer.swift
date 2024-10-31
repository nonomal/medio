import Foundation

final class DiffAnalyzer {
    private let sourceText: String
    private let targetText: String
    private let sourceLines: [(String, NSRange)]
    private let targetLines: [(String, NSRange)]
    private let isCode: Bool
    
    init(sourceText: String, targetText: String) {
        self.sourceText = sourceText
        self.targetText = targetText
        self.sourceLines = Self.getLinesWithRanges(sourceText)
        self.targetLines = Self.getLinesWithRanges(targetText)
        self.isCode = CodeAnalyzer.detectCodeContent(sourceText)
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
        let sourceNormalized = CodeAnalyzer.normalizeCodeLine(sourceLine)
        
        for (index, (targetLine, _)) in targetLines.enumerated() {
            guard !processedLines.contains(index) else { continue }
            let targetNormalized = CodeAnalyzer.normalizeCodeLine(targetLine)
            if sourceNormalized == targetNormalized {
                return index
            }
        }
        return nil
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
        let sourceTokens = Tokenizer.tokenize(sourceLine, isCode: isCode)
        var bestMatch: (index: Int, score: Double) = (-1, 0.0)
        let threshold = isCode ? 0.5 : 0.3
        
        for (index, (targetLine, _)) in targetLines.enumerated() {
            guard !processedLines.contains(index) else { continue }
            let targetTokens = Tokenizer.tokenize(targetLine, isCode: isCode)
            let similarity = SimilarityCalculator.calculateSimilarity(
                source: sourceTokens,
                target: targetTokens,
                isCode: isCode
            )
            
            if similarity > bestMatch.score {
                bestMatch = (index, similarity)
            }
        }
        
        return bestMatch.score > threshold ? bestMatch.index : nil
    }
    
    private func compareLines(sourceLine: String,
                            targetLine: String,
                            sourceStartLocation: Int,
                            totalLength: Int) -> [WordDiff] {
        guard !sourceLine.isEmpty && !targetLine.isEmpty && totalLength > 0 else {
            return []
        }
        
        let sourceTokens = Tokenizer.tokenize(sourceLine, isCode: isCode)
        let targetTokens = Tokenizer.tokenize(targetLine, isCode: isCode)
        
        guard !sourceTokens.isEmpty else { return [] }
        
        var diffs: [WordDiff] = []
        var currentLocation = 0
        
        // Initialize sequence matchers for optimized token comparison
        let sourceSequence = sourceTokens.filter { $0.type != .whitespace }
        let targetSequence = targetTokens.filter { $0.type != .whitespace }
        let matchingIndices = findMatchingTokenIndices(sourceSequence, targetSequence)
        
        for sourceToken in sourceTokens {
            // Ensure we don't exceed bounds
            guard currentLocation < totalLength else { break }
            
            let tokenLength = min(sourceToken.text.utf16.count, totalLength - currentLocation)
            guard tokenLength > 0 else { continue }
            
            let tokenLocation = sourceStartLocation + currentLocation
            
            if sourceToken.type != .whitespace {
                let isMatched = doesTokenMatch(sourceToken, in: targetTokens)
                if !isMatched {
                    // Ensure range is valid
                    let safeLength = min(tokenLength, totalLength - tokenLocation)
                    guard safeLength > 0 else { continue }
                    
                    diffs.append(WordDiff(
                        range: NSRange(location: tokenLocation, length: safeLength),
                        type: determineModificationType(sourceToken, targetTokens)
                    ))
                }
            }
            
            currentLocation += tokenLength
        }
        
        return diffs
    }
    
    private func findMatchingTokenIndices(_ source: [TextToken], _ target: [TextToken]) -> Set<Int> {
        var matchingIndices = Set<Int>()
        var processed = Set<Int>()
        
        for (sourceIdx, sourceToken) in source.enumerated() {
            for (targetIdx, targetToken) in target.enumerated() {
                guard !processed.contains(targetIdx) else { continue }
                
                if tokensMatch(sourceToken, targetToken) {
                    matchingIndices.insert(sourceIdx)
                    processed.insert(targetIdx)
                    break
                }
            }
        }
        
        return matchingIndices
    }
    
    private func tokensMatch(_ source: TextToken, _ target: TextToken) -> Bool {
        if isCode {
            return source.normalized == target.normalized && source.type == target.type
        } else {
            return source.normalized == target.normalized
        }
    }
    
    private func doesTokenMatch(_ sourceToken: TextToken, in targetTokens: [TextToken]) -> Bool {
        targetTokens.contains { targetToken in
            tokensMatch(sourceToken, targetToken)
        }
    }
    
    private func determineModificationType(_ sourceToken: TextToken, _ targetTokens: [TextToken]) -> DiffType {
        // For code, we want to be more specific about the type of change
        if isCode {
            let similarTokens = targetTokens.filter { token in
                token.type == sourceToken.type &&
                token.normalized.count > 2 &&
                (token.normalized.contains(sourceToken.normalized) ||
                 sourceToken.normalized.contains(token.normalized))
            }
            
            if !similarTokens.isEmpty {
                return .modification
            }
        }
        
        // Default to deletion for the left side (will be treated as addition on right side)
        return .deletion
    }
}
