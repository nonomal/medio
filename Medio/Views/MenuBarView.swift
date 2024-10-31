import SwiftUI

struct MenuBarView: View {
    @ObservedObject var updater: UpdateChecker
    @EnvironmentObject var menuBarController: MenuBarController
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // App Icon and Version
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text("Medio")
                    .font(.title2.bold())
                
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top)
            
            // Status Section
            Group {
                if updater.isChecking {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Checking for updates...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else if let error = updater.error {
                    VStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else if updater.updateAvailable {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                        
                        if let version = updater.latestVersion {
                            Text("Version \(version) Available")
                                .font(.headline)
                        }
                        
                        if let notes = updater.releaseNotes {
                            ScrollView {
                                Text(notes)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .frame(maxHeight: 100)
                        }
                        
                        Button {
                            if let url = updater.downloadURL {
                                NSWorkspace.shared.open(url)
                                dismiss()
                            }
                        } label: {
                            Text("Download Update")
                                .frame(maxWidth: 200)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green)
                        Text("Medio is up to date")
                            .font(.headline)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            
            Spacer()
            
            // Bottom Buttons
            HStack(spacing: 20) {
                Button("Check Again") {
                    updater.checkForUpdates()
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.bottom)
        }
        .padding()
        .frame(width: 300, height: 400)
    }
}
