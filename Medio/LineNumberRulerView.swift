import AppKit
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
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: container)
        let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        
        let lineRanges = content.components(separatedBy: .newlines)
        var currentLocation = 0
        
        for (lineNumber, line) in lineRanges.enumerated() {
            let lineRange = NSRange(location: currentLocation, length: line.count)
            currentLocation += line.count + 1 // +1 for newline
            
            if NSLocationInRange(lineRange.location, characterRange) ||
               NSLocationInRange(characterRange.location, lineRange) {
                let glyphLineRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
                let glyphRect = layoutManager.boundingRect(forGlyphRange: glyphLineRange, in: container)
                
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: self.font,
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
                
                let lineNumberString = "\(lineNumber + 1)"
                let stringSize = lineNumberString.size(withAttributes: attributes)
                let x = self.bounds.width - stringSize.width - 4
                let y = glyphRect.minY + textView.textContainerInset.height
                
                lineNumberString.draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
            }
        }
    }
}
