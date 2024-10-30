// Utils/DiffAnalyzer.swift
import Foundation

class DiffAnalyzer {
    private let sourceText: String
    private let targetText: String
    private let language: CodeLanguage
    
    init(sourceText: String, targetText: String) {
        self.sourceText = sourceText
        self.targetText = targetText
        self.language = CodeLanguage.detect(from: sourceText)
    }
    
    private func getLinesWithRanges(_ text: String) -> [(String, NSRange)] {
        var lines: [(String, NSRange)] = []
        var currentLocation = 0
        
        let lineComponents = text.components(separatedBy: .newlines)
        
        for (index, line) in lineComponents.enumerated() {
            let lineLength = line.count
            let range = NSRange(location: currentLocation, length: lineLength)
            lines.append((line, range))
            
            currentLocation += lineLength + (index < lineComponents.count - 1 ? 1 : 0)
        }
        
        return lines
    }
    
    private func splitIntoTokens(_ text: String, lineStartLocation: Int) -> [(String, NSRange)] {
        let tokens = StringUtils.tokenizeCode(text)
        var result: [(String, NSRange)] = []
        var currentLocation = lineStartLocation
        
        for token in tokens {
            let range = NSRange(location: currentLocation, length: token.count)
            result.append((token, range))
            currentLocation += token.count
        }
        
        return result
    }
    
    private func isCompleteStatement(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for import statements
        if trimmedLine.starts(with: "import ") {
            return true
        }
        
        // Check for complete variable declarations
        if language == .javascript && (
            trimmedLine.starts(with: "const ") ||
            trimmedLine.starts(with: "let ") ||
            trimmedLine.starts(with: "var ")
        ) && trimmedLine.contains("=") {
            return true
        }
        
        // Check for function declarations
        if trimmedLine.starts(with: "function ") || trimmedLine.starts(with: "const ") && trimmedLine.contains("=>") {
            return true
        }
        
        // Check for export statements
        if trimmedLine.starts(with: "export ") {
            return true
        }
        
        return false
    }
    
    private func findMatchingStatement(_ sourceLine: String, in targetLines: [(String, NSRange)]) -> Int? {
        let trimmedSource = sourceLine.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Special handling for import statements
        if trimmedSource.starts(with: "import ") {
            for (index, (targetLine, _)) in targetLines.enumerated() {
                let trimmedTarget = targetLine.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedTarget.starts(with: "import ") {
                    // Extract main module name for comparison
                    let sourceModule = trimmedSource.split(separator: " ")[1].split(separator: ",")[0]
                    let targetModule = trimmedTarget.split(separator: " ")[1].split(separator: ",")[0]
                    if sourceModule == targetModule {
                        return index
                    }
                }
            }
            return nil
        }
        
        // Handle other statement types
        let sourceTokens = Set(StringUtils.tokenizeCode(sourceLine))
        for (index, (targetLine, _)) in targetLines.enumerated() {
            let targetTokens = Set(StringUtils.tokenizeCode(targetLine))
            
            // For variable declarations, compare the variable names
            if trimmedSource.starts(with: "const ") || trimmedSource.starts(with: "let ") || trimmedSource.starts(with: "var ") {
                let sourceVarName = sourceTokens.first { !["const", "let", "var"].contains($0) }
                let targetVarName = targetTokens.first { !["const", "let", "var"].contains($0) }
                if sourceVarName == targetVarName {
                    return index
                }
            }
            
            // For other statements, check significant token overlap
            let commonTokens = sourceTokens.intersection(targetTokens)
            let similarity = Double(commonTokens.count) / Double(sourceTokens.count)
            if similarity > 0.7 {
                return index
            }
        }
        
        return nil
    }
    
    private func compareStatements(_ source: String, _ target: String, sourceStartLocation: Int) -> [WordDiff] {
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle import statements
        if trimmedSource.starts(with: "import ") {
            return StatementAnalyzer.compareImportStatements(source, target, sourceStartLocation: sourceStartLocation)
        }
        
        // Handle variable declarations
        if trimmedSource.starts(with: "const ") || trimmedSource.starts(with: "let ") || trimmedSource.starts(with: "var ") {
            let sourceTokens = splitIntoTokens(source, lineStartLocation: sourceStartLocation)
            let targetTokens = splitIntoTokens(target, lineStartLocation: sourceStartLocation)
            
            var diffs: [WordDiff] = []
            var i = 0
            while i < sourceTokens.count {
                let sourceToken = sourceTokens[i]
                let tokenText = sourceToken.0.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Skip declaration keyword and variable name
                if ["const", "let", "var"].contains(tokenText) || i == 1 {
                    i += 1
                    continue
                }
                
                // Compare the rest of the declaration
                if !targetTokens.contains(where: { $0.0 == sourceToken.0 }) {
                    var diffLength = sourceToken.0.count
                    let nextIndex = i + 1
                    
                    // Look ahead for consecutive differences
                    while nextIndex < sourceTokens.count {
                        let nextToken = sourceTokens[nextIndex]
                        if !targetTokens.contains(where: { $0.0 == nextToken.0 }) {
                            diffLength = nextToken.1.location + nextToken.1.length - sourceToken.1.location
                            i = nextIndex
                        }
                        break
                    }
                    
                    diffs.append(WordDiff(
                        range: NSRange(
                            location: sourceToken.1.location,
                            length: diffLength
                        ),
                        type: .modification
                    ))
                }
                i += 1
            }
            return diffs
        }
        
        return []
    }
    
    func computeDifferences() -> [LineDiff] {
        var lineDiffs: [LineDiff] = []
        let sourceLines = getLinesWithRanges(sourceText)
        let targetLines = getLinesWithRanges(targetText)
        
        var processedTargetLines = Set<Int>()
        
        for (lineIndex, (sourceLine, lineRange)) in sourceLines.enumerated() {
            var wordDiffs: [WordDiff] = []
            _ = sourceLine.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if isCompleteStatement(sourceLine) {
                if let matchingIndex = findMatchingStatement(sourceLine, in: targetLines) {
                    processedTargetLines.insert(matchingIndex)
                    let (targetLine, _) = targetLines[matchingIndex]
                    
                    // Compare statements granularly
                    wordDiffs = compareStatements(
                        sourceLine,
                        targetLine,
                        sourceStartLocation: lineRange.location
                    )
                } else {
                    // No matching statement found, mark entire line as deletion
                    wordDiffs.append(WordDiff(range: lineRange, type: .deletion))
                }
            } else {
                // Handle non-statement lines with token-based diff
                var bestMatchIndex = -1
                var bestMatchScore = 0.0
                
                for (targetIndex, (targetLine, _)) in targetLines.enumerated() {
                    if processedTargetLines.contains(targetIndex) {
                        continue
                    }
                    
                    let sourceTokens = Set(StringUtils.tokenizeCode(sourceLine))
                    let targetTokens = Set(StringUtils.tokenizeCode(targetLine))
                    
                    let commonTokens = sourceTokens.intersection(targetTokens)
                    let totalTokens = sourceTokens.union(targetTokens)
                    
                    if !totalTokens.isEmpty {
                        let keywordWeight = 1.5
                        let weightedCommonCount = commonTokens.reduce(0.0) { sum, token in
                            sum + (language.keywords.contains(token) ? keywordWeight : 1.0)
                        }
                        let weightedTotalCount = totalTokens.reduce(0.0) { sum, token in
                            sum + (language.keywords.contains(token) ? keywordWeight : 1.0)
                        }
                        
                        let similarity = weightedCommonCount / weightedTotalCount
                        if similarity > bestMatchScore {
                            bestMatchScore = similarity
                            bestMatchIndex = targetIndex
                        }
                    }
                }
                
                let sourceTokens = splitIntoTokens(sourceLine, lineStartLocation: lineRange.location)
                
                if bestMatchScore > 0.3 && bestMatchIndex != -1 {
                    processedTargetLines.insert(bestMatchIndex)
                    let (targetLine, _) = targetLines[bestMatchIndex]
                    let targetTokens = splitIntoTokens(targetLine, lineStartLocation: lineRange.location)
                    
                    var i = 0
                    while i < sourceTokens.count {
                        let sourceToken = sourceTokens[i]
                        
                        if sourceToken.0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            i += 1
                            continue
                        }
                        
                        let isKeyword = language.keywords.contains(sourceToken.0)
                        let foundInTarget = targetTokens.contains { targetToken in
                            if isKeyword {
                                return sourceToken.0 == targetToken.0
                            } else {
                                return StringUtils.compareStrings(sourceToken.0, targetToken.0)
                            }
                        }
                        
                        if !foundInTarget {
                            var diffLength = sourceToken.0.count
                            var nextIndex = i + 1
                            
                            while nextIndex < sourceTokens.count {
                                let nextToken = sourceTokens[nextIndex]
                                
                                if nextToken.0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    diffLength += nextToken.0.count
                                    nextIndex += 1
                                    continue
                                }
                                
                                let nextIsKeyword = language.keywords.contains(nextToken.0)
                                let foundNextInTarget = targetTokens.contains { targetToken in
                                    if nextIsKeyword {
                                        return nextToken.0 == targetToken.0
                                    } else {
                                        return StringUtils.compareStrings(nextToken.0, targetToken.0)
                                    }
                                }
                                
                                if !foundNextInTarget {
                                    diffLength = nextToken.1.location + nextToken.1.length - sourceToken.1.location
                                    i = nextIndex
                                }
                                break
                            }
                            
                            wordDiffs.append(WordDiff(
                                range: NSRange(
                                    location: sourceToken.1.location,
                                    length: diffLength
                                ),
                                type: .modification
                            ))
                        }
                        i += 1
                    }
                } else if !sourceLine.isEmpty {
                    wordDiffs.append(WordDiff(range: lineRange, type: .deletion))
                }
            }
            
            lineDiffs.append(LineDiff(
                range: lineRange,
                wordDiffs: wordDiffs,
                isDifferent: !wordDiffs.isEmpty,
                lineNumber: lineIndex
            ))
        }
        
        return lineDiffs
    }
}
