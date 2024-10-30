import SwiftUI
import AppKit

struct DiffTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var comparisonText: String
    var side: DiffSide
    
    static let textDidChangeNotification = NSNotification.Name("DiffTextViewDidChangeNotification")
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = CustomTextView()
        
        // Configure text view
        textView.allowsUndo = true
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textContainerInset = NSSize(width: 5, height: 10)
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
        
        // Add line number ruler view
        let lineNumberView = LineNumberRulerView(scrollView: scrollView)
        scrollView.verticalRulerView = lineNumberView
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        
        // Store textView reference in coordinator
        context.coordinator.textView = textView
        
        // Add observer for text changes
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handleTextChange(_:)),
            name: DiffTextView.textDidChangeNotification,
            object: nil
        )
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        if !context.coordinator.isEditing && textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(selectedRange)
            highlightDifferences(in: textView)
        }
        
        scrollView.verticalRulerView?.needsDisplay = true
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func highlightDifferences(in textView: NSTextView) {
        let attributedString = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: text.utf16.count)
        
        attributedString.addAttributes([
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        ], range: fullRange)
        
        let analyzer = DiffAnalyzer(sourceText: text, targetText: comparisonText)
        let diffs = analyzer.computeDifferences()
        
        for lineDiff in diffs {
            guard lineDiff.range.location + lineDiff.range.length <= text.utf16.count else { continue }
            
            if lineDiff.isDifferent {
                let backgroundColor = side == .left ?
                    NSColor.systemRed.withAlphaComponent(0.2) :
                    NSColor.systemGreen.withAlphaComponent(0.2)
                
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
                    
                    attributedString.addAttributes([
                        .foregroundColor: foregroundColor,
                        .backgroundColor: backgroundColor
                    ], range: wordDiff.range)
                }
            }
        }
        
        textView.textStorage?.setAttributedString(attributedString)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: DiffTextView
        var isEditing = false
        var isProcessingChange = false
        weak var textView: NSTextView?
        
        init(_ parent: DiffTextView) {
            self.parent = parent
        }
        
        func textDidBeginEditing(_ notification: Notification) {
            isEditing = true
        }
        
        func textDidEndEditing(_ notification: Notification) {
            isEditing = false
            if let textView = notification.object as? NSTextView {
                updateText(from: textView)
            }
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  !isProcessingChange else { return }
            
            updateText(from: textView)
            
            // Notify about text change
            NotificationCenter.default.post(
                name: DiffTextView.textDidChangeNotification,
                object: nil,
                userInfo: ["side": parent.side]
            )
        }
        
        @objc func handleTextChange(_ notification: Notification) {
            guard let userInfo = notification.userInfo,
                  let side = userInfo["side"] as? DiffSide,
                  side != parent.side,
                  let textView = self.textView else { return }
            
            // Trigger an update on the other side
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.parent.highlightDifferences(in: textView)
            }
        }
        
        private func updateText(from textView: NSTextView) {
            isProcessingChange = true
            
            let currentRange = textView.selectedRange()
            let visibleRect = textView.visibleRect
            
            parent.text = textView.string
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.parent.highlightDifferences(in: textView)
                
                if currentRange.location <= textView.string.count {
                    textView.setSelectedRange(currentRange)
                    textView.scrollToVisible(visibleRect)
                }
                
                self.isProcessingChange = false
            }
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                textView.insertNewline(nil)
                return true
            }
            return false
        }
    }
}

// LineNumberRulerView and CustomTextView remain unchanged
class LineNumberRulerView: NSRulerView {
    var font: NSFont = .monospacedSystemFont(ofSize: 11, weight: .regular)
    
    init(scrollView: NSScrollView) {
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        self.clientView = scrollView.documentView as? NSTextView
        self.ruleThickness = 40
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = self.clientView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer,
              let content = textView.string as NSString? else {
            return
        }
        
        let visibleRect = textView.visibleRect
        _ = layoutManager.glyphRange(forBoundingRect: visibleRect, in: container)
        
        var lineNumber = 1
        
        content.enumerateSubstrings(in: NSRange(location: 0, length: content.length),
                                  options: [.byLines, .substringNotRequired]) { _, range, _, _ in
            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let glyphRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: container)
            
            if glyphRect.intersects(visibleRect) {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: self.font,
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
                
                let lineNumberString = "\(lineNumber)"
                let size = lineNumberString.size(withAttributes: attributes)
                let x = self.bounds.width - size.width - 4
                let y = glyphRect.minY + textView.textContainerInset.height
                
                lineNumberString.draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
            }
            
            lineNumber += 1
        }
    }
}
