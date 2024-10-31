import Foundation

final class DiffAnalyzer {
    private let sourceText: String
    private let targetText: String
    private let sourceLines: [(String, NSRange)]
    private let targetLines: [(String, NSRange)]
    
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
        return sourceLines.enumerated().map { (lineIndex, lineInfo) -> LineDiff in
            let (sourceLine, lineRange) = lineInfo
            let wordDiffs = computeWordDiffs(sourceLine: sourceLine,
                                           lineRange: lineRange,
                                           processedTargetLines: &processedTargetLines)
            
            return LineDiff(
                range: lineRange,
                wordDiffs: wordDiffs,
                isDifferent: !wordDiffs.isEmpty,
                lineNumber: lineIndex
            )
        }
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
            return compareLines(sourceLine: sourceLine,
                              targetLine: targetLines[matchIndex].0,
                              sourceStartLocation: lineRange.location)
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
            let similarity = Double(commonTokens.count) / Double(sourceTokens.union(targetTokens).count)
            
            if similarity > bestMatch.score {
                bestMatch = (index, similarity)
            }
        }
        
        return bestMatch.score > 0.3 ? bestMatch.index : nil
    }
    
    private func compareLines(sourceLine: String,
                            targetLine: String,
                            sourceStartLocation: Int) -> [WordDiff] {
        let sourceTokens = StringUtils.tokenizeCode(sourceLine)
        let targetTokens = Set(StringUtils.tokenizeCode(targetLine))
        var diffs: [WordDiff] = []
        var currentLocation = sourceStartLocation
        
        for token in sourceTokens {
            let tokenLength = token.count
            if !targetTokens.contains(token) && !token.trimmingCharacters(in: .whitespaces).isEmpty {
                diffs.append(WordDiff(
                    range: NSRange(location: currentLocation, length: tokenLength),
                    type: .modification
                ))
            }
            currentLocation += tokenLength
        }
        
        return diffs
    }
}
