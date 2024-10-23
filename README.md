# Medio

![image](https://github.com/user-attachments/assets/bf2e4860-d209-4c17-b74b-592dec01ed5e)

A fast, native macOS text comparison tool with real-time diff highlighting and a minimal interface.

Because the really world needed another diff checker.

## ✨ Features

-  **Real-time Comparison**: See differences instantly as you type
-  **Modern UI**: Clean, native macOS interface with light/dark mode support
-  **Smart Diff Detection**: Intelligent word-level difference highlighting
-  **Keyboard Friendly**: Full support for keyboard shortcuts including undo/redo
-  **Lightweight**: Small, efficient, and fast
-  **Dark and Light modes**: Of course
-  **Native Performance**: Built with SwiftUI and AppKit for optimal performance

-  ![42115](https://github.com/user-attachments/assets/d4a202c5-a160-4a66-a7c7-dad346de86a3)


## Get it

You can find the .app here:
[mediano.vercel.app](https://mediano.vercel.app)

This is a designer's first Swift app so it's probably really buggy, feel free to [report](https://github.com/nuance-dev/Medio/issues) any bugs found and I'll do my best to fix them.

## Fun facts?

- First version was made within a day by Claude Sonnet 3.5

- Medio was actually used to develop itself

![72366](https://github.com/user-attachments/assets/d31f9a8f-d76f-446b-bba7-c3ffdf29660e)


## 🚀 How It Works

Medio splits your screen into two editing panes:
- **Left Pane**: Original text
- **Right Pane**: Modified text

As you type or paste text into either pane, Medio automatically:
1. Detects differences at both the line and word level
2. Highlights changes in real-time
3. Uses color coding to show:
   - 🔴 Deletions (in red)
   - 🟢 Additions (in green)
   - Changes are highlighted with corresponding background colors

## 💻 Development

### Requirements
- macOS 14.5+
- Xcode 13.0+
- Swift 5.5+

### Building from Source

1. Clone the repository
```bash
git clone https://github.com/yourusername/medio.git
```

2. Open the project in Xcode
```bash
cd medio
open Medio.xcodeproj
```

3. Build and run using Xcode's build system (⌘B to build, ⌘R to run)

## 🤝 Contributing

We welcome contributions! Here's how you can help:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

Please ensure your PR:
- Follows the existing code style
- Includes appropriate tests
- Updates documentation as needed

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- Website: [mediano.vercel.app](https://mediano.vercel.app)
- Report issues: [GitHub Issues](https://github.com/nuance-dev/Medio/issues)
- Follow updates: [@Nuanced](https://twitter.com/Nuancedev)

---

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![macOS](https://img.shields.io/badge/platform-macOS-lightgrey)]()
[![Swift](https://img.shields.io/badge/Swift-5.5+-orange.svg)]()
