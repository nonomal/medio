import Foundation

enum DiffSide: Hashable {
    case left, right
}

enum DiffType: Hashable {
    case addition, deletion, modification
}

struct WordDiff: Hashable {
    let range: NSRange
    let type: DiffType
}

struct LineDiff: Hashable {
    let range: NSRange
    let wordDiffs: [WordDiff]
    let isDifferent: Bool
    let lineNumber: Int
}
