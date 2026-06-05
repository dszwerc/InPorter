import SwiftUI

struct RenameView: View {
    @EnvironmentObject var model: InPorterModel
    
    var body: some View {
        let previews = model.renamePreviewItems()
        let disableRename = model.requiresManualNumber && Int(model.manualStartNumber) == nil
        
        VStack(alignment: .leading, spacing: 0) {
            
            // Header
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Rename Configuration")
                        .font(.title2)
                        .bold()
                    Spacer()
                }
                .padding()
                
                GuidedInfo(message: "InPorter follows the professional standard: [DATE]_[TRICODE]_[SHOOT]_[NUMBER]. This ensures that files from different cameras never collide and remain chronologically sortable in any OS.")
                    .padding(.horizontal)
                    .padding(.bottom, 10)
            }
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            HSplitView {
                // LEFT COLUMN: Controls
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // 1. Shoot Info Group
                        GroupBox(label: Label("Shoot Information", systemImage: "info.circle")) {
                            VStack(alignment: .leading, spacing: 10) {
                                GuidedInfo(message: "The Shoot Code identifies the project or scene, while the Tricode categorizes the media type (e.g., PGM for Program, RAW for uncompressed footage).")
                                
                                Text("Shoot / Footage Code")
                                    .font(.headline)
                                TextField("Example: JAMESRIVER", text: $model.shootCode)
                                    .textFieldStyle(.roundedBorder)
                                
                                Divider()
                                
                                Text("Tricode (Category)")
                                    .font(.headline)
                                Picker("", selection: Binding<UUID?>(
                                    get: { model.selectedTricode?.id },
                                    set: { id in
                                        if let id = id {
                                            model.selectedTricode = model.tricodes.first(where: { $0.id == id })
                                        } else {
                                            model.selectedTricode = nil
                                        }
                                    }
                                )) {
                                    ForEach(model.tricodes) { tri in
                                        Text(tri.menuLabel).tag(Optional(tri.id))
                                    }
                                }
                                .labelsHidden()
                                
                                if let tri = model.selectedTricode {
                                    Text(tri.explainerText)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(8)
                        }
                        
                        // 2. Date Logic Group
                        GroupBox(label: Label("Date Logic", systemImage: "calendar")) {
                            VStack(alignment: .leading, spacing: 10) {
                                GuidedInfo(message: "Most professional cameras record dates in the filename. If a shoot spans past midnight, use 'Single Date' to force all files into the same project day.")

                                Toggle("Use a single date for all files", isOn: $model.useSingleDateForAll)
                                
                                if model.useSingleDateForAll {
                                    DatePicker("Select Date", selection: Binding<Date>(
                                        get: { model.sharedDate ?? Date() },
                                        set: { model.sharedDate = $0 }
                                    ), displayedComponents: .date)
                                    .datePickerStyle(.graphical)
                                } else {
                                    Text(model.hasMixedDates ? "Each file uses its own creation date." : "All files share the same creation date.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(8)
                        }
                        
                        // 3. Numbering Group
                        GroupBox(label: Label("Sequence Numbering", systemImage: "number.square")) {
                            VStack(alignment: .leading, spacing: 10) {
                                GuidedInfo(message: "InPorter preserves original camera sequence numbers (e.g. C0001) where possible. If numbers reset on every card, use manual start numbering to maintain a unique global sequence.")

                                if model.allHaveNumbers {
                                    Text("Existing 4-digit numbers detected.")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    TextField("Override Start Number (Optional)", text: $model.manualStartNumber)
                                        .textFieldStyle(.roundedBorder)
                                } else {
                                    Text("Manual numbering required.")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    TextField("Start Number (e.g. 0001)", text: $model.manualStartNumber)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                            .padding(8)
                        }
                    }
                    .padding()
                }
                .frame(minWidth: 320, maxWidth: 400)
                
                // RIGHT COLUMN: Preview List
                VStack(spacing: 0) {
                    HStack {
                        Text("Live Preview")
                            .font(.headline)
                            .padding(.leading)
                        Spacer()
                        Text("\(previews.count) Items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.trailing)
                    }
                    .frame(height: 30)
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                    
                    if previews.isEmpty {
                        VStack {
                            Spacer()
                            Text("No files selected for rename.")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    } else {
                        List {
                            ForEach(previews) { item in
                                HStack {
                                    Text(item.originalName)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .frame(width: 200, alignment: .leading)
                                    
                                    Image(systemName: "arrow.right")
                                        .font(.caption2)
                                        .foregroundColor(.secondary.opacity(0.5))
                                    
                                    Text(item.newName)
                                        .font(.system(.body, design: .monospaced))
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .listStyle(.bordered)
                    }
                }
                .frame(minWidth: 400)
            }
            
            Divider()
            
            // Footer
            HStack {
                Button("Back") {
                    model.backFromRename()
                }
                .controlSize(.large)
                
                Spacer()
                
                Button("Confirm & Proceed") {
                    // Changed from model.performRename() to proceedFromRename()
                    // so it evaluates the next step in the workflow.
                    model.proceedFromRename()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(disableRename || previews.isEmpty)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
            .padding(.top, 10)
        }
    }
}
