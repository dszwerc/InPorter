import SwiftUI

struct DoneView: View {
    @EnvironmentObject var model: InPorterModel
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: model.hasErrors ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(model.hasErrors ? .orange : .green)
            
            VStack(spacing: 12) {
                Text(model.hasErrors ? "Operation Completed with Warnings" : "All Tasks Complete!")
                    .font(.system(size: 34, weight: .bold))
                
                Text(model.hasErrors ? "Some files could not be processed. Check the logs for details." : "Your media has been processed, renamed, and verified.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 600)
            
            HStack(spacing: 20) {
                Button(action: { model.openLogFolder() }) {
                    Label("Open Log Folder", systemImage: "folder.fill")
                }
                .controlSize(.large)
                
                if !model.lastOperationFolders.isEmpty {
                    // UPDATED: This button will now open a unique window for each destination path
                    Button(action: { model.openOutputFolders() }) {
                        Label("Open Destination Folders", systemImage: "externaldrive.fill")
                    }
                    .controlSize(.large)
                }
            }
            
            Divider()
                .frame(maxWidth: 400)
            
            Button("Start New Batch") {
                withAnimation { model.resetToSelectFiles() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
