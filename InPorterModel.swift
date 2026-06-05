import SwiftUI
import AppKit
import Combine
import CryptoKit
import AVFoundation

final class InPorterModel: ObservableObject {
    // MARK: - Persistence Keys
    private let onboardingKey = "InPorter.hasCompletedOnboarding"
    private let versionKey = "InPorter.lastSeenVersion"
    private let explainerKey = "InPorter.explainerMode"
    private let tricodeKey = "InPorter.tricodeOfferings"
    
    // MARK: - Published state
    @Published var isFirstRun: Bool = false
    @Published var step: WorkflowStep = .loading
    
    // Workflow Choices
    @Published var operationChoice = OperationChoice()
    
    // Metadata State
    @Published var globalMetadata = GlobalMetadata()
    @Published var clipMetadata: [UUID: ClipMetadata] = [:]
    @Published var metadataPage: Int = 1
    
    // Progress and state
    @Published var currentFileProgress: Double = 0
    @Published var currentFileName: String = ""
    @Published var currentFileBytesCopied: Int64 = 0
    @Published var currentFileTotalBytes: Int64 = 0
    @Published var totalBatchBytesCopied: Int64 = 0
    @Published var totalBatchSizeBytes: Int64 = 0
    @Published var estimatedTimeRemaining: TimeInterval? = nil
    @Published var currentThroughput: Double = 0 
    @Published var currentVerifyProgress: Double = 0
    @Published var currentVerifyFileName: String = ""
    @Published var overallProgress: Double = 0
    @Published var currentDestinationName: String = ""
    @Published var fileItems: [FileItem] = []
    @Published var activeBatchSize: Int64 = 0 
    
    private var stepsCompletedCount: Double = 0
    @Published var selectedFileId: UUID?
    
    // Persisted Explainer Mode
    @Published var explainerMode: Bool = true {
        didSet { UserDefaults.standard.set(explainerMode, forKey: explainerKey) }
    }
    
    @Published var showSettings = false
    @Published var tricodes: [Tricode] = []
    @Published var selectedTricode: Tricode?
    @Published var shootCode: String = ""
    @Published var useSingleDateForAll: Bool = false
    @Published var sharedDate: Date? = nil
    @Published var hasMixedDates: Bool = false
    @Published var allHaveNumbers: Bool = false
    @Published var requiresManualNumber: Bool = false
    @Published var manualStartNumber: String = ""
    
    // LRF Handling
    @Published var skipLRFFiles: Bool = false {
        didSet { refreshBatchStats() }
    }
    @Published var hasLRFFiles: Bool = false
    
    @Published var copyDestinations: [CopyDestinationConfig] = []
    @Published var rememberCopyDestinationsNextTime: Bool = true
    @Published var customLogPath: String = ""
    @Published var customLogBookmark: Data?
    @Published var historicalLogs: [LogFile] = []
    @Published var isParsingLogs: Bool = false
    @Published var logSearchText: String = ""
    @Published var logLines: [String] = []
    @Published var detailedLogRows: [String] = []
    @Published var hasErrors: Bool = false
    @Published var isCancelling: Bool = false
    private var copyTask: Task<Void, Never>?
    private var stopAfterCurrentItem: Bool = false
    @Published var lastOperationFolders: Set<URL> = []
    
    private let fileManager = FileManager.default
    private let primaryMediaExtensions: Set<String> = ["mov", "mp4", "mxf", "avi", "ari", "r3d", "braw", "crm"]
    private let sidecarExtensions: Set<String> = ["xml", "srt", "csv", "json", "txt", "cdl", "lrf"]

    init() {
        loadTricodes()
        loadCopyPreferences()
        loadLogPreferences()
        
        if UserDefaults.standard.object(forKey: explainerKey) != nil {
            self.explainerMode = UserDefaults.standard.bool(forKey: explainerKey)
        }
        
        checkIfFirstRun()
    }
    
    private func checkIfFirstRun() {
        let d = UserDefaults.standard
        let hasCompleted = d.bool(forKey: onboardingKey)
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let lastVersion = d.string(forKey: versionKey)
        
        if !hasCompleted || lastVersion != currentVersion {
            isFirstRun = true
        } else {
            isFirstRun = false
        }
    }
    
    func completeOnboarding() {
        let d = UserDefaults.standard
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        d.set(true, forKey: onboardingKey)
        d.set(currentVersion, forKey: versionKey)
        isFirstRun = false
        saveCopyPreferences()
    }

    var tabTitle: String {
        if step == .copyProgress {
            let percent = Int(overallProgress * 100)
            return "\(percent)% — Offloading"
        }
        switch step {
        case .loading: return "Loading..."
        case .landing: return "Welcome"
        case .selectFiles: return "Source"
        case .chooseAction: return "Action"
        case .rename: return "Rename"
        case .metadataSetup: return "Metadata"
        case .copySetup: return "Destination"
        case .done: return "Finish"
        case .reviewLogs: return "Logs"
        case .copyProgress: return "Offloading"
        }
    }

    func startApp() {
        Task {
            try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 2.0)) { self.step = .landing }
            }
        }
    }

    func startNewImport() {
        resetToSelectFiles()
        step = .selectFiles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.selectFilesWithPanel()
        }
    }
    
    func proceedFromAction() {
        if operationChoice.rename { step = .rename }
        else if operationChoice.metadata { enterMetadataSetup() }
        else if operationChoice.copy { step = .copySetup }
    }
    
    func proceedFromRename() {
        if operationChoice.metadata { enterMetadataSetup() }
        else if operationChoice.copy { step = .copySetup }
        else { performRename() }
    }
    
    func enterMetadataSetup() {
        if let firstItem = activeFileItems.first {
            if globalMetadata.productionName.isEmpty {
                let df = DateFormatter()
                df.dateStyle = .medium
                globalMetadata.productionName = "Shoot - \(df.string(from: firstItem.creationDate))"
            }
        }
        
        Task {
            let active = self.activeFileItems
            var updatedMetadata = self.clipMetadata
            for item in active {
                if updatedMetadata[item.id] == nil {
                    var meta = ClipMetadata(id: item.id)
                    self.populateMetadataFromSidecars(&meta, for: item)
                    updatedMetadata[item.id] = meta
                }
            }
            let foundCamera = updatedMetadata.values.first(where: { !$0.cameraModel.isEmpty })?.cameraModel ?? ""
            await MainActor.run {
                self.clipMetadata = updatedMetadata
                if self.globalMetadata.camera.isEmpty && !foundCamera.isEmpty { self.globalMetadata.camera = foundCamera }
                self.metadataPage = 1
                self.step = .metadataSetup
            }
        }
    }
    
    private func populateMetadataFromSidecars(_ meta: inout ClipMetadata, for item: FileItem) {
        let patterns: [WritableKeyPath<ClipMetadata, String>: String] = [
            \.cameraModel: #"(?i)\b(?:Camera|Model|Device|Manufacturer)\b[\s:=">]+([^<",\n]+)"#,
            \.iso: #"(?i)\b(?:ISO|Sensitivity|Gain)\b[\s:=">]+([^<"\s,\n]+)"#,
            \.fStop: #"(?i)\b(?:f-stop|Aperture|FNumber|Iris|T-Stop)\b[\s:=">]+([^<"\s,\n]+)"#,
            \.cameraAngle: #"(?i)\b(?:Angle|ShutterAngle)\b[\s:=">]+([^<"\s,\n]+)"#,
            \.shutter: #"(?i)\b(?:Shutter|ExposureTime|Speed|Exposure)\b[\s:=">]+([^<"\s,\n]+)"#,
            \.lens: #"(?i)\b(?:Lens|FocalLength)\b[\s:=">]+([^<",\n]+)"#,
            \.colorProfile: #"(?i)\b(?:Gamma|ColorSpace|Profile|Log|Look|LUT|CaptureGammaEquation)\b[\s:=">]+([^<",\n]+)"#,
            \.location: #"(?i)\b(?:Location|GPS|City|Country|Scene)\b[\s:=">]+([^<",\n]+)"#
        ]
        
        for url in item.sidecarFiles {
            guard let attr = try? fileManager.attributesOfItem(atPath: url.path),
                  let size = attr[.size] as? Int64, size < 1_048_576,
                  let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            
            let contentRange = NSRange(location: 0, length: (content as NSString).length)
            let delimiters = CharacterSet(charactersIn: "\"'= ").union(.whitespacesAndNewlines)
            
            for (keyPath, pattern) in patterns {
                if meta[keyPath: keyPath].isEmpty {
                    if let regex = try? NSRegularExpression(pattern: pattern),
                       let match = regex.firstMatch(in: content, range: contentRange) {
                        let extracted = (content as NSString).substring(with: match.range(at: 1))
                        var cleaned = extracted.trimmingCharacters(in: delimiters)
                        let attributeNames = ["modelName", "manufacturer", "value", "name"]
                        for attr in attributeNames {
                            let prefix = "\(attr)="
                            if cleaned.lowercased().hasPrefix(prefix.lowercased()) {
                                cleaned = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: delimiters)
                            }
                        }
                        if !cleaned.isEmpty && !attributeNames.contains(cleaned) { meta[keyPath: keyPath] = cleaned }
                    }
                }
            }
        }
    }
    
    func proceedFromMetadata() {
        if operationChoice.copy { step = .copySetup }
        else if operationChoice.rename { performRename() }
        else { logLines.append("Metadata setup complete."); step = .done }
    }

    var internalLogURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = appSupport.appendingPathComponent("InPorter/InPorter Logs", isDirectory: true)
        if !fileManager.fileExists(atPath: folder.path) { try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true) }
        return folder
    }
    
    var userLogURL: URL {
        if let bookmark = customLogBookmark {
            var isStale = false
            if let resolved = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) { return resolved }
        }
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("InPorterLogs")
    }
    
    func selectFilesWithPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK { loadFiles(from: panel.urls) }
        else if step == .selectFiles && fileItems.isEmpty { step = .landing }
    }
    
    func loadFiles(from urls: [URL]) {
        guard !urls.isEmpty else { return }
        var primaryCandidates: [URL] = [], sidecarCandidates: [URL] = []
        for url in urls {
            if url.lastPathComponent.hasPrefix(".") { continue }
            let ext = url.pathExtension.lowercased()
            if primaryMediaExtensions.contains(ext) { primaryCandidates.append(url) }
            else if sidecarExtensions.contains(ext) { sidecarCandidates.append(url) }
        }
        var newItems: [FileItem] = []
        for url in primaryCandidates {
            let name = url.deletingPathExtension().lastPathComponent
            let creationDate = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date()
            let item = FileItem(url: url, name: name, ext: url.pathExtension, creationDate: creationDate,
                                dateFromName: Self.parseMMDDYY(in: name), originalNumber: Self.extractTrailingNumber(name: name, digits: 4),
                                isIncluded: true, sidecarFiles: [])
            newItems.append(item)
        }
        for i in 0..<newItems.count {
            let primaryName = newItems[i].name
            for sidecarURL in sidecarCandidates {
                if sidecarURL.deletingPathExtension().lastPathComponent.hasPrefix(primaryName) { newItems[i].sidecarFiles.append(sidecarURL) }
            }
        }
        newItems.sort { $0.creationDate < $1.creationDate }
        fileItems.append(contentsOf: newItems)
        if selectedFileId == nil, let first = fileItems.first { selectedFileId = first.id }
        refreshBatchStats()
        step = .selectFiles
    }
    
    func toggleInclusion(for itemID: UUID) {
        if let idx = fileItems.firstIndex(where: { $0.id == itemID }) {
            fileItems[idx].isIncluded.toggle()
            refreshBatchStats()
        }
    }
    
    private func refreshBatchStats() {
        analyzeDates(); analyzeNumbers()
        let active = activeFileItems
        
        // Detect if LRF exists in the active set
        let foundLRF = active.contains { item in
            item.sidecarFiles.contains { $0.pathExtension.lowercased() == "lrf" }
        }
        self.hasLRFFiles = foundLRF
        
        Task.detached(priority: .userInitiated) {
            let size = active.reduce(Int64(0)) { total, item in
                let primarySize = (try? self.fileManager.attributesOfItem(atPath: item.url.path)[.size] as? Int64) ?? 0
                let sidecarSize = item.sidecarFiles.reduce(Int64(0)) { sTotal, sURL in
                    if self.skipLRFFiles && sURL.pathExtension.lowercased() == "lrf" { return sTotal }
                    return sTotal + ((try? self.fileManager.attributesOfItem(atPath: sURL.path)[.size] as? Int64) ?? 0)
                }
                return total + primarySize + sidecarSize
            }
            await MainActor.run { self.activeBatchSize = size }
        }
    }
    
    var activeFileItems: [FileItem] { fileItems.filter { $0.isIncluded } }
    
    static func parseMMDDYY(in name: String) -> Date? {
        let pattern = #"(\d{6})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: name, range: NSRange(location: 0, length: (name as NSString).length)) else { return nil }
        let span = (name as NSString).substring(with: match.range(at: 1))
        let formatter = DateFormatter(); formatter.dateFormat = "MMddyy"
        return formatter.date(from: span)
    }
    
    static func extractTrailingNumber(name: String, digits: Int) -> Int? {
        // First check last 4 digits (standard behavior)
        if name.count >= digits {
            let suffix = String(name.suffix(digits))
            if let num = Int(suffix) {
                return num
            }
        }
        
        // If not found in last 4, check the last 10 characters for any 4-digit sequence
        let lookback = min(name.count, 10)
        let last10 = String(name.suffix(lookback))
        if let regex = try? NSRegularExpression(pattern: #"\d{4}"#) {
            let matches = regex.matches(in: last10, range: NSRange(location: 0, length: (last10 as NSString).length))
            // Take the last match if multiple exist
            if let lastMatch = matches.last, let range = Range(lastMatch.range, in: last10) {
                return Int(last10[range])
            }
        }
        
        return nil
    }
    
    private func analyzeDates() {
        let active = activeFileItems
        guard !active.isEmpty else { hasMixedDates = false; sharedDate = nil; return }
        let calendar = Calendar.current
        let baseDates = active.map { $0.dateFromName ?? $0.creationDate }
        let firstDay = calendar.startOfDay(for: baseDates[0])
        hasMixedDates = baseDates.contains { calendar.startOfDay(for: $0) != firstDay }
        if sharedDate == nil { sharedDate = firstDay }
    }
    
    private func analyzeNumbers() {
        let active = activeFileItems
        guard !active.isEmpty else { allHaveNumbers = false; requiresManualNumber = false; return }
        let countWithNumbers = active.filter { $0.originalNumber != nil }.count
        allHaveNumbers = (countWithNumbers == active.count)
        requiresManualNumber = (countWithNumbers == 0)
    }
    
    func proceedFromFileSelection() { if !activeFileItems.isEmpty { step = .chooseAction } }
    func backFromAction() { step = .landing }
    func backFromRename() { step = .chooseAction }
    func backFromRenameToSelectFiles() { step = .selectFiles }
    func backFromMetadata() { step = operationChoice.rename ? .rename : .chooseAction }
    func backFromCopy() { 
        if operationChoice.metadata { step = .metadataSetup }
        else if operationChoice.rename { step = .rename }
        else { step = .chooseAction }
    }
    
    func resetToSelectFiles() {
        fileItems.removeAll(); shootCode = ""; selectedTricode = nil; useSingleDateForAll = false; sharedDate = nil
        hasMixedDates = false; allHaveNumbers = false; requiresManualNumber = false; manualStartNumber = ""
        skipLRFFiles = false; hasLRFFiles = false
        operationChoice = OperationChoice(); logLines.removeAll(); detailedLogRows.removeAll(); hasErrors = false
        lastOperationFolders.removeAll(); clipMetadata.removeAll(); activeBatchSize = 0; step = .landing
    }
    
    func renamePreviewItems() -> [RenamePreviewItem] {
        let active = activeFileItems
        guard !active.isEmpty else { return [] }
        let sortedItems = active.sorted { $0.creationDate < $1.creationDate }
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy_MMdd"
        let triCodeComponent = selectedTricode?.code.uppercased() ?? ""
        let shootComponent = shootCode.components(separatedBy: CharacterSet(charactersIn: " -_")).joined()
        let useManualNumbers = (Int(manualStartNumber) != nil) || requiresManualNumber
        var currentNum: Int = Int(manualStartNumber) ?? 1
        var result: [RenamePreviewItem] = []
        for item in sortedItems {
            let baseDate = (useSingleDateForAll && sharedDate != nil) ? sharedDate! : (item.dateFromName ?? item.creationDate)
            let dateStr = formatter.string(from: baseDate)
            let num = useManualNumbers ? currentNum : (item.originalNumber ?? 0)
            if useManualNumbers { currentNum += 1 }
            let numStr = String(format: "%04d", num)
            var components: [String] = [dateStr]
            if !triCodeComponent.isEmpty { components.append(triCodeComponent) }
            if !shootComponent.isEmpty { components.append(shootComponent) }
            let baseName = components.joined(separator: "_") + "_\(numStr)"
            let finalName = item.ext.isEmpty ? baseName : "\(baseName).\(item.ext)"
            result.append(RenamePreviewItem(originalName: item.url.lastPathComponent, newName: finalName, url: item.url))
        }
        return result
    }
    
    func performRename() {
        let previews = renamePreviewItems()
        guard !previews.isEmpty else { return }
        logLines.removeAll(); detailedLogRows.removeAll()
        detailedLogRows.append("Date,Time,Status,Source_Path,Destination_Path,Original_Name,Renamed_Name,Info")
        hasErrors = false; logLines.append("--- InPorter Rename Log ---")
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let tf = DateFormatter(); tf.dateFormat = "HH:mm:ss"
        lastOperationFolders.removeAll()
        let activeItems = activeFileItems
        for preview in previews {
            let folder = preview.url.deletingLastPathComponent()
            let newURL = folder.appendingPathComponent(preview.newName)
            lastOperationFolders.insert(folder)
            let now = Date(), dStr = df.string(from: now), tStr = tf.string(from: now)
            do {
                try fileManager.moveItem(at: preview.url, to: newURL)
                logLines.append("Renamed: \(preview.originalName) -> \(preview.newName)")
                detailedLogRows.append("\(dStr),\(tStr),SUCCESS,\"\(preview.url.path)\",\"\(newURL.path)\",\"\(preview.originalName)\",\"\(preview.newName)\",Renamed in place")
            } catch {
                hasErrors = true
                logLines.append("🛑 ERROR renaming \(preview.originalName): \(error.localizedDescription)")
                detailedLogRows.append("\(dStr),\(tStr),ERROR,\"\(preview.url.path)\",\"\(newURL.path)\",\"\(preview.originalName)\",\"\(preview.newName)\",\"\(error.localizedDescription)\"")
                continue
            }
            if let sourceItem = activeItems.first(where: { $0.url == preview.url }) {
                let pON = sourceItem.name, pNN = newURL.deletingPathExtension().lastPathComponent
                for sidecarURL in sourceItem.sidecarFiles {
                    // Check if we should skip LRF during rename as well
                    if skipLRFFiles && sidecarURL.pathExtension.lowercased() == "lrf" { continue }
                    
                    let sON = sidecarURL.deletingPathExtension().lastPathComponent, sExt = sidecarURL.pathExtension
                    let suffix = sON.dropFirst(pON.count)
                    let newSidecarName = "\(pNN)\(suffix).\(sExt)", newSidecarURL = folder.appendingPathComponent(newSidecarName)
                    do {
                        try fileManager.moveItem(at: sidecarURL, to: newSidecarURL)
                        logLines.append("...sidecar: \(sidecarURL.lastPathComponent) -> \(newSidecarName)")
                        detailedLogRows.append("\(dStr),\(tStr),SUCCESS,\"\(sidecarURL.path)\",\"\(newSidecarURL.path)\",\"\(sidecarURL.lastPathComponent)\",\"\(newSidecarName)\",Sidecar renamed")
                    } catch {
                        hasErrors = true
                        logLines.append("🛑 ERROR renaming sidecar \(sidecarURL.lastPathComponent): \(error.localizedDescription)")
                    }
                }
            }
        }
        fileItems.removeAll(); saveLogs(prefix: "RenameOnly"); step = .done
    }
    
    private func loadTricodes() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: tricodeKey), 
           let decoded = try? JSONDecoder().decode([Tricode].self, from: data) {
            tricodes = decoded
        } else if let url = Bundle.main.url(forResource: "Book1", withExtension: "csv"), 
                  let text = try? String(contentsOf: url, encoding: .utf8) {
            var rows: [Tricode] = []
            for line in text.split(whereSeparator: \.isNewline).dropFirst() {
                let cols = line.split(separator: ",", omittingEmptySubsequences: false)
                if cols.count >= 3 {
                    let c = String(cols[0]).trimmingCharacters(in: .whitespaces), m = String(cols[1]).trimmingCharacters(in: .whitespaces), u = String(cols[2]).trimmingCharacters(in: .whitespaces)
                    if !c.isEmpty { rows.append(Tricode(code: c, menuLabel: m, explainerText: u)) }
                }
            }
            let defaultList = rows + [Tricode(code: "", menuLabel: "None — leave blank", explainerText: "Leave the tricode portion of the filename empty.")]
            tricodes = defaultList
            saveTricodes()
        } else { 
            tricodes = [Tricode(code: "PGM", menuLabel: "Program", explainerText: "Fallback")] 
            saveTricodes()
        }
    }
    
    func saveTricodes() {
        if let data = try? JSONEncoder().encode(tricodes) {
            UserDefaults.standard.set(data, forKey: tricodeKey)
        }
    }
    
    func addTricode(code: String, name: String) {
        let new = Tricode(code: code.uppercased(), menuLabel: name, explainerText: "User-defined code")
        tricodes.append(new)
        saveTricodes()
    }
    
    func removeTricode(id: UUID) {
        tricodes.removeAll { $0.id == id }
        saveTricodes()
    }
    
    func moveTricode(fromOffsets: IndexSet, toOffset: Int) {
        tricodes.move(fromOffsets: fromOffsets, toOffset: toOffset)
        saveTricodes()
    }

    private func loadCopyPreferences() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: "InPorter.copyPrefs.destinations"), let decoded = try? JSONDecoder().decode([CopyDestinationConfig].self, from: data) { copyDestinations = decoded }
        else { copyDestinations = [CopyDestinationConfig(icon: "internaldrive", namePreset: "Mac Internal (SSD)"), CopyDestinationConfig(icon: "network", namePreset: "Network Server (SMB/AFP)")] }
        rememberCopyDestinationsNextTime = d.bool(forKey: "InPorter.copyPrefs.rememberNextTime")
    }
    
    func saveCopyPreferences() {
        let d = UserDefaults.standard
        if let data = try? JSONEncoder().encode(copyDestinations) { d.set(data, forKey: "InPorter.copyPrefs.destinations") }
        d.set(rememberCopyDestinationsNextTime, forKey: "InPorter.copyPrefs.rememberNextTime")
    }
    func addDestination() { copyDestinations.append(CopyDestinationConfig()); saveCopyPreferences() }
    func removeDestination(id: UUID) { copyDestinations.removeAll { $0.id == id }; saveCopyPreferences() }
    func moveDestination(fromOffsets: IndexSet, toOffset: Int) { copyDestinations.move(fromOffsets: fromOffsets, toOffset: toOffset); saveCopyPreferences() }
    func loadLogPreferences() { let d = UserDefaults.standard; customLogPath = d.string(forKey: "InPorter.logPrefs.path") ?? ""; customLogBookmark = d.data(forKey: "InPorter.logPrefs.bookmark") }
    func setCustomLogLocation(url: URL) {
        if let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            customLogPath = url.path; customLogBookmark = data
            let d = UserDefaults.standard; d.set(customLogPath, forKey: "InPorter.logPrefs.path"); d.set(customLogBookmark, forKey: "InPorter.logPrefs.bookmark")
        }
    }
    func resetLogLocationToDefault() { customLogPath = ""; customLogBookmark = nil; let d = UserDefaults.standard; d.removeObject(forKey: "InPorter.logPrefs.path"); d.removeObject(forKey: "InPorter.logPrefs.bookmark") }
    func saveBookmark(for url: URL, into configID: UUID) {
        if let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil), let index = copyDestinations.firstIndex(where: { $0.id == configID }) {
            copyDestinations[index].basePath = url.path; copyDestinations[index].bookmarkData = data; saveCopyPreferences()
        }
    }
    func resolveBookmark(for config: CopyDestinationConfig) -> URL? {
        guard let data = config.bookmarkData else { return nil }
        var isStale = false; return try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
    }
    func enabledDestinations() -> [CopyDestinationConfig] { copyDestinations.filter { !$0.basePath.isEmpty } }
    func startCopyToEnabledDestinations() { step = .copyProgress; isCancelling = false; stopAfterCurrentItem = false; lastOperationFolders.removeAll(); copyTask = Task { await performCopy() } }
    func cancelCopy(finishCurrent: Bool) { isCancelling = true; if finishCurrent { stopAfterCurrentItem = true } else { copyTask?.cancel() } }
    
    private func calculateBatchSize(destinationsCount: Int) -> Int64 {
        var total: Int64 = 0
        for item in activeFileItems {
            total += (try? fileManager.attributesOfItem(atPath: item.url.path)[.size] as? Int64) ?? Int64(0)
            for s in item.sidecarFiles {
                if skipLRFFiles && s.pathExtension.lowercased() == "lrf" { continue }
                total += (try? fileManager.attributesOfItem(atPath: s.path)[.size] as? Int64) ?? Int64(0)
            }
        }
        return total * Int64(destinationsCount)
    }
    
    func performCopy() async {
        let startTime = Date()
        await MainActor.run {
            self.logLines.removeAll(); self.detailedLogRows.removeAll(); self.detailedLogRows.append("Date,Time,Status,Source_Path,Destination_Path,Original_Name,Renamed_Name,SHA256_Checksum")
            self.hasErrors = false; self.logLines.append("--- InPorter Copy & Verify Log ---"); self.overallProgress = 0; self.totalBatchBytesCopied = 0
        }
        let dests = enabledDestinations()
        if dests.isEmpty { await MainActor.run { self.hasErrors = true; self.step = .done }; return }
        await MainActor.run { self.totalBatchSizeBytes = self.calculateBatchSize(destinationsCount: dests.count) }
        let renames = renamePreviewItems()
        var resolvedDestinations: [(CopyDestinationConfig, URL)] = []
        for dest in dests {
            if let url = resolveBookmark(for: dest) { if url.startAccessingSecurityScopedResource() { resolvedDestinations.append((dest, url)) } }
            else { resolvedDestinations.append((dest, URL(fileURLWithPath: dest.basePath))) }
        }
        for (_, url) in resolvedDestinations { await MainActor.run { self.lastOperationFolders.insert(url) } }
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let tf = DateFormatter(); tf.dateFormat = "HH:mm:ss"
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for (destConfig, destFolderURL) in resolvedDestinations {
                    if stopAfterCurrentItem { break }
                    await MainActor.run { self.currentDestinationName = destConfig.resolvedName }
                    for renameItem in renames {
                        if stopAfterCurrentItem { break }
                        let finalName = operationChoice.rename ? renameItem.newName : renameItem.originalName
                        try Task.checkCancellation()
                        do {
                            let destinationURL = destFolderURL.appendingPathComponent(finalName)
                            await MainActor.run { self.currentFileName = finalName; self.currentFileProgress = 0; self.currentFileBytesCopied = 0 }
                            
                            // Copy the primary file
                            let hash = try await copyAndHashFile(from: renameItem.url, to: destinationURL, batchStartTime: startTime)
                            
                            // Copy associated sidecars (if not already handled by rename-in-place)
                            if let sourceItem = self.activeFileItems.first(where: { $0.url == renameItem.url }) {
                                let pON = sourceItem.name
                                let pNN = destinationURL.deletingPathExtension().lastPathComponent
                                for sidecarURL in sourceItem.sidecarFiles {
                                    if self.skipLRFFiles && sidecarURL.pathExtension.lowercased() == "lrf" { continue }
                                    
                                    let sON = sidecarURL.deletingPathExtension().lastPathComponent
                                    let sExt = sidecarURL.pathExtension
                                    let suffix = sON.dropFirst(pON.count)
                                    let newSidecarName = "\(pNN)\(suffix).\(sExt)"
                                    let newSidecarURL = destFolderURL.appendingPathComponent(newSidecarName)
                                    
                                    // Copy without hashing for sidecars to save time, assuming small files
                                    try? self.fileManager.copyItem(at: sidecarURL, to: newSidecarURL)
                                }
                            }
                            
                            group.addTask {
                                let now = Date(), dStr = df.string(from: now), tStr = tf.string(from: now)
                                await MainActor.run { self.currentVerifyFileName = finalName; self.currentVerifyProgress = 0 }
                                let destHash = await self.calculateHashNative(of: destinationURL) { p in Task { @MainActor in self.currentVerifyProgress = p } }
                                await MainActor.run {
                                    self.currentVerifyProgress = 1.0
                                    if hash == destHash { self.detailedLogRows.append("\(dStr),\(tStr),SUCCESS,\"\(renameItem.url.path)\",\"\(destinationURL.path)\",\"\(renameItem.originalName)\",\"\(finalName)\",\(destHash ?? "FAIL")") }
                                    else { self.hasErrors = true; self.detailedLogRows.append("\(dStr),\(tStr),CHECKSUM_FAIL,\"\(renameItem.url.path)\",\"\(destinationURL.path)\",\"\(renameItem.originalName)\",\"\(finalName)\",MISMATCH") }
                                }
                            }
                        } catch { await MainActor.run { self.hasErrors = true; self.logLines.append("🛑 FAIL: \(finalName)") } }
                    }
                }
                try await group.waitForAll()
            }
        } catch is CancellationError { await MainActor.run { self.logLines.append("\n⚠️ Cancelled.") } }
        catch { await MainActor.run { self.hasErrors = true } }
        for (_, url) in resolvedDestinations { url.stopAccessingSecurityScopedResource() }
        await MainActor.run { self.overallProgress = 1.0; self.saveLogs(prefix: "CopyResult"); self.step = .done }
    }
    
    func copyAndHashFile(from src: URL, to dst: URL, batchStartTime: Date) async throws -> String {
        let bufferSize = 1024 * 1024; var hasher = SHA256()
        if fileManager.fileExists(atPath: dst.path) { try fileManager.removeItem(at: dst) }
        fileManager.createFile(atPath: dst.path, contents: nil)
        let srcH = try FileHandle(forReadingFrom: src), dstH = try FileHandle(forWritingTo: dst)
        defer { try? srcH.close(); try? dstH.close() }
        let totalSize = Double((try? fileManager.attributesOfItem(atPath: src.path)[.size] as? Int64) ?? 1)
        await MainActor.run { self.currentFileTotalBytes = Int64(totalSize) }
        var copied = 0.0, lastUp = Date()
        while true {
            guard let data = try srcH.read(upToCount: bufferSize), !data.isEmpty else { break }
            hasher.update(data: data); try dstH.write(contentsOf: data)
            copied += Double(data.count)
            try Task.checkCancellation()
            await MainActor.run {
                self.currentFileProgress = copied / totalSize; self.currentFileBytesCopied = Int64(copied); self.totalBatchBytesCopied += Int64(data.count)
                self.overallProgress = Double(self.totalBatchBytesCopied) / Double(self.totalBatchSizeBytes)
                let now = Date()
                if now.timeIntervalSince(lastUp) > 0.5 {
                    let dur = now.timeIntervalSince(batchStartTime)
                    if dur > 0 { self.currentThroughput = Double(self.totalBatchBytesCopied) / dur }
                    lastUp = now
                }
            }
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
    
    func calculateHashNative(of url: URL, progress: @escaping (Double) -> Void) async -> String? {
        let buf = 1024 * 1024; var h = SHA256()
        do {
            let srcH = try FileHandle(forReadingFrom: url); defer { try? srcH.close() }
            let total = Double((try? fileManager.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 1)
            var read = 0.0
            while true {
                guard let data = try srcH.read(upToCount: buf), !data.isEmpty else { break }
                h.update(data: data); read += Double(data.count); progress(read / total); try Task.checkCancellation()
            }
            return h.finalize().map { String(format: "%02x", $0) }.joined()
        } catch { return nil }
    }

    func openLogFolder() { NSWorkspace.shared.open(userLogURL) }
    func openOutputFolders() { for url in lastOperationFolders { NSWorkspace.shared.open(url) } }
    func saveLogs(prefix: String) {
        let logName = "\(prefix)_Log_\(Date().timeIntervalSince1970).csv", logText = detailedLogRows.joined(separator: "\n")
        try? logText.write(to: internalLogURL.appendingPathComponent(logName), atomically: true, encoding: .utf8)
        let folderURL = userLogURL; if !fileManager.fileExists(atPath: folderURL.path) { try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true) }
        try? logText.write(to: folderURL.appendingPathComponent(logName), atomically: true, encoding: .utf8)
    }
    
    func fetchHistoricalLogs() async {
        await MainActor.run { self.isParsingLogs = true }
        guard let files = try? fileManager.contentsOfDirectory(at: internalLogURL, includingPropertiesForKeys: [.creationDateKey]) else { await MainActor.run { self.isParsingLogs = false }; return }
        var parsed: [LogFile] = []
        for url in files where url.pathExtension == "csv" {
            let date = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date()
            guard let content = try? String(contentsOf: url) else { continue }
            var records: [LogRecord] = []
            for line in content.components(separatedBy: .newlines).dropFirst() {
                let cols = line.components(separatedBy: ",")
                if cols.count >= 8 { records.append(LogRecord(date: cols[0], time: cols[1], status: cols[2], source: cols[3], destination: cols[4], originalName: cols[5], renamedName: cols[6], checksum: cols[7])) }
            }
            parsed.append(LogFile(filename: url.lastPathComponent, creationDate: date, records: records))
        }
        await MainActor.run { self.historicalLogs = parsed.sorted { $0.creationDate > $1.creationDate }; self.isParsingLogs = false }
    }
    
    var filteredLogs: [LogFile] {
        if logSearchText.isEmpty { return historicalLogs }
        return historicalLogs.compactMap { log in
            let filtered = log.records.filter { $0.originalName.localizedCaseInsensitiveContains(logSearchText) || $0.renamedName.localizedCaseInsensitiveContains(logSearchText) }
            return filtered.isEmpty ? nil : LogFile(filename: log.filename, creationDate: log.creationDate, records: filtered)
        }
    }
}
