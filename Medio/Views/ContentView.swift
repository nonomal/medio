import SwiftUI
import AppKit

struct ContentView: View {
    @State private var leftText = "This is some text on the left side"
    @State private var rightText = "This is some new text on the right side"
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .headerView, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            HStack(spacing: 0) {
                DiffTextView(text: $leftText, comparisonText: $rightText, side: .left)
                Divider()
                    .background(Color(NSColor.separatorColor))
                DiffTextView(text: $rightText, comparisonText: $leftText, side: .right)
            }
            .padding()
        }
    }
}
