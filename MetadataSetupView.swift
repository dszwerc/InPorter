import SwiftUI
import Foundation

struct MetadataSetupView: View {
    @EnvironmentObject var model: InPorterModel
    
    var body: some View {
        VStack(spacing: 0) {
            if model.metadataPage == 1 {
                GlobalMetadataEntry()
            } else {
                PerClipMetadataEntry()
            }
            
            Divider()
            
            // Footer
            HStack {
                Button("Back") {
                    if model.metadataPage == 2 {
                        model.metadataPage = 1
                    } else {
                        model.backFromMetadata()
                    }
                }
                .controlSize(.large)
                
                Spacer()
                
                Button(model.metadataPage == 1 ? "Next: Per-Clip Metadata" : "Finalize Metadata") {
                    if model.metadataPage == 1 {
                        model.metadataPage = 2
                    } else {
                        model.proceedFromMetadata()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(20)
        }
    }
}

struct GlobalMetadataEntry: View {
    @EnvironmentObject var model: InPorterModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Area
            VStack(alignment: .leading, spacing: 8) {
                Text("Global Metadata")
                    .font(.title2)
                    .bold()
                
                GuidedInfo(message: "Global metadata is applied to every clip in this batch. This information is often embedded into the file's 'Creator', 'Project', or 'Location' atoms during the final processing stage.")
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 30) {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Production / Project Name").font(.headline)
                                TextField("e.g. James River Documentary", text: $model.globalMetadata.productionName)
                                    .textFieldStyle(.roundedBorder)
                                    .controlSize(.large)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Shoot Location").font(.headline)
                                TextField("e.g. Richmond, VA", text: $model.globalMetadata.shootLocation)
                                    .textFieldStyle(.roundedBorder)
                                    .controlSize(.large)
                            }
                        }
                        .padding(12)
                    } label: {
                        Label("Production Context", systemImage: "info.circle")
                    }
                    
                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Primary Camera / Unit").font(.headline)
                                TextField("e.g. RED V-Raptor (A-Cam)", text: $model.globalMetadata.camera)
                                    .textFieldStyle(.roundedBorder)
                                    .controlSize(.large)
                                Text("If InPorter detected a camera model in the sidecars, it has been pre-filled here.")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Global Keywords").font(.headline)
                                TagInputField(tagsString: $model.globalMetadata.globalKeywords)
                                Text("Keywords added here will be prepended to any per-clip tags.")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(12)
                    } label: {
                        Label("Technical & Search", systemImage: "tag")
                    }
                    
                    Spacer(minLength: 40)
                    
                    VStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.down.on.square.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("On the next screen, you can add technical notes like f-Stop, ISO, and Shutter Angle for individual clips.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .font(.callout)
                            .frame(maxWidth: 400)
                    }
                }
                .padding(40)
            }
        }
    }
}

struct PerClipMetadataEntry: View {
    @EnvironmentObject var model: InPorterModel
    @FocusState private var focusedField: String?
    
    var body: some View {
        HSplitView {
            // Left: File List
            List(model.activeFileItems) { item in
                FileRow(item: item, isSelected: model.selectedFileId == item.id)
                    .onTapGesture { model.selectedFileId = item.id }
            }
            .frame(minWidth: 250, maxWidth: 350)
            
            // Right: Detail & Player
            VStack(spacing: 0) {
                if let selectedId = model.selectedFileId,
                   let item = model.activeFileItems.first(where: { $0.id == selectedId }) {
                    
                    VStack(spacing: 0) {
                        VideoPlayerView(url: item.url, autoPlay: true)
                            .frame(height: 350)
                            .background(Color.black)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(item.name)
                                            .font(.title2).bold()
                                        Text(item.url.path)
                                            .font(.caption).foregroundColor(.secondary).lineLimit(1).truncationMode(.middle)
                                    }
                                    Spacer()
                                    Text("Use ↑↓ arrows to switch clips")
                                        .font(.caption2).italic().foregroundColor(.secondary)
                                }
                                
                                GroupBox("Keywords & Tags") {
                                    TagInputField(tagsString: binding(for: selectedId, keyPath: \.keywords))
                                }
                                
                                GroupBox("Technical Data") {
                                    Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                                        GridRow {
                                            VStack(alignment: .leading) {
                                                Text("f-Stop").font(.caption).foregroundColor(.secondary)
                                                TextField("e.g. 2.8", text: binding(for: selectedId, keyPath: \.fStop))
                                                    .textFieldStyle(.roundedBorder)
                                            }
                                            VStack(alignment: .leading) {
                                                Text("ISO").font(.caption).foregroundColor(.secondary)
                                                TextField("e.g. 800", text: binding(for: selectedId, keyPath: \.iso))
                                                    .textFieldStyle(.roundedBorder)
                                            }
                                            VStack(alignment: .leading) {
                                                Text("Lens").font(.caption).foregroundColor(.secondary)
                                                TextField("e.g. 35mm", text: binding(for: selectedId, keyPath: \.lens))
                                                    .textFieldStyle(.roundedBorder)
                                            }
                                        }
                                        GridRow {
                                            VStack(alignment: .leading) {
                                                Text("Shutter / Angle").font(.caption).foregroundColor(.secondary)
                                                TextField("e.g. 180° / 1/48", text: binding(for: selectedId, keyPath: \.cameraAngle))
                                                    .textFieldStyle(.roundedBorder)
                                            }
                                            VStack(alignment: .leading) {
                                                Text("Color Profile").font(.caption).foregroundColor(.secondary)
                                                TextField("e.g. Log-C", text: binding(for: selectedId, keyPath: \.colorProfile))
                                                    .textFieldStyle(.roundedBorder)
                                            }
                                            VStack(alignment: .leading) {
                                                Text("Notes").font(.caption).foregroundColor(.secondary)
                                                TextField("Additional notes", text: binding(for: selectedId, keyPath: \.notes))
                                                    .textFieldStyle(.roundedBorder)
                                            }
                                        }
                                    }
                                    .padding(8)
                                }
                            }
                            .padding(24)
                        }
                    }
                } else {
                    if #available(macOS 14.0, *) {
                        ContentUnavailableView("Select a clip", systemImage: "video.badge.plus")
                    } else {
                        VStack {
                            Image(systemName: "video.badge.plus").font(.largeTitle)
                            Text("Select a clip")
                        }.foregroundColor(.secondary)
                    }
                }
            }
            .frame(minWidth: 500)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .background(
            Group {
                Button("") { moveSelection(direction: -1) }.keyboardShortcut(.upArrow, modifiers: [])
                Button("") { moveSelection(direction: 1) }.keyboardShortcut(.downArrow, modifiers: [])
            }
            .opacity(0)
        )
    }
    
    private func moveSelection(direction: Int) {
        let active = model.activeFileItems
        guard let currentId = model.selectedFileId,
              let currentIndex = active.firstIndex(where: { $0.id == currentId }) else { return }
        
        let nextIndex = currentIndex + direction
        if nextIndex >= 0 && nextIndex < active.count {
            model.selectedFileId = active[nextIndex].id
        }
    }
    
    private func binding(for id: UUID, keyPath: WritableKeyPath<ClipMetadata, String>) -> Binding<String> {
        Binding(
            get: { model.clipMetadata[id]?[keyPath: keyPath] ?? "" },
            set: { newValue in
                if var meta = model.clipMetadata[id] {
                    meta[keyPath: keyPath] = newValue
                    model.clipMetadata[id] = meta
                }
            }
        )
    }
}

struct TagInputField: View {
    @Binding var tagsString: String
    @State private var currentInput: String = ""
    
    var tags: [String] {
        tagsString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowLayout(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text(tag).font(.subheadline)
                        Button {
                            removeTag(tag)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.15))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor.opacity(0.3), lineWidth: 1))
                }
                
                TextField("Add keywords...", text: $currentInput)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .frame(minWidth: 150)
                    .onSubmit { addCurrentAsTag() }
                    .onChange(of: currentInput) { newValue in
                        if newValue.contains(",") {
                            addCurrentAsTag()
                        }
                    }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        }
    }
    
    private func addCurrentAsTag() {
        let newTags = currentInput.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        var existing = tags
        for t in newTags where !existing.contains(t) {
            existing.append(t)
        }
        tagsString = existing.joined(separator: ", ")
        currentInput = ""
    }
    
    private func removeTag(_ tag: String) {
        tagsString = tags.filter { $0 != tag }.joined(separator: ", ")
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        return CGSize(width: proposal.width ?? 0, height: rows.last?.frame.maxY ?? 0)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        for row in rows {
            for element in row.elements {
                element.subview.place(at: CGPoint(x: bounds.minX + element.frame.minX, y: bounds.minY + element.frame.minY), proposal: ProposedViewSize(element.frame.size))
            }
        }
    }
    
    private struct Element {
        let subview: LayoutSubview
        let frame: CGRect
    }
    
    private struct Row {
        let elements: [Element]
        let frame: CGRect
    }
    
    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentRowElements: [Element] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && !currentRowElements.isEmpty {
                rows.append(Row(elements: currentRowElements, frame: CGRect(x: 0, y: y, width: x, height: rowHeight)))
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
                currentRowElements = []
            }
            currentRowElements.append(Element(subview: subview, frame: CGRect(x: x, y: y, width: size.width, height: size.height)))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        if !currentRowElements.isEmpty {
            rows.append(Row(elements: currentRowElements, frame: CGRect(x: 0, y: y, width: x, height: rowHeight)))
        }
        return rows
    }
}
