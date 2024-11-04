import XCTest
import SwiftUI
@testable import Medio

class DiffAnalyzerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Any setup code if needed
    }
    
    override func tearDown() {
        // Any cleanup code if needed
        super.tearDown()
    }
    
    func testCodeDiffing() {
        // Test Case 1: Code with subtle changes
        let oldCode = """
        function calculateTotal(items) {
            let total = 0;
            for (let i = 0; i < items.length; i++) {
                total += items[i].price;
            }
            return total;
        }
        """
        
        let newCode = """
        function calculateTotal(items) {
            let sum = 0;
            for (const item of items) {
                sum += item.price;
            }
            return sum;
        }
        """
        
        let analyzer = DiffAnalyzer(sourceText: oldCode, targetText: newCode)
        let diffs = analyzer.computeDifferences()
        
        // Print detailed debug information
        printDiffDebugInfo(
            testName: "Code Diffing",
            oldText: oldCode,
            newText: newCode,
            diffs: diffs,
            expectedChanges: [
                "total → sum",
                "for (let i = 0; i < items.length; i++) → for (const item of items)",
                "items[i].price → item.price"
            ]
        )
        
        // Add some basic assertions
        XCTAssertFalse(diffs.isEmpty, "Should detect changes")
        XCTAssertTrue(diffs.contains(where: { $0.isDifferent }), "Should have at least one difference")
    }
    
    func testSimpleTextDiffing() {
        let oldText = "The quick brown fox jumps over the lazy dog."
        let newText = "The fast brown fox leaps over the sleepy dog."
        
        let analyzer = DiffAnalyzer(sourceText: oldText, targetText: newText)
        let diffs = analyzer.computeDifferences()
        
        printDiffDebugInfo(
            testName: "Simple Text Diffing",
            oldText: oldText,
            newText: newText,
            diffs: diffs,
            expectedChanges: [
                "quick → fast",
                "jumps → leaps",
                "lazy → sleepy"
            ]
        )
        
        // Basic assertions
        XCTAssertFalse(diffs.isEmpty, "Should detect changes")
    }
    
    func testComplexTextDiffing() {
        let oldText = """
        Hello! 👋 Here's my weekend plan:
        • Go shopping 🛍️
        • Meet friends for café ☕️
        • Watch movie @ home 🎬
        """
        
        let newText = """
        Hi there! 👋 Here's my weekend schedule:
        • Go shopping with mom 🛍️
        • Meet friends for lunch 🍽️
        • Watch series @ home 📺
        """
        
        let analyzer = DiffAnalyzer(sourceText: oldText, targetText: newText)
        let diffs = analyzer.computeDifferences()
        
        printDiffDebugInfo(
            testName: "Complex Text Diffing",
            oldText: oldText,
            newText: newText,
            diffs: diffs,
            expectedChanges: [
                "Hello! → Hi there!",
                "plan → schedule",
                "shopping → shopping with mom",
                "café ☕️ → lunch 🍽️",
                "movie 🎬 → series 📺"
            ]
        )
        
        // Basic assertions
        XCTAssertFalse(diffs.isEmpty, "Should detect changes")
    }
    
    // MARK: - Helper Methods
    
    private func printDiffDebugInfo(
        testName: String,
        oldText: String,
        newText: String,
        diffs: [LineDiff],
        expectedChanges: [String]
    ) {
        print("\n=== \(testName) Debug Information ===\n")
        
        // Print input texts with line numbers
        print("Old Text (with line numbers):")
        oldText.components(separatedBy: .newlines).enumerated().forEach { index, line in
            print("\(index + 1): \(line)")
        }
        
        print("\nNew Text (with line numbers):")
        newText.components(separatedBy: .newlines).enumerated().forEach { index, line in
            print("\(index + 1): \(line)")
        }
        
        // Print diff details
        print("\nDetected Changes:")
        for diff in diffs where diff.isDifferent {
            print("\nLine \(diff.lineNumber + 1):")
            for wordDiff in diff.wordDiffs {
                if let range = Range(wordDiff.range, in: oldText) {
                    let word = String(oldText[range])
                    print("- Location: \(wordDiff.range.location)")
                    print("- Length: \(wordDiff.range.length)")
                    print("- Text: \"\(word)\"")
                    print("- Type: \(wordDiff.type)")
                }
            }
        }
        
        // Print expected changes
        print("\nExpected Changes:")
        expectedChanges.forEach { print("• \($0)") }
        
        // Add separating line
        print("\n" + String(repeating: "=", count: 50) + "\n")
    }
}
