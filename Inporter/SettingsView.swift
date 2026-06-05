import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: InPorterModel
    @State private var tempDestination: CopyDestinationConfig?
    
    // Tricode addition state
    @State private var newTricodeName: String = ""
    @State private var newTricodeCode: String = ""

    var body: some View {
        ScrollView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("InPorter will copy your media to all paths listed below simultaneously.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        List {
                            ForEach($model.copyDestinations) { $dest in
                                CopyDestinationRow(
                                    dest: $dest,
                                    showDragHandle: true,
                                    onBrowse: { browseForFolder(into: $dest) },
                                    onEdit: {
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
                        .frame(minHeight: 300)
                        .listStyle(.plain)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
                        
                        Button {
                            tempDestination = CopyDestinationConfig()
                        } label: {
                            Label("Add New Destination", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Label("Offloading Destinations", systemImage: "externaldrive.badge.plus")
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                }
                .popover(item: $tempDestination) { _ in
                    DestinationEditor(dest: Binding(
                        get: { tempDestination ?? CopyDestinationConfig() },
                        set: { tempDestination = $0 }
                    )) {
                        saveEditedDestination()
                    }
                }
                
                Divider().padding(.vertical)

                // MARK: - Tricode Management Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Manage the 3-letter codes used to categorize media in filenames.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        List {
                            ForEach(model.tricodes) { tri in
                                HStack {
                                    Text(tri.code)
                                        .font(.system(.body, design: .monospaced))
                                        .fontWeight(.bold)
                                        .frame(width: 50, alignment: .leading)
                                    
                                    Text(tri.menuLabel)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Button(role: .destructive) {
                                        model.removeTricode(id: tri.id)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                            }
                            .onMove { from, to in
                                model.moveTricode(fromOffsets: from, toOffset: to)
                            }
                        }
                        .frame(minHeight: 250)
                        .listStyle(.plain)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add New Tricode")
                                .font(.headline)
                            
                            HStack {
                                TextField("Code (e.g. BRL)", text: $newTricodeCode)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                                    .onChange(of: newTricodeCode) { newValue in
                                        if newValue.count > 3 {
                                            newTricodeCode = String(newValue.prefix(3))
                                        }
                                    }
                                
                                TextField("Full Name (e.g. B-Roll)", text: $newTricodeName)
                                    .textFieldStyle(.roundedBorder)
                                
                                Button {
                                    model.addTricode(code: newTricodeCode, name: newTricodeName)
                                    newTricodeCode = ""
                                    newTricodeName = ""
                                } label: {
                                    Image(systemName: "plus")
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(newTricodeCode.isEmpty || newTricodeName.isEmpty)
                            }
                        }
                        .padding(.top, 12)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Label("Filename Tricodes", systemImage: "tag.fill")
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                }

                Divider().padding(.vertical)
                
                Section {
                    Toggle("Enable Guided Mode", isOn: $model.explainerMode)
                        .toggleStyle(.switch)
                    
                    Text("Guided mode provides professional insights and metadata tooltips throughout the workflow.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Label("App Experience", systemImage: "sparkles")
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                }
                
                Divider().padding(.vertical)
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Detailed checksum reports and CSV logs are mirrored to this location for your production records.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.accentColor)
                            Text(model.customLogPath.isEmpty ? "Default: Documents/InPorterLogs" : model.customLogPath)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        
                        HStack {
                            Button("Change Folder…") {
                                let panel = NSOpenPanel()
                                panel.canChooseFiles = false
                                panel.canChooseDirectories = true
                                panel.canCreateDirectories = true
                                if panel.runModal() == .OK, let url = panel.url {
                                    model.setCustomLogLocation(url: url)
                                }
                            }
                            
                            if !model.customLogPath.isEmpty {
                                Button("Reset to Default") { model.resetLogLocationToDefault() }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Label("Logging & Compliance", systemImage: "doc.text.magnifyingglass")
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                }
            }
            .padding(40)
        }
        .frame(width: 800, height: 750)
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
    
    private func browseForFolder(into dest: Binding<CopyDestinationConfig>) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Choose Destination"
        if panel.runModal() == .OK, let url = panel.url {
            model.saveBookmark(for: url, into: dest.id)
        }
    }
}
