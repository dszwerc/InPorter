import SwiftUI

struct ChooseActionView: View {
    @EnvironmentObject var model: InPorterModel
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(alignment: .center, spacing: 32) {
                VStack(spacing: 12) {
                    Text("Choose Actions")
                        .font(.system(size: 34, weight: .bold))
                    
                    Text("Select the processing steps for this batch.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                HStack(alignment: .center, spacing: 30) {
                    ActionCard(
                        title: "Rename",
                        icon: "pencil.line",
                        description: "Standardize filenames based on date, tricodes, and sequence.",
                        isOn: $model.operationChoice.rename
                    )
                    
                    ActionCard(
                        title: "Metadata",
                        icon: "tag.fill",
                        description: "Embed camera technical info and keywords into clip atoms.",
                        isOn: $model.operationChoice.metadata
                    )
                    
                    ActionCard(
                        title: "Copy & Verify",
                        icon: "doc.on.doc.fill",
                        description: "Parallel offload to multiple drives with SHA256 checksums.",
                        isOn: $model.operationChoice.copy
                    )
                }
                
                GuidedInfo(message: "InPorter will guide you through each active section sequentially.")
                    .frame(maxWidth: 600)
            }
            .frame(maxWidth: .infinity)
            
            Spacer()
            
            Divider()
            
            // Footer
            HStack {
                Button("Back") { model.backFromAction() }
                    .controlSize(.large)
                Spacer()
                
                Button("Confirm & Proceed") {
                    model.proceedFromAction()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!model.operationChoice.rename && !model.operationChoice.metadata && !model.operationChoice.copy)
            }
            .padding(30)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}
