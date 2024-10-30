import SwiftUI
import AppKit

struct DiffTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var comparisonText: String
    var side: DiffSide
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = CustomTextView()
        
        // Configure text view
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
        
        // Configure scroll view
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
    
    private func highlightDifferences(in textView: NSTextView) {
        let attributedString = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: text.utf16.count)
        
        // Reset attributes
        attributedString.addAttributes([
            .foregroundColor: NSColor.labelColor,
            .backgroundColor: NSColor.clear,
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        ], range: fullRange)
        
        let analyzer = DiffAnalyzer(sourceText: text, targetText: comparisonText)
        let diffs = analyzer.computeDifferences()
        
        for lineDiff in diffs {
            guard lineDiff.range.location + lineDiff.range.length <= text.utf16.count else { continue }
            
            if lineDiff.isDifferent {
                let backgroundColor = side == .left ?
                    NSColor.systemRed.withAlphaComponent(0.1) :
                    NSColor.systemGreen.withAlphaComponent(0.1)
                
                attributedString.addAttribute(
                    .backgroundColor,
                    value: backgroundColor,
                    range: lineDiff.range
                )
                
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
