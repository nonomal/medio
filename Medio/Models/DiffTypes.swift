import Foundation

public struct Line {
    public let text: String
    public let range: NSRange
    
    public init(text: String, range: NSRange) {
        self.text = text
        self.range = range
    }
}

public enum DiffType: Hashable {
    case addition, deletion, modification
}

public struct WordDiff: Hashable {
    public let range: NSRange
    public let type: DiffType
    
    public init(range: NSRange, type: DiffType) {
        self.range = range
        self.type = type
    }
}

public enum DiffSide: Hashable {
    case left, right
}

public struct LineDiff: Hashable {
    public let range: NSRange
    public let wordDiffs: [WordDiff]
    public let isDifferent: Bool
    public let lineNumber: Int
    
    public init(range: NSRange, wordDiffs: [WordDiff], isDifferent: Bool, lineNumber: Int) {
        self.range = range
        self.wordDiffs = wordDiffs
        self.isDifferent = isDifferent
        self.lineNumber = lineNumber
    }
}
