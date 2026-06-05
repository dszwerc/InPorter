import SwiftUI

struct LogReviewView: View {
    @EnvironmentObject var model: InPorterModel
    @State private var expandedLogID: UUID?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Historical Logs")
                        .font(.largeTitle)
                        .bold()
                    Text("Stored in Application Support")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Done") {
                    withAnimation { model.step = .landing }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search logs for filenames, paths, or checksums...", text: $model.logSearchText)
                    .textFieldStyle(.plain)
                    .font(.body)
            }
            .padding()
            .background(Color.black.opacity(0.03))
            
            Divider()
            
            // List of Logs
            if model.isParsingLogs {
                Spacer()
                HStack {
                    Spacer()
                    ProgressView("Parsing log history...")
                    Spacer()
                }
                Spacer()
            } else if model.filteredLogs.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(model.logSearchText.isEmpty ? "No logs found in Library." : "No records match '\(model.logSearchText)'.")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                List {
                    ForEach(model.filteredLogs) { log in
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { expandedLogID == log.id || !model.logSearchText.isEmpty },
                                set: { expanded in expandedLogID = expanded ? log.id : nil }
                            )
                        ) {
                            LogRecordTable(records: log.records)
                                .padding(.top, 8)
                        } label: {
                            HStack {
                                Image(systemName: iconFor(log.filename))
                                    .foregroundColor(.accentColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(operationDisplayName(for: log.filename)) — \(log.records.count) files")
                                        .font(.headline)
                                    Text("\(log.creationDate, style: .date) at \(log.creationDate, style: .time)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .task {
            await model.fetchHistoricalLogs()
        }
    }
    
    private func operationDisplayName(for filename: String) -> String {
        if filename.hasPrefix("RenameOnly") { return "Rename Only" }
        if filename.hasPrefix("RenameAndCopy") { return "Rename & Copy" }
        if filename.hasPrefix("Copy") { return "Copy Only" }
        return "Process Result"
    }
    
    private func iconFor(_ filename: String) -> String {
        if filename.hasPrefix("RenameOnly") { return "pencil.line" }
        if filename.hasPrefix("RenameAndCopy") { return "arrow.triangle.branch" }
        return "doc.on.doc"
    }
}

/// Helper view to highlight search matches within text
struct HighlightedText: View {
    let text: String
    let query: String
    
    var body: some View {
        if query.isEmpty {
            Text(text)
        } else {
            highlight(text: text, query: query)
        }
    }
    
    private func highlight(text: String, query: String) -> Text {
        var result = Text("")
        var currentPos = text.startIndex
        
        while let range = text.range(of: query, options: .caseInsensitive, range: currentPos..<text.endIndex) {
            result = result + Text(text[currentPos..<range.lowerBound])
            result = result + Text(text[range]).bold().foregroundColor(.accentColor)
            currentPos = range.upperBound
        }
        
        result = result + Text(text[currentPos...])
        return result
    }
}

struct LogRecordTable: View {
    @EnvironmentObject var model: InPorterModel
    let records: [LogRecord]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Table Header
            HStack {
                Text("Filename").frame(width: 250, alignment: .leading)
                Text("Status").frame(width: 100, alignment: .leading)
                Text("Checksum").frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.caption.bold())
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color.secondary.opacity(0.05))
            
            Divider()
            
            ForEach(records) { record in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading) {
                            let displayName = record.renamedName.isEmpty || record.renamedName == record.originalName ? record.originalName : record.renamedName
                            HighlightedText(text: displayName, query: model.logSearchText)
                                .font(.system(.body, design: .monospaced))
                            
                            if !record.renamedName.isEmpty && record.renamedName != record.originalName {
                                HStack(spacing: 2) {
                                    Text("Original:")
                                    HighlightedText(text: record.originalName, query: model.logSearchText)
                                }
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 250, alignment: .leading)
                        
                        Text(record.status)
                            .font(.caption)
                            .foregroundColor(record.status == "SUCCESS" ? .green : .red)
                            .frame(width: 100, alignment: .leading)
                        
                        HighlightedText(text: record.checksum, query: model.logSearchText)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HighlightedText(text: "From: \(record.source)", query: model.logSearchText)
                        if !record.destination.isEmpty && record.destination != record.source {
                            HighlightedText(text: "To: \(record.destination)", query: model.logSearchText)
                        }
                    }
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
                .contextMenu {
                    Button {
                        let pathToReveal = record.destination.isEmpty ? record.source : record.destination
                        NSWorkspace.shared.selectFile(pathToReveal, inFileViewerRootedAtPath: "")
                    } label: {
                        Label("Reveal in Finder", systemImage: "magnifyingglass")
                    }
                }
                
                Divider()
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
    }
}
