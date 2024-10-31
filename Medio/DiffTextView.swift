import SwiftUI

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
        textView.textContainerInset = NSSize(width: 0, height: 5)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.backgroundColor = .clear
        
        // Configure scroll view
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = .clear
        
        // Set up line numbers
        let lineNumberView = LineNumberRulerView(scrollView: scrollView)
        scrollView.verticalRulerView = lineNumberView
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        
        context.coordinator.textView = textView
        
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
                
                attributedString.addAttribute(.backgroundColor, value: backgroundColor, range: lineDiff.range)
                
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
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
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
    }
}
