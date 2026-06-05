import SwiftUI
import AVKit
import WebKit

// MARK: - Shared UI Components

struct FileRow: View {
    @EnvironmentObject var model: InPorterModel
    let item: FileItem
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: Binding(
                get: { item.isIncluded },
                set: { _ in model.toggleInclusion(for: item.id) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            
            Image(systemName: "video.fill")
                .foregroundColor(isSelected ? .white : .secondary)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .foregroundColor(isSelected ? .white : .primary)
                
                if !item.sidecarFiles.isEmpty {
                    Text("\(item.sidecarFiles.count) sidecar(s)")
                        .font(.system(size: 10))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .accentColor)
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.white)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(isSelected ? Color.accentColor : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
    }
}

struct ActionCard: View {
    let title: String
    let icon: String
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title)
                        .foregroundColor(isOn ? .accentColor : .secondary)
                    Spacer()
                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isOn ? .accentColor : .secondary.opacity(0.5))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding()
            .frame(width: 200, height: 160)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isOn ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct GuidedInfo: View {
    @EnvironmentObject var model: InPorterModel
    let message: String
    
    var body: some View {
        if model.explainerMode {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.accentColor)
                Text(message)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color.accentColor.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

struct CopyDestinationRow: View {
    @Binding var dest: CopyDestinationConfig
    @EnvironmentObject var model: InPorterModel
    var showDragHandle: Bool = false
    var onBrowse: () -> Void
    var onEdit: () -> Void
    var onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            if showDragHandle {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(.secondary.opacity(0.5))
                    .font(.caption)
            }
            
            Image(systemName: dest.iconSymbol)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(dest.resolvedName)
                    .font(.headline)
                
                if !dest.basePath.isEmpty {
                    Text(dest.basePath)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("Folder not selected")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: onBrowse) {
                    Label("Select Location", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Edit name and icon")
                
                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
    }
}

struct DestinationEditor: View {
    @Binding var dest: CopyDestinationConfig
    var onSave: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Configure Destination")
                .font(.headline)
            
            Form {
                Section("Appearance") {
                    Picker("Icon", selection: $dest.iconSymbol) {
                        ForEach(CopyDestinationConfig.symbols, id: \.self) { symbol in
                            Image(systemName: symbol).tag(symbol)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Preset Name", selection: $dest.namePreset) {
                        ForEach(CopyDestinationConfig.presets, id: \.self) { preset in
                            Text(preset).tag(preset)
                        }
                        Divider()
                        Text("Enter Manually...").tag(CopyDestinationConfig.manualOption)
                    }
                    
                    if dest.namePreset == CopyDestinationConfig.manualOption {
                        TextField("Custom Name", text: $dest.customName)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            
            HStack {
                Spacer()
                Button("Done") {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding()
        .frame(width: 350)
    }
}

struct FileSelectionOverview: View {
    @EnvironmentObject var model: InPorterModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Batch Summary")
                .font(.subheadline.bold())
            
            HStack {
                Text("Total Files:")
                Spacer()
                Text("\(model.activeFileItems.count)")
            }
            
            HStack {
                Text("Total Size:")
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: model.activeBatchSize, countStyle: .file))
            }
            
            if model.operationChoice.rename {
                Label("Renaming Enabled", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color.accentColor.opacity(0.05))
        .cornerRadius(8)
    }
}

struct MetadataDisplayView: View {
    @EnvironmentObject var model: InPorterModel
    let item: FileItem
    @State private var technicalMetadata: [String: String] = [:]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("FILE PROPERTIES")
                    .font(.caption2.bold())
                    .foregroundColor(.accentColor)
                
                if technicalMetadata.isEmpty {
                    Text("Reading file header...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(technicalMetadata.sorted(by: <), id: \.key) { key, value in
                        HStack {
                            Text(key).bold()
                            Spacer()
                            Text(value)
                        }
                        .font(.system(size: 11, design: .monospaced))
                    }
                }
            }
            
            if let sidecarData = model.clipMetadata[item.id] {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("CAM TECHNICAL (SIDECAR)")
                        .font(.caption2.bold())
                        .foregroundColor(.accentColor)
                    
                    MetadataRow(label: "Camera", value: sidecarData.cameraModel)
                    MetadataRow(label: "Lens", value: sidecarData.lens)
                    MetadataRow(label: "f-Stop", value: sidecarData.fStop)
                    MetadataRow(label: "ISO", value: sidecarData.iso)
                    MetadataRow(label: "Shutter", value: sidecarData.shutter.isEmpty ? sidecarData.cameraAngle : sidecarData.shutter)
                    MetadataRow(label: "Profile", value: sidecarData.colorProfile)
                }
            }
        }
        .onAppear { loadMetadata() }
        .onChange(of: item.url) { _ in loadMetadata() }
    }
    
    private func loadMetadata() {
        let asset = AVAsset(url: item.url)
        technicalMetadata = [:]
        Task {
            do {
                let duration = try await asset.load(.duration)
                let tracks = try await asset.load(.tracks)
                var found: [String: String] = [:]
                found["Duration"] = String(format: "%.2f sec", duration.seconds)
                if let videoTrack = tracks.first(where: { $0.mediaType == .video }) {
                    let size = try await videoTrack.load(.naturalSize)
                    let frameRate = try await videoTrack.load(.nominalFrameRate)
                    found["Resolution"] = "\(Int(size.width))x\(Int(size.height))"
                    found["FPS"] = String(format: "%.2f", frameRate)
                }
                await MainActor.run { self.technicalMetadata = found }
            } catch { print("Failed to load metadata: \(error)") }
        }
    }
}

private struct MetadataRow: View {
    let label: String
    let value: String
    var body: some View {
        if !value.isEmpty {
            HStack {
                Text(label).bold()
                Spacer()
                Text(value)
            }
            .font(.system(size: 11, design: .monospaced))
        }
    }
}

struct GifImage: NSViewRepresentable {
    let name: String
    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = true
        imageView.imageAlignment = .alignCenter
        if let url = Bundle.main.url(forResource: name, withExtension: "gif"),
           let image = NSImage(contentsOf: url) { imageView.image = image }
        return imageView
    }
    func updateNSView(_ nsView: NSImageView, context: Context) {}
}

struct VideoPlayerView: NSViewRepresentable {
    let url: URL
    var autoPlay: Bool = false
    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .inline
        view.showsFullScreenToggleButton = true
        return view
    }
    func updateNSView(_ view: AVPlayerView, context: Context) {
        if let currentAsset = view.player?.currentItem?.asset as? AVURLAsset, currentAsset.url == url { return }
        view.player?.pause()
        let player = AVPlayer(url: url)
        view.player = player
        if autoPlay { player.play() }
    }
}
