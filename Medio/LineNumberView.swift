import AppKit
class LineNumberView: NSView {
    weak var textView: NSTextView? {
        didSet {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleTextViewBoundsChange(_:)),
                name: NSView.boundsDidChangeNotification,
                object: textView?.enclosingScrollView?.contentView
            )
        }
    }
    
    private let font: NSFont = .monospacedSystemFont(ofSize: 11, weight: .regular)
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func handleTextViewBoundsChange(_ notification: Notification) {
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let textView = self.textView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer,
              let content = textView.string as NSString? else {
            return
        }
        
        // Get the visible rect considering scroll position
        let visibleRect = textView.enclosingScrollView?.contentView.bounds ?? .zero
        
        // Calculate the range of text that's currently visible
        var glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: container)
        glyphRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        
        // Count newlines before visible range to determine starting line number
        let preVisibleString = content.substring(to: glyphRange.location)
        let startingLineNumber = preVisibleString.components(separatedBy: .newlines).count
        
        // Get visible content
        let visibleString = content.substring(with: glyphRange)
        let lines = visibleString.components(separatedBy: .newlines)
        
        // Calculate padding for right alignment based on total lines
        let totalLines = content.components(separatedBy: .newlines).count
        _ = "\(totalLines)".size(withAttributes: [.font: font]).width + 16 // 8px padding on each side
        
        // Draw line numbers
        var lineNumber = startingLineNumber
        var currentGlyphPosition = glyphRange.location
        
        for line in lines {
            let lineRange = NSRange(location: currentGlyphPosition, length: line.count)
            var lineRect = layoutManager.lineFragmentRect(forGlyphAt: lineRange.location, effectiveRange: nil)
            
            // Adjust for text container insets and scroll position
            lineRect.origin.y += textView.textContainerInset.height
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            
            let lineNumberString = "\(lineNumber + 1)"
            let stringSize = lineNumberString.size(withAttributes: attributes)
            
            // Right align with consistent padding
            let x = bounds.width - stringSize.width - 8
            let y = lineRect.minY
            
            // Only draw if the line is visible
            if y >= visibleRect.minY - lineRect.height && y <= visibleRect.maxY {
                lineNumberString.draw(
                    at: NSPoint(x: x, y: y),
                    withAttributes: attributes
                )
            }
            
            lineNumber += 1
            currentGlyphPosition += line.count + 1 // +1 for newline character
        }
    }
}
