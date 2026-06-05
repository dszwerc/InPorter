import SwiftUI

struct CopySetupView: View {
    @EnvironmentObject var model: InPorterModel
    
    // Track editing state for the destination popover
    @State private var tempDestination: CopyDestinationConfig?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Copy Setup")
                        .font(.title2)
                        .bold()
                    Spacer()
                }
                .padding()

                GuidedInfo(message: "Parallel Offloading allows you to copy to multiple drives at once. InPorter uses macOS Security Scopes (Bookmarks) to remember these folders, avoiding permission prompts in the future.")
                    .padding(.horizontal)
                    .padding(.bottom, 10)
            }
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            HStack(alignment: .top, spacing: 0) {
                // LEFT: Destination Configuration
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Destinations")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button {
                            // Create a new config and open the editor
                            tempDestination = CopyDestinationConfig()
                        } label: {
                            Label("Add Destination", systemImage: "plus.circle")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.top, 8)

                    List {
                        ForEach($model.copyDestinations) { $dest in
                            CopyDestinationRow(
                                dest: $dest,
                                showDragHandle: true,
                                onBrowse: { chooseFolder(for: $dest) },
                                onEdit: {
                                    // Capture the current value for the editor
                                    tempDestination = dest
                                },
                                onRemove: { model.removeDestination(id: dest.id) }
                            )
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            .listRowBackground(Color.clear)
                        }
                        .onMove { from, to in
                            model.moveDestination(fromOffsets: from, toOffset: to)
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.secondary.opacity(0.02))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
                    // Popover for editing destination details
                    .popover(item: $tempDestination) { _ in
                        DestinationEditor(dest: Binding(
                            get: { tempDestination ?? CopyDestinationConfig() },
                            set: { tempDestination = $0 }
                        )) {
                            saveEditedDestination()
                        }
                    }
                    
                    HStack {
                        Toggle("Remember these destinations for next time", isOn: $model.rememberCopyDestinationsNextTime)
                            .onChange(of: model.rememberCopyDestinationsNextTime) { _ in
                                model.saveCopyPreferences()
                            }
                            .controlSize(.small)
                        
                        Spacer()
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)

                Divider()

                // RIGHT: Source Overview
                VStack(alignment: .leading, spacing: 16) {
                    Text("Source Summary")
                        .font(.headline)
                        .padding(.top, 8)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(model.activeFileItems) { item in
                                HStack {
                                    Image(systemName: "video.fill")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(item.name)
                                        .font(.system(.caption, design: .monospaced))
                                        .lineLimit(1)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(8)
                    .frame(maxHeight: .infinity)

                    FileSelectionOverview()
                }
                .padding()
                .frame(width: 350)
            }

            Divider()

            // Footer Buttons
            HStack {
                Button("Back") { model.backFromCopy() }
                .controlSize(.large)

                Spacer()

                Button("Start Copy & Verify") {
                    // Sync to settings before starting if toggle is on
                    if model.rememberCopyDestinationsNextTime { model.saveCopyPreferences() }
                    model.startCopyToEnabledDestinations()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.enabledDestinations().isEmpty || model.activeFileItems.isEmpty)
            }
            .padding(20)
        }
    }

    private func chooseFolder(for dest: Binding<CopyDestinationConfig>) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"
        if panel.runModal() == .OK, let url = panel.url {
            model.saveBookmark(for: url, into: dest.wrappedValue.id)
        }
    }

    private func saveEditedDestination() {
        guard let edited = tempDestination else { return }
        if let index = model.copyDestinations.firstIndex(where: { $0.id == edited.id }) {
            model.copyDestinations[index] = edited
        } else {
            model.copyDestinations.append(edited)
        }
        model.saveCopyPreferences()
        tempDestination = nil
    }
}
