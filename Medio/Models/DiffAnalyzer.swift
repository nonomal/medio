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
        let lines = text.components(separatedBy: .newlines)
        return lines.map { line in
            let length = line.utf16.count
            let range = NSRange(location: currentLocation, length: length)
            currentLocation += length + 1 // +1 for newline character
            return Line(text: line, range: range)
        }
    }
    
    func computeDifferences() -> [LineDiff] {
        let sourceLinesText = sourceLines.map { $0.text }
        let targetLinesText = targetLines.map { $0.text }
        
        // Use patch instead of diff for safer index handling
        let patches = patch(from: sourceLinesText, to: targetLinesText)
        var lineDiffs: [LineDiff] = []
        var processedIndices = Set<Int>()
        
        // Handle patches
        for p in patches {
            switch p {
            case let .deletion(at):
                guard at < sourceLines.count else { continue }
                processedIndices.insert(at)
                let sourceLine = sourceLines[at]
                
                // Check if this is a modification by looking for similar line
                if let targetLine = findSimilarLine(sourceLine.text, in: targetLinesText) {
                    let wordDiffs = computeWordDiffs(sourceLine: sourceLine, targetText: targetLine)
                    lineDiffs.append(LineDiff(
                        range: sourceLine.range,
                        wordDiffs: wordDiffs,
                        isDifferent: !wordDiffs.isEmpty,
                        lineNumber: at
                    ))
                } else {
                    // Pure deletion
                    lineDiffs.append(LineDiff(
                        range: sourceLine.range,
                        wordDiffs: [WordDiff(range: sourceLine.range, type: .deletion)],
                        isDifferent: true,
                        lineNumber: at
                    ))
                }
                
            case .insertion:
                // Handled on target side
                continue
            }
        }
        
        // Handle unchanged lines
        for i in 0..<sourceLines.count {
            guard !processedIndices.contains(i) else { continue }
            
            let sourceLine = sourceLines[i]
            if targetLinesText.contains(sourceLine.text) {
                // Exact match - unchanged line
                lineDiffs.append(LineDiff(
                    range: sourceLine.range,
                    wordDiffs: [],
                    isDifferent: false,
                    lineNumber: i
                ))
            } else {
                // Check for similar line
                if let targetLine = findSimilarLine(sourceLine.text, in: targetLinesText) {
                    let wordDiffs = computeWordDiffs(sourceLine: sourceLine, targetText: targetLine)
                    lineDiffs.append(LineDiff(
                        range: sourceLine.range,
                        wordDiffs: wordDiffs,
                        isDifferent: !wordDiffs.isEmpty,
                        lineNumber: i
                    ))
                } else {
                    // No match found - mark as deletion
                    lineDiffs.append(LineDiff(
                        range: sourceLine.range,
                        wordDiffs: [WordDiff(range: sourceLine.range, type: .deletion)],
                        isDifferent: true,
                        lineNumber: i
                    ))
                }
            }
        }
        
        return lineDiffs.sorted { $0.lineNumber < $1.lineNumber }
    }
    
    private func findSimilarLine(_ sourceLine: String, in targetLines: [String]) -> String? {
        // Try exact match first
        if let exactMatch = targetLines.first(where: { $0 == sourceLine }) {
            return exactMatch
        }
        
        // Then try similarity matching
        let sourceWords = Set(tokenizeLine(sourceLine))
        var bestMatch: (text: String, similarity: Double) = ("", 0)
        
        for targetLine in targetLines {
            let targetWords = Set(tokenizeLine(targetLine))
            let commonWords = sourceWords.intersection(targetWords)
            let similarity = Double(commonWords.count) / Double(max(sourceWords.count, targetWords.count))
            
            if similarity > bestMatch.similarity && similarity > 0.3 {  // Lower threshold for better matching
                bestMatch = (targetLine, similarity)
            }
        }
        
        return bestMatch.similarity > 0 ? bestMatch.text : nil
    }
    
    private func computeWordDiffs(sourceLine: Line, targetText: String) -> [WordDiff] {
        let sourceWords = tokenizeLine(sourceLine.text)
        let targetWords = tokenizeLine(targetText)
        
        let patches = patch(from: sourceWords, to: targetWords)
        var wordDiffs: [WordDiff] = []
        var currentLocation = sourceLine.range.location
        var processedLocations = Set<Int>()
        
        for (index, word) in sourceWords.enumerated() {
            let wordLength = word.utf16.count
            let wordStart = currentLocation
            
            if patches.contains(where: { patch in
                if case .deletion(let at) = patch {
                    return at == index
                }
                return false
            }) {
                // This word was changed
                processedLocations.insert(wordStart)
                wordDiffs.append(WordDiff(
                    range: NSRange(location: wordStart, length: wordLength),
                    type: .modification
                ))
            }
            
            currentLocation += wordLength + (index < sourceWords.count - 1 ? 1 : 0)
        }
        
        return wordDiffs
    }
    
    private func tokenizeLine(_ line: String) -> [String] {
        if isCode {
            return StringUtils.tokenizeCode(line)
        } else {
            return line.components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
        }
    }
}
