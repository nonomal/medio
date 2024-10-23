import SwiftUI
import AppKit

enum DiffSide {
    case left
    case right
}

struct WordDiff {
    let range: NSRange
    let type: DiffType
}

enum DiffType {
    case addition
    case deletion
    case modification
}

struct LineDiff {
    let range: NSRange
    let wordDiffs: [WordDiff]
    let isDifferent: Bool
    let lineNumber: Int
}

struct DiffTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var comparisonText: String
    var side: DiffSide
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = CustomTextView()
        
        textView.allowsUndo = true
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        if !context.coordinator.isEditing && textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(selectedRange)
        }
        highlightDifferences(in: textView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func normalizeString(_ str: String) -> String {
        return str.decomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func compareStrings(_ str1: String, _ str2: String) -> Bool {
        let str1Clean = normalizeString(str1)
        let str2Clean = normalizeString(str2)
        return str1Clean == str2Clean
    }
    
    private func splitIntoWords(_ text: String, lineStartLocation: Int) -> [(String, NSRange)] {
        var words: [(String, NSRange)] = []
        let nsString = text as NSString
        let range = NSRange(location: 0, length: nsString.length)
        
        let tagger = NSLinguisticTagger(tagSchemes: [.tokenType], options: 0)
        tagger.string = text
        
        var lastLocation = 0
        
        tagger.enumerateTags(in: range, unit: .word, scheme: .tokenType, options: []) { tag, tokenRange, _ in
            let word = nsString.substring(with: tokenRange)
            
            // Adjust range to account for line start location
            if lastLocation < tokenRange.location {
                let whitespaceRange = NSRange(
                    location: lineStartLocation + lastLocation,
                    length: tokenRange.location - lastLocation
                )
                let whitespace = nsString.substring(with: NSRange(location: lastLocation, length: tokenRange.location - lastLocation))
                if !whitespace.isEmpty {
                    words.append((whitespace, whitespaceRange))
                }
            }
            
            if !word.isEmpty {
                let adjustedRange = NSRange(
                    location: lineStartLocation + tokenRange.location,
                    length: tokenRange.length
                )
                words.append((word, adjustedRange))
            }
            
            lastLocation = tokenRange.upperBound
        }
        
        if lastLocation < nsString.length {
            let whitespaceRange = NSRange(
                location: lineStartLocation + lastLocation,
                length: nsString.length - lastLocation
            )
            let whitespace = nsString.substring(with: NSRange(location: lastLocation, length: nsString.length - lastLocation))
            if !whitespace.isEmpty {
                words.append((whitespace, whitespaceRange))
            }
        }
        
        return words
    }
    
    private func getLinesWithRanges(_ text: String) -> [(String, NSRange)] {
        var lines: [(String, NSRange)] = []
        var currentLocation = 0
        
        let lineComponents = text.components(separatedBy: .newlines)
        
        for (index, line) in lineComponents.enumerated() {
            let lineLength = line.count
            let range = NSRange(location: currentLocation, length: lineLength)
            lines.append((line, range))
            
            // Add newline character length except for the last line
            currentLocation += lineLength + (index < lineComponents.count - 1 ? 1 : 0)
        }
        
        return lines
    }
    
    private func computeDifferences() -> [LineDiff] {
        var lineDiffs: [LineDiff] = []
        let sourceLines = getLinesWithRanges(text)
        let targetLines = getLinesWithRanges(comparisonText)
        
        for (lineIndex, (sourceLine, lineRange)) in sourceLines.enumerated() {
            var wordDiffs: [WordDiff] = []
            var bestMatchIndex = -1
            var bestMatchScore = 0.0
            
            // Find best matching line
            for (targetIndex, (targetLine, _)) in targetLines.enumerated() {
                let sourceWords = Set(sourceLine.components(separatedBy: .whitespacesAndNewlines))
                let targetWords = Set(targetLine.components(separatedBy: .whitespacesAndNewlines))
                
                let commonWords = sourceWords.intersection(targetWords)
                let totalWords = sourceWords.union(targetWords)
                
                if !totalWords.isEmpty {
                    let similarity = Double(commonWords.count) / Double(totalWords.count)
                    if similarity > bestMatchScore {
                        bestMatchScore = similarity
                        bestMatchIndex = targetIndex
                    }
                }
            }
            
            let sourceWords = splitIntoWords(sourceLine, lineStartLocation: lineRange.location)
            
            if bestMatchScore > 0.3 && bestMatchIndex != -1 {
                let (targetLine, _) = targetLines[bestMatchIndex]
                let targetWords = splitIntoWords(targetLine, lineStartLocation: lineRange.location)
                
                var i = 0
                while i < sourceWords.count {
                    let sourceWord = sourceWords[i]
                    
                    if sourceWord.0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        i += 1
                        continue
                    }
                    
                    var found = false
                    for targetWord in targetWords {
                        if compareStrings(sourceWord.0, targetWord.0) {
                            found = true
                            break
                        }
                    }
                    
                    if !found {
                        var diffLength = sourceWord.0.count
                        var nextIndex = i + 1
                        
                        // Look ahead for consecutive differences
                        while nextIndex < sourceWords.count {
                            let nextWord = sourceWords[nextIndex]
                            
                            // Include whitespace in the diff
                            if nextWord.0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                diffLength += nextWord.0.count
                                nextIndex += 1
                                continue
                            }
                            
                            var foundNext = false
                            for targetWord in targetWords {
                                if compareStrings(nextWord.0, targetWord.0) {
                                    foundNext = true
                                    break
                                }
                            }
                            
                            if !foundNext {
                                diffLength = nextWord.1.location + nextWord.1.length - sourceWord.1.location
                                i = nextIndex
                            }
                            break
                        }
                        
                        wordDiffs.append(WordDiff(
                            range: NSRange(
                                location: sourceWord.1.location,
                                length: diffLength
                            ),
                            type: .modification
                        ))
                    }
                    i += 1
                }
            } else if !sourceLine.isEmpty {
                // Line is completely different
                wordDiffs.append(WordDiff(range: lineRange, type: .deletion))
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
    
    private func highlightDifferences(in textView: NSTextView) {
        let attributedString = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: text.utf16.count)
        
        // Reset attributes
        attributedString.addAttributes([
            .foregroundColor: NSColor.labelColor,
            .backgroundColor: NSColor.clear,
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        ], range: fullRange)
        
        let diffs = computeDifferences()
        
        for lineDiff in diffs {
            guard lineDiff.range.location + lineDiff.range.length <= text.utf16.count else { continue }
            
            if lineDiff.isDifferent {
                // Light background for the whole line
                let backgroundColor = side == .left ?
                    NSColor.systemRed.withAlphaComponent(0.1) :
                    NSColor.systemGreen.withAlphaComponent(0.1)
                
                attributedString.addAttribute(
                    .backgroundColor,
                    value: backgroundColor,
                    range: lineDiff.range
                )
                
                // Highlight specific word changes
                for wordDiff in lineDiff.wordDiffs {
                    guard wordDiff.range.location + wordDiff.range.length <= text.utf16.count else { continue }
                    
                    let foregroundColor = side == .left ?
                        NSColor.systemRed :
                        NSColor(calibratedRed: 0, green: 0.6, blue: 0, alpha: 1.0)
                    
                    let specificBackgroundColor = side == .left ?
                        NSColor.systemRed.withAlphaComponent(0.2) :
                        NSColor.systemGreen.withAlphaComponent(0.2)
                    
                    attributedString.addAttributes([
                        .foregroundColor: foregroundColor,
                        .backgroundColor: specificBackgroundColor
                    ], range: wordDiff.range)
                }
            }
        }
        
        textView.textStorage?.setAttributedString(attributedString)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: DiffTextView
        var isEditing = false
        var lastSelectedRange: NSRange?
        
        init(_ parent: DiffTextView) {
            self.parent = parent
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                textView.insertNewline(nil)
                return true
            }
            return false
        }
        
        func textDidBeginEditing(_ notification: Notification) {
            isEditing = true
            if let textView = notification.object as? NSTextView {
                lastSelectedRange = textView.selectedRange()
            }
        }
        
        func textDidEndEditing(_ notification: Notification) {
            isEditing = false
            if let textView = notification.object as? NSTextView {
                parent.text = textView.string
                DispatchQueue.main.async { [self] in
                    parent.highlightDifferences(in: textView)
                }
            }
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let currentRange = textView.selectedRange()
            parent.text = textView.string
            
            DispatchQueue.main.async { [self] in
                parent.highlightDifferences(in: textView)
                if currentRange.location <= textView.string.count {
                    textView.setSelectedRange(currentRange)
                }
            }
            
            lastSelectedRange = currentRange
        }
    }
}

class CustomTextView: NSTextView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "z":
                if event.modifierFlags.contains(.shift) {
                    return undoManager?.redo() != nil
                } else {
                    return undoManager?.undo() != nil
                }
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}
