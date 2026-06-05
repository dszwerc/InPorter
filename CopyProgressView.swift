import SwiftUI

struct CopyProgressView: View {
    @EnvironmentObject var model: InPorterModel
    @State private var showingCancelDialog = false
    
    // Helper Formatters
    private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useMB, .useGB, .useTB]
        f.countStyle = .file
        return f
    }()
    
    private static let timeFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute, .second]
        f.unitsStyle = .abbreviated
        return f
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Top Header
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Processing Files")
                            .font(.largeTitle)
                            .bold()
                        Text("Simultaneous Copy & Verification Active")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                    }
                    Spacer()
                }
                .padding()
                
                GuidedInfo(message: "InPorter performs bit-level verification using the SHA256 algorithm. Verification happens on a separate thread simultaneously with the copy to maximize disk I/O efficiency.")
                    .padding(.horizontal)
                    .padding(.bottom, 10)
            }
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Dynamic Progress Section
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // 1. Copying Progress
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Copying:", systemImage: "doc.on.doc.fill")
                                .fontWeight(.semibold)
                            Text(truncateFilename(model.currentFileName))
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            // File Size Progress
                            Text("\(Self.byteFormatter.string(fromByteCount: model.currentFileBytesCopied)) / \(Self.byteFormatter.string(fromByteCount: model.currentFileTotalBytes))")
                                .font(.caption)
                                .monospacedDigit()
                        }
                        
                        ProgressView(value: model.currentFileProgress, total: 1.0)
                            .progressViewStyle(.linear)
                    }
                    
                    // 2. Verification Progress (Simultaneous)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Verifying:", systemImage: "checkmark.shield.fill")
                                .fontWeight(.semibold)
                            Text(model.currentVerifyFileName.isEmpty ? "Waiting..." : truncateFilename(model.currentVerifyFileName))
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        
                        ProgressView(value: model.currentVerifyProgress, total: 1.0)
                            .progressViewStyle(.linear)
                            .tint(.green)
                    }
                    
                    Divider()
                    
                    // 3. Overall Progress
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Total Batch Progress")
                                .fontWeight(.bold)
                            Spacer()
                            Text("\(Int(model.overallProgress * 100))%")
                                .font(.caption)
                        }
                        
                        ProgressView(value: model.overallProgress, total: 1.0)
                        
                        HStack {
                            Text(Self.byteFormatter.string(fromByteCount: model.totalBatchBytesCopied) + " of " + Self.byteFormatter.string(fromByteCount: model.totalBatchSizeBytes))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if let remaining = model.estimatedTimeRemaining {
                                Text("Approx. \(Self.timeFormatter.string(from: remaining) ?? "?") remaining")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else if model.overallProgress < 1.0 {
                                Text("Calculating time...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if model.currentThroughput > 0 && model.overallProgress < 1.0 {
                            Text("Speed: \(Self.byteFormatter.string(fromByteCount: Int64(model.currentThroughput)))/s")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text("Current Destination: \(model.currentDestinationName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            // Log View
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(model.logLines, id: \.self) { line in
                            Text(line)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(line.contains("ERROR") || line.contains("FAIL") ? .red : .secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(8)
                }
                .frame(minHeight: 100, maxHeight: 200)
                .background(Color.black.opacity(0.05))
                .cornerRadius(6)
                .padding(.horizontal)
                .padding(.bottom)
                .onChange(of: model.logLines.count) { _, _ in
                    if let last = model.logLines.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
            
            Divider()
            
            HStack {
                // CANCEL BUTTON
                if model.overallProgress < 1.0 && !model.isCancelling {
                    Button("Cancel Operation") {
                        showingCancelDialog = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }

                Spacer()
                
                Button("Finish") {
                    model.step = .done
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.overallProgress < 1.0 && !model.hasErrors)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog("Stop Copy Process?", isPresented: $showingCancelDialog) {
            Button("Finish Current File Then Stop") {
                model.cancelCopy(finishCurrent: true)
            }
            Button("Stop Immediately", role: .destructive) {
                model.cancelCopy(finishCurrent: false)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Do you want to finish the file currently being copied before stopping, or stop immediately?")
        }
    }
    
    private func truncateFilename(_ name: String) -> String {
        guard name.count > 12 else { return name }
        let prefix = String(name.prefix(4))
        let suffix = String(name.suffix(4))
        return "\(prefix)...\(suffix)"
    }
}
