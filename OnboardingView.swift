import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var model: InPorterModel
    @State private var showingAddDestinationSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.accentColor)
                
                Text("Welcome to InPorter")
                    .font(.largeTitle)
                    .bold()
                
                Text("Let's configure your professional media offloading environment.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 40)
            .padding(.bottom, 20)
            
            Divider()
            
            // New Version Intro / Settings Area
            VStack(spacing: 20) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $model.explainerMode) {
                            VStack(alignment: .leading) {
                                Text("Guided Mode")
                                    .font(.headline)
                                Text("Show professional insights and technical tooltips throughout the app.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                    }
                    .padding(8)
                }
                .padding(.horizontal, 40)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Default Copy Destinations")
                        .font(.headline)
                    Text("InPorter works best when configured with at least two backup locations.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 40)
            }
            .padding(.top, 20)
            
            // List of Destinations
            List {
                ForEach(model.copyDestinations) { dest in
                    DestinationRow(dest: dest,
                                   isLast: model.copyDestinations.count == 1,
                                   onRemove: { model.removeDestination(id: dest.id) },
                                   onBrowse: { chooseFolder(for: dest) })
                }
            }
            .listStyle(.inset)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Footer
            HStack(spacing: 12) {
                Spacer()
                
                Button(action: { showingAddDestinationSheet = true }) {
                    Label("Add Destination", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .sheet(isPresented: $showingAddDestinationSheet) {
                    AddDestinationMenu(isPresented: $showingAddDestinationSheet)
                }
                
                Button("Save & Start") {
                    withAnimation {
                        model.completeOnboarding()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(20)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 700, height: 750)
    }
    
    private func chooseFolder(for dest: CopyDestinationConfig) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Set Default"
        
        if panel.runModal() == .OK, let url = panel.url {
            model.saveBookmark(for: url, into: dest.id)
        }
    }
}

private struct DestinationRow: View {
    let dest: CopyDestinationConfig
    let isLast: Bool
    let onRemove: () -> Void
    let onBrowse: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: dest.iconSymbol)
                .foregroundColor(.accentColor)
                .font(.title2)
                .frame(width: 24, alignment: .center)
            
            Text(dest.resolvedName)
                .font(.headline)
                .frame(minWidth: 150, alignment: .leading)
            
            if !dest.basePath.isEmpty {
                Text(dest.basePath)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(minWidth: 200, alignment: .leading)
            } else {
                Text("No folder selected")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .frame(minWidth: 200, alignment: .leading)
            }
            
            Spacer()
            
            Button("Browse…", action: onBrowse)
                .buttonStyle(.bordered)
            
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(isLast ? .gray : .red)
            }
            .buttonStyle(.plain)
            .disabled(isLast)
        }
        .padding(.vertical, 8)
    }
}

private struct AddDestinationMenu: View {
    @EnvironmentObject var model: InPorterModel
    @Binding var isPresented: Bool
    
    let columns = [GridItem(.adaptive(minimum: 150))]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Select Destination Type")
                    .font(.headline)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(CopyDestinationConfig.presets, id: \.self) { preset in
                        Button {
                            addPreset(preset)
                        } label: {
                            VStack(spacing: 12) {
                                Image(systemName: iconFor(preset))
                                    .font(.system(size: 30))
                                    .foregroundColor(.accentColor)
                                Text(preset)
                                    .font(.callout)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 100)
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 500, height: 400)
    }
    
    private func addPreset(_ preset: String) {
        let newDest = CopyDestinationConfig(icon: iconFor(preset), namePreset: preset)
        model.copyDestinations.append(newDest)
        model.saveCopyPreferences()
        isPresented = false
    }
    
    private func iconFor(_ preset: String) -> String {
        switch preset {
        case "Mac Internal (SSD)": return "internaldrive"
        case "Network Server (SMB/AFP)": return "network"
        case "Dropbox (Local Folder)": return "tray.fill"
        case "Portable SSD": return "externaldrive.fill"
        case "Local RAID Storage": return "harddrive.fill"
        case "Edit Suite RAID)": return "server.rack"
        case "Archive Backup": return "archivebox.fill"
        case "Cloud Storage (Sync)": return "cloud.fill"
        default: return "externaldrive"
        }
    }
}
