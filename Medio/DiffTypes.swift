import Foundation

enum DiffSide {
    case left
    case right
}

enum DiffType {
    case addition
    case deletion
    case modification
}

struct WordDiff {
    let range: NSRange
    let type: DiffType
}

struct LineDiff {
    let range: NSRange
    let wordDiffs: [WordDiff]
    let isDifferent: Bool
    let lineNumber: Int
}
