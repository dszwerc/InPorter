import Foundation

// Overall workflow state
enum WorkflowStep: Equatable {
    case loading
    case landing
    case selectFiles
    case chooseAction
    case rename
    case metadataSetup
    case copySetup
    case copyProgress
    case done
    case reviewLogs
}

struct GlobalMetadata {
    var camera: String = ""
    var shootLocation: String = ""
    var globalKeywords: String = ""
    var productionName: String = ""
}

struct ClipMetadata: Identifiable, Equatable {
    let id: UUID
    var location: String = ""
    var keywords: String = ""
    var fStop: String = ""
    var iso: String = ""
    var cameraAngle: String = ""
    var shutter: String = ""
    var lens: String = ""
    var cameraModel: String = ""
    var colorProfile: String = ""
    var notes: String = ""
}

struct OperationChoice {
    var rename: Bool = true
    var metadata: Bool = false
    var copy: Bool = true
}

struct FileItem: Identifiable, Codable {
    let id: UUID
    let url: URL
    let name: String
    let ext: String
    let creationDate: Date
    var dateFromName: Date?
    var originalNumber: Int?
    var isIncluded: Bool
    var sidecarFiles: [URL]
    
    init(id: UUID = UUID(), url: URL, name: String, ext: String, creationDate: Date, dateFromName: Date? = nil, originalNumber: Int? = nil, isIncluded: Bool = true, sidecarFiles: [URL] = []) {
        self.id = id
        self.url = url
        self.name = name
        self.ext = ext
        self.creationDate = creationDate
        self.dateFromName = dateFromName
        self.originalNumber = originalNumber
        self.isIncluded = isIncluded
        self.sidecarFiles = sidecarFiles
    }
}

struct Tricode: Identifiable, Codable, Equatable {
    let id: UUID
    let code: String
    let menuLabel: String
    let explainerText: String
    
    init(id: UUID = UUID(), code: String, menuLabel: String, explainerText: String) {
        self.id = id
        self.code = code
        self.menuLabel = menuLabel
        self.explainerText = explainerText
    }
}

struct RenamePreviewItem: Identifiable {
    let id: UUID = UUID()
    let originalName: String
    let newName: String
    let url: URL
}

struct LogRecord: Identifiable, Codable {
    let id: UUID = UUID()
    let date: String
    let time: String
    let status: String
    let source: String
    let destination: String
    let originalName: String
    let renamedName: String
    let checksum: String
}

struct LogFile: Identifiable {
    let id: UUID = UUID()
    let filename: String
    let creationDate: Date
    let records: [LogRecord]
}

// MARK: - Offloading Models

struct CopyDestinationConfig: Identifiable, Codable {
    let id: UUID
    var iconSymbol: String
    var namePreset: String
    var customName: String
    var basePath: String
    var bookmarkData: Data?
    
    static let manualOption = "Enter Manually..."
    static let presets = [
        "Mac Internal (SSD)",
        "Network Server (SMB/AFP)",
        "Dropbox (Local Folder)",
        "Portable SSD",
        "Local RAID Storage",
        "Edit Suite RAID",
        "Archive Backup",
        "Cloud Storage (Sync)"
    ]
    
    static let symbols = [
        "externaldrive", "externaldrive.fill", "externaldrive.connected.2.fill",
        "internaldrive", "network", "server.rack", "desktopcomputer", "laptopcomputer",
        "bolt.horizontal.fill", "usb.fill", "sdcard.fill", "cloud.fill", "icloud.fill",
        "folder.fill", "harddrive.fill", "archivebox.fill", "opticaldiscdrive.fill",
        "tray.2.fill", "macmini.fill", "cable.connector"
    ]
    
    var resolvedName: String {
        namePreset == Self.manualOption ? customName : namePreset
    }
    
    init(id: UUID = UUID(), icon: String = "externaldrive", namePreset: String = "Portable SSD", customName: String = "", basePath: String = "", bookmarkData: Data? = nil) {
        self.id = id
        self.iconSymbol = icon
        self.namePreset = namePreset
        self.customName = customName
        self.basePath = basePath
        self.bookmarkData = bookmarkData
    }
}
