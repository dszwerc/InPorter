import SwiftUI

struct ContentView: View {
    // CHANGE: Use @StateObject here. This ensures that every time a new window 
    // or tab is opened, a brand new InPorterModel instance is created for it.
    @StateObject private var model = InPorterModel()
    @Namespace private var splashNamespace
    
    // Modern environment action for macOS 14+ fallback
    @Environment(\.openSettings) private var openSettings
    
    // Track the specific window this view instance is hosted in
    @State private var hostingWindow: NSWindow?
    
    var body: some View {
        VStack(spacing: 0) {
            if isMainWorkflow(model.step) {
                WorkflowTabs()
            }
            mainAppLayout
        }
        .environmentObject(model)
        // Use a background helper to capture the reference to the local NSWindow
        .background(WindowAccessor(window: $hostingWindow))
        .navigationTitle(model.tabTitle)
        .frame(minWidth: model.step == .loading ? 400 : (model.step == .landing ? 850 : 1000),
               minHeight: model.step == .loading ? 400 : (model.step == .landing ? 500 : 750))
        .onAppear {
            if model.step == .loading {
                model.startApp()
                applyStyle(for: .loading)
            }
        }
        .onChange(of: model.step) { oldStep, newStep in
            if oldStep == .loading && newStep == .landing {
                animateWindow(to: NSSize(width: 850, height: 500))
            } else if (oldStep == .landing || oldStep == .reviewLogs) && newStep == .selectFiles {
                applyStyle(for: .selectFiles)
            }
        }
        // MODIFICATION: Present onboarding as a modal sheet instead of a conditional root view.
        // This separates the view hierarchies, allowing the background window to proceed 
        // with its splash screen and window-sizing animations while onboarding is active.
        .sheet(isPresented: $model.isFirstRun) {
            OnboardingView()
                .environmentObject(model)
        }
    }
    
    private func isMainWorkflow(_ step: WorkflowStep) -> Bool {
        switch step {
        case .loading, .landing, .reviewLogs: return false
        default: return true
        }
    }
    
    @ViewBuilder
    private var mainAppLayout: some View {
        ZStack {
            switch model.step {
            case .loading:
                SplashScreenView(namespace: splashNamespace)
                    .transition(.asymmetric(insertion: .identity, removal: .opacity))
            case .landing:
                LandingScreenView(namespace: splashNamespace) {
                    triggerSettings()
                }
                .transition(.asymmetric(insertion: .opacity, removal: .opacity))
            case .selectFiles:
                SelectFilesView()
                    .transition(.opacity)
            case .chooseAction:
                ChooseActionView()
                    .transition(.opacity)
            case .rename:
                RenameView()
                    .transition(.opacity)
            case .metadataSetup:
                MetadataSetupView()
                    .transition(.opacity)
            case .copySetup:
                CopySetupView()
                    .transition(.opacity)
            case .copyProgress:
                CopyProgressView()
                    .transition(.opacity)
            case .done:
                DoneView()
                    .transition(.opacity)
            case .reviewLogs:
                LogReviewView()
                    .transition(.opacity)
            }
        }
    }
    
    private func triggerSettings() {
        if #available(macOS 14.0, *) {
            try? openSettings()
        } else {
            NSApp.sendAction(NSSelectorFromString("showSettings:"), to: nil, from: nil)
        }
    }
    
    private func applyStyle(for step: WorkflowStep) {
        // CHANGE: Use the detected hostingWindow instead of the global .first window
        guard let window = hostingWindow else { return }
        
        if step == .loading {
            window.setContentSize(NSSize(width: 400, height: 400))
            window.center()
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
        } else {
            window.standardWindowButton(.closeButton)?.isHidden = false
            window.standardWindowButton(.miniaturizeButton)?.isHidden = false
            window.standardWindowButton(.zoomButton)?.isHidden = false
            window.setContentSize(NSSize(width: 1000, height: 750))
            window.center()
            window.titleVisibility = .visible
            window.titlebarAppearsTransparent = false
        }
    }
    
    private func animateWindow(to size: NSSize) {
        // CHANGE: Use the detected hostingWindow instead of the global .first window
        guard let window = hostingWindow else { return }
        
        if let screen = window.screen {
            let screenFrame = screen.visibleFrame
            let newX = screenFrame.origin.x + (screenFrame.width - size.width) / 2
            let newY = screenFrame.origin.y + (screenFrame.height - size.height) / 2
            let newFrame = NSRect(x: newX, y: newY, width: size.width, height: size.height)
            
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 1.0 
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(newFrame, display: true)
            }
        }
    }
}

// Helper view to capture the NSWindow reference for the current view hierarchy
struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.window = view.window
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if self.window == nil, let window = nsView.window {
            DispatchQueue.main.async {
                self.window = window
            }
        }
    }
}

struct SplashScreenView: View {
    let namespace: Namespace.ID
    
    var body: some View {
        VStack(spacing: 30) {
            GifImage(name: "splash")
                .matchedGeometryEffect(id: "splashGif", in: namespace)
                .frame(width: 200, height: 200)
            
            Text("InPorter")
                .font(.system(size: 32, weight: .black))
                .opacity(0.8)
            
            ProgressView()
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct LandingScreenView: View {
    @EnvironmentObject var model: InPorterModel
    let namespace: Namespace.ID
    let onSettings: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            HStack(spacing: 80) {
                // Select Clips
                LandingIconButton(title: "New Import", systemImage: "plus.square.fill.on.square.fill", iconSize: 80, fontSize: 24) {
                    model.startNewImport()
                }
                
                // View Logs
                LandingIconButton(title: "View Logs", systemImage: "doc.text.magnifyingglass", iconSize: 80, fontSize: 24) {
                    withAnimation { model.step = .reviewLogs }
                }
            }
            
            Spacer()
        }
        .overlay(
            HStack(spacing: 30) {
                LandingIconButton(title: "Settings", systemImage: "gearshape", iconSize: 16, fontSize: 13, isHorizontal: true, action: onSettings)
                
                Button {
                    model.explainerMode.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16))
                            .foregroundColor(model.explainerMode ? .accentColor : .secondary)
                        
                        Text(model.explainerMode ? "Guided mode ON" : "Guided mode OFF")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(30),
            alignment: .bottom
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct LandingIconButton: View {
    let title: String
    let systemImage: String
    let iconSize: CGFloat
    let fontSize: CGFloat
    var isHorizontal: Bool = false
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            Group {
                if isHorizontal {
                    HStack(spacing: 8) {
                        iconLabel
                    }
                } else {
                    VStack(spacing: 20) {
                        iconLabel
                    }
                }
            }
            .padding(24)
            .background(isHovering ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
    
    @ViewBuilder
    private var iconLabel: some View {
        Image(systemName: systemImage)
            .font(.system(size: iconSize))
            .foregroundColor(isHovering ? .accentColor : .primary)
        
        Text(title)
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundColor(isHovering ? .accentColor : .primary)
    }
}

struct WorkflowTabs: View {
    @EnvironmentObject var model: InPorterModel
    
    struct TabStep: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let step: WorkflowStep
    }
    
    private var activeSteps: [TabStep] {
        var steps: [TabStep] = [
            TabStep(title: "Source", icon: "folder.badge.plus", step: .selectFiles),
            TabStep(title: "Action", icon: "checklist", step: .chooseAction)
        ]
        
        if model.operationChoice.rename {
            steps.append(TabStep(title: "Rename", icon: "pencil.line", step: .rename))
        }
        
        if model.operationChoice.metadata {
            steps.append(TabStep(title: "Metadata", icon: "tag.fill", step: .metadataSetup))
        }
        
        if model.operationChoice.copy {
            steps.append(TabStep(title: "Destination", icon: "externaldrive.fill", step: .copySetup))
            steps.append(TabStep(title: "Offload", icon: "arrow.up.doc.fill", step: .copyProgress))
        }
        
        steps.append(TabStep(title: "Finish", icon: "checkmark.circle.fill", step: .done))
        
        return steps
    }
    
    var body: some View {
        HStack(spacing: 0) {
            let steps = activeSteps
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, tab in
                WorkflowTabItem(
                    title: tab.title,
                    icon: tab.icon,
                    step: tab.step,
                    current: model.step,
                    allSteps: steps.map { $0.step }
                )
                
                if index < steps.count - 1 {
                    WorkflowTabArrow()
                }
            }
        }
        .frame(height: 64)
        .padding(.horizontal)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(Divider(), alignment: .bottom)
    }
}

private struct WorkflowTabItem: View {
    let title: String
    let icon: String
    let step: WorkflowStep
    let current: WorkflowStep
    let allSteps: [WorkflowStep]
    
    var isActive: Bool { current == step }
    
    var isPast: Bool {
        guard let currentIndex = allSteps.firstIndex(of: current),
              let stepIndex = allSteps.firstIndex(of: step) else { return false }
        return stepIndex < currentIndex
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: isPast ? "checkmark.circle.fill" : icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(isActive ? .accentColor : (isPast ? .green : .secondary.opacity(0.8)))
            
            Text(title)
                .font(.system(size: 10, weight: isActive ? .bold : .medium))
                .foregroundColor(isActive ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                if isActive {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.08))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
                    
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(height: 3)
                            .cornerRadius(1.5)
                            .padding(.horizontal, 12)
                    }
                }
            }
        )
        .contentShape(Rectangle())
    }
}

private struct WorkflowTabArrow: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.secondary.opacity(0.3))
            .padding(.horizontal, 2)
    }
}
