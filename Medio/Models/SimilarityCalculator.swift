import Foundation

final class SimilarityCalculator {
    static func calculateSimilarity(source: [TextToken], target: [TextToken], isCode: Bool) -> Double {
        if isCode {
            return calculateCodeSimilarity(source: source, target: target)
        }
        
        let sourceWords = Set(source.filter { $0.type != .whitespace }.map { $0.normalized })
        let targetWords = Set(target.filter { $0.type != .whitespace }.map { $0.normalized })
        
        // Handle empty cases
        if sourceWords.isEmpty && targetWords.isEmpty {
            return 1.0
        }
        if sourceWords.isEmpty || targetWords.isEmpty {
            return 0.0
        }
        
        let intersection = sourceWords.intersection(targetWords)
        let union = sourceWords.union(targetWords)
        
        return Double(intersection.count) / Double(union.count)
    }
    
    private static func calculateCodeSimilarity(source: [TextToken], target: [TextToken]) -> Double {
        let sourceStructure = source.filter { $0.type != .whitespace }.map { $0.normalized }
        let targetStructure = target.filter { $0.type != .whitespace }.map { $0.normalized }
        
        // Handle empty cases
        if sourceStructure.isEmpty && targetStructure.isEmpty {
            return 1.0
        }
        if sourceStructure.isEmpty || targetStructure.isEmpty {
            return 0.0
        }
        
        let lcs = longestCommonSubsequence(sourceStructure, targetStructure)
        let maxLength = Double(max(sourceStructure.count, targetStructure.count))
        
        return Double(lcs) / maxLength
    }
    
    private static func longestCommonSubsequence(_ source: [String], _ target: [String]) -> Int {
        guard !source.isEmpty && !target.isEmpty else { return 0 }
        
        var dp = Array(repeating: Array(repeating: 0, count: target.count + 1),
                      count: source.count + 1)
        
        for i in 0..<source.count {
            for j in 0..<target.count {
                if source[i] == target[j] {
                    dp[i + 1][j + 1] = dp[i][j] + 1
                } else {
                    dp[i + 1][j + 1] = max(dp[i + 1][j], dp[i][j + 1])
                }
            }
        }
        
        return dp[source.count][target.count]
    }
}
