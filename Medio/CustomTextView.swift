import AppKit

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
