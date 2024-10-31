import Foundation

final class DiffAnalyzer {
    private let sourceText: String
    private let targetText: String
    private let sourceLines: [(String, NSRange)]
    private let targetLines: [(String, NSRange)]
    
    // Threshold values for matching
    private let similarityThreshold = 0.3
    private let exactMatchThreshold = 0.9
    private let structureWeight = 0.4
    private let contentWeight = 0.6
    
    init(sourceText: String, targetText: String) {
        self.sourceText = sourceText
        self.targetText = targetText
        self.sourceLines = Self.getLinesWithRanges(sourceText)
        self.targetLines = Self.getLinesWithRanges(targetText)
    }
    
    private static func getLinesWithRanges(_ text: String) -> [(String, NSRange)] {
        text.components(separatedBy: .newlines).reduce(into: [(String, NSRange)]()) { result, line in
            let currentLocation = result.last.map { $0.1.location + $0.1.length + 1 } ?? 0
            result.append((line, NSRange(location: currentLocation, length: line.count)))
        }
    }
    
    func computeDifferences() -> [LineDiff] {
        var processedTargetLines = Set<Int>()
        var lineMatchCache: [Int: Int] = [:] // Cache for line matches
        
        // First pass: Find exact matches and build initial mapping
        for (sourceIdx, sourceLine) in sourceLines.enumerated() {
            if let matchIdx = findExactMatch(for: sourceLine.0, in: targetLines, processedLines: processedTargetLines) {
                lineMatchCache[sourceIdx] = matchIdx
                processedTargetLines.insert(matchIdx)
            }
        }
        
        // Second pass: Process remaining lines with fuzzy matching
        return sourceLines.enumerated().map { (lineIndex, lineInfo) -> LineDiff in
            let (sourceLine, lineRange) = lineInfo
            
            // If we have an exact match from the first pass, use it
            if let matchedIndex = lineMatchCache[lineIndex] {
                let wordDiffs = compareLines(
                    sourceLine: sourceLine,
                    targetLine: targetLines[matchedIndex].0,
                    sourceStartLocation: lineRange.location,
                    useStructuralMatching: true
                )
                return LineDiff(
                    range: lineRange,
                    wordDiffs: wordDiffs,
                    isDifferent: !wordDiffs.isEmpty,
                    lineNumber: lineIndex
                )
            }
            
            // Otherwise, try fuzzy matching
            let wordDiffs = computeWordDiffs(
                sourceLine: sourceLine,
                lineRange: lineRange,
                processedTargetLines: &processedTargetLines
            )
            
            return LineDiff(
                range: lineRange,
                wordDiffs: wordDiffs,
                isDifferent: !wordDiffs.isEmpty,
                lineNumber: lineIndex
            )
        }
    }
    
    private func findExactMatch(for sourceLine: String,
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
        // Remove whitespace and comments for structural comparison
        line.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "//.*$", with: "", options: .regularExpression)
    }
    
    private func computeWordDiffs(sourceLine: String,
                                lineRange: NSRange,
                                processedTargetLines: inout Set<Int>) -> [WordDiff] {
        let trimmedSource = sourceLine.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedSource.isEmpty { return [] }
        
        if let matchIndex = findBestMatch(for: sourceLine,
                                        in: targetLines,
                                        processedLines: processedTargetLines) {
            processedTargetLines.insert(matchIndex)
            return compareLines(
                sourceLine: sourceLine,
                targetLine: targetLines[matchIndex].0,
                sourceStartLocation: lineRange.location,
                useStructuralMatching: false
            )
        }
        
        return [WordDiff(range: lineRange, type: .deletion)]
    }
    
    private func findBestMatch(for sourceLine: String,
                             in targetLines: [(String, NSRange)],
                             processedLines: Set<Int>) -> Int? {
        let sourceTokens = Set(StringUtils.tokenizeCode(sourceLine))
        var bestMatch: (index: Int, score: Double) = (-1, 0.0)
        
        for (index, (targetLine, _)) in targetLines.enumerated() {
            guard !processedLines.contains(index) else { continue }
            
            let targetTokens = Set(StringUtils.tokenizeCode(targetLine))
            let commonTokens = sourceTokens.intersection(targetTokens)
            
            // Calculate structural similarity
            let structuralSimilarity = calculateStructuralSimilarity(sourceLine, targetLine)
            
            // Calculate content similarity
            let contentSimilarity = Double(commonTokens.count) / Double(sourceTokens.union(targetTokens).count)
            
            // Weighted combination of structural and content similarity
            let totalSimilarity = (structuralSimilarity * structureWeight) + (contentSimilarity * contentWeight)
            
            if totalSimilarity > bestMatch.score {
                bestMatch = (index, totalSimilarity)
            }
        }
        
        return bestMatch.score > similarityThreshold ? bestMatch.index : nil
    }
    
    private func calculateStructuralSimilarity(_ source: String, _ target: String) -> Double {
        let sourceStructure = extractCodeStructure(source)
        let targetStructure = extractCodeStructure(target)
        
        let maxLength = Double(max(sourceStructure.count, targetStructure.count))
        guard maxLength > 0 else { return 1.0 }
        
        let commonElements = sourceStructure.filter { targetStructure.contains($0) }
        return Double(commonElements.count) / maxLength
    }
    
    private func extractCodeStructure(_ line: String) -> [String] {
        // Extract key structural elements like brackets, operators, etc.
        let structuralPattern = "([{}()\\[\\].,;:]|=>|==|!=|>=|<=|\\+=|-=|\\*=|/=|&&|\\|\\||\\+\\+|--)"
        let regex = try? NSRegularExpression(pattern: structuralPattern, options: [])
        let range = NSRange(location: 0, length: line.utf16.count)
        let matches = regex?.matches(in: line, options: [], range: range) ?? []
        
        return matches.compactMap { match in
            Range(match.range, in: line).map { String(line[$0]) }
        }
    }
    
    private func compareLines(sourceLine: String,
                            targetLine: String,
                            sourceStartLocation: Int,
                            useStructuralMatching: Bool) -> [WordDiff] {
        let sourceTokens = StringUtils.tokenizeCode(sourceLine)
        let targetTokens = StringUtils.tokenizeCode(targetLine)
        var diffs: [WordDiff] = []
        var currentLocation = sourceStartLocation
        
        let sourceStructure = useStructuralMatching ? extractCodeStructure(sourceLine) : []
        let targetStructure = useStructuralMatching ? extractCodeStructure(targetLine) : []
        
        for token in sourceTokens {
            let tokenLength = token.count
            let trimmedToken = token.trimmingCharacters(in: .whitespaces)
            
            if !trimmedToken.isEmpty {
                let isStructuralElement = sourceStructure.contains(trimmedToken)
                let isInTarget = targetTokens.contains(token)
                let isStructuralMatch = isStructuralElement && targetStructure.contains(trimmedToken)
                
                if !isInTarget || (useStructuralMatching && isStructuralElement && !isStructuralMatch) {
                    diffs.append(WordDiff(
                        range: NSRange(location: currentLocation, length: tokenLength),
                        type: .modification
                    ))
                }
            }
            currentLocation += tokenLength
        }
        
        return diffs
    }
}
