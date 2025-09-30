import SwiftUI
import EmulatorKit

/// Sprint 2 - CREATOR-002: Stream Overlay Editor Interface
/// Drag-and-drop overlay editor with real-time preview
public struct StreamOverlayEditor: View {
    @StateObject private var overlayManager = StreamOverlayManager()
    @State private var selectedOverlay: StreamOverlay?
    @State private var selectedElement: OverlayElement?
    @State private var showingTemplateSelector = false
    @State private var showingElementProperties = false
    @State private var canvasScale: CGFloat = 1.0
    @State private var isPreviewMode = false

    // Canvas dimensions (16:9 aspect ratio)
    private let canvasSize = CGSize(width: 800, height: 450)

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar - Overlay Library & Elements
            OverlayEditorSidebar(
                overlayManager: overlayManager,
                selectedOverlay: $selectedOverlay,
                onNewOverlay: { showingTemplateSelector = true },
                onAddElement: addElement
            )
            .frame(width: 280)

            // Main Canvas Area
            VStack(spacing: 0) {
                // Top Toolbar
                OverlayEditorToolbar(
                    overlayManager: overlayManager,
                    selectedOverlay: $selectedOverlay,
                    canvasScale: $canvasScale,
                    isPreviewMode: $isPreviewMode,
                    onSave: saveOverlay,
                    onPreview: togglePreview
                )
                .padding()

                // Canvas Container
                GeometryReader { geometry in
                    let availableSize = geometry.size
                    let scale = min(
                        (availableSize.width - 40) / canvasSize.width,
                        (availableSize.height - 40) / canvasSize.height
                    )
                    let actualScale = scale * canvasScale

                    ScrollView([.horizontal, .vertical]) {
                        OverlayCanvas(
                            overlay: selectedOverlay,
                            canvasSize: canvasSize,
                            scale: actualScale,
                            selectedElement: $selectedElement,
                            onElementUpdate: updateElement,
                            isPreviewMode: isPreviewMode
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(Color(.controlBackgroundColor))
            }

            // Right Sidebar - Properties Panel
            if let selectedElement = selectedElement {
                OverlayElementPropertiesPanel(
                    element: selectedElement,
                    onUpdate: { updatedElement in
                        updateElement(updatedElement)
                        self.selectedElement = updatedElement
                    },
                    onRemove: {
                        removeElement(selectedElement)
                        self.selectedElement = nil
                    }
                )
                .frame(width: 300)
                .background(Color(.controlBackgroundColor))
            }
        }
        .background(Color(.windowBackgroundColor))
        .navigationTitle("Overlay Editor")
        .sheet(isPresented: $showingTemplateSelector) {
            OverlayTemplateSelector(
                overlayManager: overlayManager,
                onTemplateSelected: createOverlayFromTemplate
            )
        }
        .onAppear {
            loadDefaultOverlay()
        }
    }

    // MARK: - Actions

    private func loadDefaultOverlay() {
        if let firstOverlay = overlayManager.userOverlays.first {
            selectedOverlay = firstOverlay
        } else if let defaultTemplate = overlayManager.availableTemplates.first {
            selectedOverlay = overlayManager.createOverlay(
                from: defaultTemplate,
                name: "My Overlay"
            )
        }
    }

    private func createOverlayFromTemplate(_ template: OverlayTemplate) {
        let overlay = overlayManager.createOverlay(
            from: template,
            name: "\(template.name) Copy"
        )
        selectedOverlay = overlay
        showingTemplateSelector = false
    }

    private func addElement(_ elementType: OverlayElementType) {
        guard let overlay = selectedOverlay else { return }

        let newElement = OverlayElement(
            id: UUID(),
            type: elementType,
            position: CGPoint(x: 0.1, y: 0.1), // Top-left area
            size: defaultSizeForElementType(elementType),
            properties: defaultPropertiesForElementType(elementType),
            isVisible: true,
            zIndex: overlay.elements.count
        )

        overlayManager.addElement(newElement, to: overlay)

        // Update the selected overlay reference
        selectedOverlay = overlayManager.userOverlays.first { $0.id == overlay.id }
        selectedElement = newElement
    }

    private func updateElement(_ element: OverlayElement) {
        guard let overlay = selectedOverlay else { return }

        overlayManager.updateElement(element, in: overlay)

        // Update the selected overlay reference
        selectedOverlay = overlayManager.userOverlays.first { $0.id == overlay.id }
    }

    private func removeElement(_ element: OverlayElement) {
        guard let overlay = selectedOverlay else { return }

        overlayManager.removeElement(element, from: overlay)

        // Update the selected overlay reference
        selectedOverlay = overlayManager.userOverlays.first { $0.id == overlay.id }
    }

    private func saveOverlay() {
        guard let overlay = selectedOverlay else { return }
        overlayManager.updateOverlay(overlay)
    }

    private func togglePreview() {
        guard let overlay = selectedOverlay else { return }

        if isPreviewMode {
            overlayManager.exitPreview()
            isPreviewMode = false
        } else {
            overlayManager.previewOverlay(overlay)
            isPreviewMode = true
        }
    }

    private func defaultSizeForElementType(_ type: OverlayElementType) -> CGSize {
        switch type {
        case .webcam:
            return CGSize(width: 0.2, height: 0.25)
        case .chat:
            return CGSize(width: 0.25, height: 0.4)
        case .streamInfo:
            return CGSize(width: 0.3, height: 0.08)
        case .recentFollower, .donation:
            return CGSize(width: 0.25, height: 0.06)
        case .text:
            return CGSize(width: 0.2, height: 0.05)
        case .image:
            return CGSize(width: 0.15, height: 0.15)
        case .timer, .counter:
            return CGSize(width: 0.12, height: 0.06)
        case .gameCapture:
            return CGSize(width: 0.6, height: 0.6)
        case .socialMedia:
            return CGSize(width: 0.2, height: 0.1)
        }
    }

    private func defaultPropertiesForElementType(_ type: OverlayElementType) -> OverlayElementProperties {
        switch type {
        case .webcam:
            return OverlayElementProperties(
                borderColor: .white,
                borderWidth: 2,
                cornerRadius: 12
            )
        case .chat:
            return OverlayElementProperties(
                fontSize: 12,
                textColor: .white,
                backgroundColor: .black.opacity(0.7),
                cornerRadius: 8
            )
        case .streamInfo:
            return OverlayElementProperties(
                fontName: "SF Pro Display",
                fontSize: 16,
                textColor: .white,
                backgroundColor: .blue.opacity(0.8),
                cornerRadius: 8
            )
        case .text:
            return OverlayElementProperties(
                fontName: "SF Pro Display",
                fontSize: 18,
                textColor: .white,
                customText: "Sample Text"
            )
        case .recentFollower:
            return OverlayElementProperties(
                fontSize: 14,
                textColor: .white,
                backgroundColor: .purple.opacity(0.8),
                cornerRadius: 6
            )
        case .donation:
            return OverlayElementProperties(
                fontSize: 14,
                textColor: .white,
                backgroundColor: .green.opacity(0.8),
                cornerRadius: 6
            )
        case .timer, .counter:
            return OverlayElementProperties(
                fontName: "SF Mono",
                fontSize: 16,
                textColor: .white,
                backgroundColor: .black.opacity(0.6),
                cornerRadius: 4
            )
        case .image:
            return OverlayElementProperties(
                borderColor: .white.opacity(0.5),
                borderWidth: 1,
                cornerRadius: 8
            )
        case .gameCapture:
            return OverlayElementProperties(
                borderColor: .blue,
                borderWidth: 2,
                cornerRadius: 8
            )
        case .socialMedia:
            return OverlayElementProperties(
                fontSize: 14,
                textColor: .white,
                backgroundColor: .blue.opacity(0.8),
                cornerRadius: 8
            )
        }
    }
}

// MARK: - Sidebar Component

struct OverlayEditorSidebar: View {
    let overlayManager: StreamOverlayManager
    @Binding var selectedOverlay: StreamOverlay?
    let onNewOverlay: () -> Void
    let onAddElement: (OverlayElementType) -> Void

    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab Selector
            Picker("Sidebar Tab", selection: $selectedTab) {
                Text("Overlays").tag(0)
                Text("Elements").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            TabView(selection: $selectedTab) {
                // Overlays Tab
                OverlayLibraryTab(
                    overlayManager: overlayManager,
                    selectedOverlay: $selectedOverlay,
                    onNewOverlay: onNewOverlay
                )
                .tag(0)

                // Elements Tab
                ElementLibraryTab(onAddElement: onAddElement)
                .tag(1)
            }
#if os(iOS) || os(tvOS)
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
#else
            .tabViewStyle(DefaultTabViewStyle())
#endif
        }
        .background(Color(.controlBackgroundColor))
    }
}

struct OverlayLibraryTab: View {
    let overlayManager: StreamOverlayManager
    @Binding var selectedOverlay: StreamOverlay?
    let onNewOverlay: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // New Overlay Button
                Button(action: onNewOverlay) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("New Overlay")
                        Spacer()
                    }
                    .padding()
                    .background(.blue)
                    .foregroundColor(.white)
                    .cornerRadius(DesignSystem.Radius.lg)
                }

                // User Overlays
                if !overlayManager.userOverlays.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("My Overlays")
                            .font(.headline)
                            .fontWeight(.semibold)

                        LazyVStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(overlayManager.userOverlays) { overlay in
                                OverlayListItem(
                                    overlay: overlay,
                                    isSelected: selectedOverlay?.id == overlay.id,
                                    onSelect: { selectedOverlay = overlay }
                                )
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct ElementLibraryTab: View {
    let onAddElement: (OverlayElementType) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                Text("Add Elements")
                    .font(.headline)
                    .fontWeight(.semibold)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: DesignSystem.Spacing.md) {
                    ForEach(OverlayElementType.allCases, id: \.self) { elementType in
                        ElementTypeButton(
                            elementType: elementType,
                            onTap: { onAddElement(elementType) }
                        )
                    }
                }
            }
            .padding()
        }
    }
}

struct OverlayListItem: View {
    let overlay: StreamOverlay
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Preview thumbnail
                RoundedRectangle(cornerRadius: 4)
                    .fill(.regularMaterial)
                    .frame(width: 40, height: 22)
                    .overlay(
                        Text("\(overlay.elements.count)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(overlay.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Text("\(overlay.elements.count) elements")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(DesignSystem.Spacing.sm)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(DesignSystem.Radius.md)
        }
        .buttonStyle(.plain)
    }
}

struct ElementTypeButton: View {
    let elementType: OverlayElementType
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: elementType.iconName)
                    .font(.title2)
                    .foregroundColor(.accentColor)

                Text(elementType.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.regularMaterial)
            .cornerRadius(DesignSystem.Radius.lg)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Toolbar Component

struct OverlayEditorToolbar: View {
    let overlayManager: StreamOverlayManager
    @Binding var selectedOverlay: StreamOverlay?
    @Binding var canvasScale: CGFloat
    @Binding var isPreviewMode: Bool
    let onSave: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack {
            // Overlay name
            if let overlay = selectedOverlay {
                Text(overlay.name)
                    .font(.headline)
                    .fontWeight(.semibold)
            } else {
                Text("No Overlay Selected")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Zoom Controls
            HStack(spacing: DesignSystem.Spacing.sm) {
                Button("−") {
                    canvasScale = max(0.25, canvasScale - 0.25)
                }
                .font(.title3)

                Text("\(Int(canvasScale * 100))%")
                    .font(.caption)
                    .monospacedDigit()
                    .frame(width: 40)

                Button("+") {
                    canvasScale = min(2.0, canvasScale + 0.25)
                }
                .font(.title3)
            }

            Spacer().frame(width: 20)

            // Action Buttons
            HStack(spacing: DesignSystem.Spacing.md) {
                Button(isPreviewMode ? "Edit" : "Preview", action: onPreview)
                    .buttonStyle(.bordered)
                    .disabled(selectedOverlay == nil)

                Button("Save", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedOverlay == nil)
            }
        }
    }
}

// MARK: - Canvas Component

struct OverlayCanvas: View {
    let overlay: StreamOverlay?
    let canvasSize: CGSize
    let scale: CGFloat
    @Binding var selectedElement: OverlayElement?
    let onElementUpdate: (OverlayElement) -> Void
    let isPreviewMode: Bool

    var body: some View {
        ZStack {
            // Canvas Background
            Rectangle()
                .fill(.black)
                .frame(
                    width: canvasSize.width * scale,
                    height: canvasSize.height * scale
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary, lineWidth: 1)
                )

            // Grid Lines (when not in preview mode)
            if !isPreviewMode {
                CanvasGrid(canvasSize: canvasSize, scale: scale)
            }

            // Overlay Elements
            if let overlay = overlay {
                ForEach(overlay.elements.sorted(by: { $0.zIndex < $1.zIndex }), id: \.id) { element in
                    if element.isVisible {
                        OverlayElementView(
                            element: element,
                            canvasSize: canvasSize,
                            scale: scale,
                            isSelected: selectedElement?.id == element.id,
                            isPreviewMode: isPreviewMode,
                            onTap: {
                                if !isPreviewMode {
                                    selectedElement = element
                                }
                            },
                            onUpdate: onElementUpdate
                        )
                    }
                }
            }

            // Preview Mode Overlay
            if isPreviewMode {
                VStack {
                    HStack {
                        Text("🔴 PREVIEW MODE")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.8))
                            .cornerRadius(DesignSystem.Radius.sm)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(DesignSystem.Spacing.sm)
            }
        }
        .onTapGesture {
            if !isPreviewMode {
                selectedElement = nil
            }
        }
    }
}

struct CanvasGrid: View {
    let canvasSize: CGSize
    let scale: CGFloat

    var body: some View {
        let gridSpacing: CGFloat = 50 * scale
        let cols = Int(canvasSize.width * scale / gridSpacing)
        let rows = Int(canvasSize.height * scale / gridSpacing)

        ZStack {
            // Vertical lines
            ForEach(0...cols, id: \.self) { col in
                Rectangle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 1)
                    .offset(x: CGFloat(col) * gridSpacing - (canvasSize.width * scale) / 2)
            }

            // Horizontal lines
            ForEach(0...rows, id: \.self) { row in
                Rectangle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 1)
                    .offset(y: CGFloat(row) * gridSpacing - (canvasSize.height * scale) / 2)
            }
        }
    }
}

// MARK: - Properties Panel

struct OverlayElementPropertiesPanel: View {
    let element: OverlayElement
    let onUpdate: (OverlayElement) -> Void
    let onRemove: () -> Void

    @State private var localElement: OverlayElement

    init(element: OverlayElement, onUpdate: @escaping (OverlayElement) -> Void, onRemove: @escaping () -> Void) {
        self.element = element
        self.onUpdate = onUpdate
        self.onRemove = onRemove
        self._localElement = State(initialValue: element)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                // Header
                HStack {
                    Image(systemName: localElement.type.iconName)
                        .font(.title2)
                        .foregroundColor(.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(localElement.type.displayName)
                            .font(.headline)
                            .fontWeight(.semibold)

                        Text("Properties")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: onRemove) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                }

                // Position & Size
                PropertySection(title: "Position & Size") {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        HStack {
                            Text("X:")
                            Slider(
                                value: Binding(
                                    get: { localElement.position.x },
                                    set: { newValue in
                                        localElement.position.x = newValue
                                        onUpdate(localElement)
                                    }
                                ),
                                in: 0...1
                            )
                            Text("\(Int(localElement.position.x * 100))%")
                                .frame(width: 40)
                        }

                        HStack {
                            Text("Y:")
                            Slider(
                                value: Binding(
                                    get: { localElement.position.y },
                                    set: { newValue in
                                        localElement.position.y = newValue
                                        onUpdate(localElement)
                                    }
                                ),
                                in: 0...1
                            )
                            Text("\(Int(localElement.position.y * 100))%")
                                .frame(width: 40)
                        }

                        HStack {
                            Text("Width:")
                            Slider(
                                value: Binding(
                                    get: { localElement.size.width },
                                    set: { newValue in
                                        localElement.size.width = newValue
                                        onUpdate(localElement)
                                    }
                                ),
                                in: 0.05...1
                            )
                            Text("\(Int(localElement.size.width * 100))%")
                                .frame(width: 40)
                        }

                        HStack {
                            Text("Height:")
                            Slider(
                                value: Binding(
                                    get: { localElement.size.height },
                                    set: { newValue in
                                        localElement.size.height = newValue
                                        onUpdate(localElement)
                                    }
                                ),
                                in: 0.05...1
                            )
                            Text("\(Int(localElement.size.height * 100))%")
                                .frame(width: 40)
                        }
                    }
                }

                // Type-specific properties
                TypeSpecificProperties(
                    element: $localElement,
                    onUpdate: onUpdate
                )

                // Style Properties
                StylePropertiesSection(
                    element: $localElement,
                    onUpdate: onUpdate
                )

                Spacer()
            }
            .padding()
        }
        .onAppear {
            localElement = element
        }
        .onChange(of: element) { newElement in
            localElement = newElement
        }
    }
}

struct PropertySection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            content()
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(DesignSystem.Radius.lg)
    }
}

struct TypeSpecificProperties: View {
    @Binding var element: OverlayElement
    let onUpdate: (OverlayElement) -> Void

    var body: some View {
        switch element.type {
        case .text:
            PropertySection(title: "Text Content") {
                TextField(
                    "Enter text",
                    text: Binding(
                        get: { element.properties.customText ?? "" },
                        set: { newValue in
                            element.properties.customText = newValue
                            onUpdate(element)
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)
            }
        default:
            EmptyView()
        }
    }
}

struct StylePropertiesSection: View {
    @Binding var element: OverlayElement
    let onUpdate: (OverlayElement) -> Void

    var body: some View {
        PropertySection(title: "Style") {
            VStack(spacing: DesignSystem.Spacing.md) {
                // Visibility toggle
                Toggle("Visible", isOn: Binding(
                    get: { element.isVisible },
                    set: { newValue in
                        element.isVisible = newValue
                        onUpdate(element)
                    }
                ))

                // Opacity
                HStack {
                    Text("Opacity:")
                    Slider(
                        value: Binding(
                            get: { element.properties.opacity ?? 1.0 },
                            set: { newValue in
                                element.properties.opacity = newValue
                                onUpdate(element)
                            }
                        ),
                        in: 0...1
                    )
                    Text("\(Int((element.properties.opacity ?? 1.0) * 100))%")
                        .frame(width: 40)
                }

                // Corner Radius
                HStack {
                    Text("Corner Radius:")
                    Slider(
                        value: Binding(
                            get: { element.properties.cornerRadius ?? 0 },
                            set: { newValue in
                                element.properties.cornerRadius = newValue
                                onUpdate(element)
                            }
                        ),
                        in: 0...50
                    )
                    Text("\(Int(element.properties.cornerRadius ?? 0))")
                        .frame(width: 40)
                }

                // Border Width
                HStack {
                    Text("Border:")
                    Slider(
                        value: Binding(
                            get: { element.properties.borderWidth ?? 0 },
                            set: { newValue in
                                element.properties.borderWidth = newValue
                                onUpdate(element)
                            }
                        ),
                        in: 0...10
                    )
                    Text("\(Int(element.properties.borderWidth ?? 0))px")
                        .frame(width: 40)
                }
            }
        }
    }
}

// MARK: - Template Selector Sheet

struct OverlayTemplateSelector: View {
    let overlayManager: StreamOverlayManager
    let onTemplateSelected: (OverlayTemplate) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory = OverlayCategory.minimalist

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Category Picker
                Picker("Category", selection: $selectedCategory) {
                    ForEach(OverlayCategory.allCases, id: \.self) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Templates Grid
                let filteredTemplates = overlayManager.availableTemplates.filter {
                    selectedCategory == .custom || $0.category == selectedCategory
                }

                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: DesignSystem.Spacing.lg) {
                        ForEach(filteredTemplates) { template in
                            TemplateCard(template: template) {
                                onTemplateSelected(template)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Choose Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TemplateCard: View {
    let template: OverlayTemplate
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                // Preview
                Rectangle()
                    .fill(.regularMaterial)
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay(
                        VStack {
                            Image(systemName: template.category.iconName)
                                .font(.title)
                                .foregroundColor(.secondary)

                            Text("\(template.elements.count) elements")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    )
                    .cornerRadius(DesignSystem.Radius.lg)

                // Info
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(template.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(template.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding()
            .background(.regularMaterial)
            .cornerRadius(DesignSystem.Radius.xxl)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Overlay Element View

struct OverlayElementView: View {
    let element: OverlayElement
    let canvasSize: CGSize
    let scale: CGFloat
    let isSelected: Bool
    let isPreviewMode: Bool
    let onTap: () -> Void
    let onUpdate: (OverlayElement) -> Void

    @State private var dragOffset = CGSize.zero

    var body: some View {
        let elementSize = CGSize(
            width: element.size.width * canvasSize.width * scale,
            height: element.size.height * canvasSize.height * scale
        )

        let elementPosition = CGPoint(
            x: element.position.x * canvasSize.width * scale,
            y: element.position.y * canvasSize.height * scale
        )

        ZStack {
            // Element Content
            ElementContentView(element: element, size: elementSize)

            // Selection Border (edit mode only)
            if isSelected && !isPreviewMode {
                RoundedRectangle(cornerRadius: element.properties.cornerRadius ?? 0)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: element.properties.cornerRadius ?? 0)
                            .fill(Color.accentColor.opacity(0.1))
                    )
            }
        }
        .frame(width: elementSize.width, height: elementSize.height)
        .position(
            x: elementPosition.x + dragOffset.width,
            y: elementPosition.y + dragOffset.height
        )
        .opacity(element.properties.opacity ?? 1.0)
        .onTapGesture(perform: onTap)
        .gesture(
            isPreviewMode ? nil : DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    let newX = max(0, min(1, element.position.x + (value.translation.width / (canvasSize.width * scale))))
                    let newY = max(0, min(1, element.position.y + (value.translation.height / (canvasSize.height * scale))))

                    var updatedElement = element
                    updatedElement.position = CGPoint(x: newX, y: newY)
                    onUpdate(updatedElement)

                    dragOffset = .zero
                }
        )
    }
}

struct ElementContentView: View {
    let element: OverlayElement
    let size: CGSize

    var body: some View {
        Group {
            switch element.type {
            case .webcam:
                WebcamElementView(element: element, size: size)
            case .text:
                TextElementView(element: element, size: size)
            case .streamInfo:
                StreamInfoElementView(element: element, size: size)
            case .chat:
                ChatElementView(element: element, size: size)
            default:
                PlaceholderElementView(element: element, size: size)
            }
        }
    }
}

struct WebcamElementView: View {
    let element: OverlayElement
    let size: CGSize

    var body: some View {
        RoundedRectangle(cornerRadius: element.properties.cornerRadius ?? 0)
            .fill(.regularMaterial)
            .overlay(
                Image(systemName: "video.fill")
                    .font(.title)
                    .foregroundColor(.secondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: element.properties.cornerRadius ?? 0)
                    .stroke(
                        element.properties.borderColor?.color ?? .clear,
                        lineWidth: element.properties.borderWidth ?? 0
                    )
            )
    }
}

struct TextElementView: View {
    let element: OverlayElement
    let size: CGSize

    var body: some View {
        Text(element.properties.customText ?? "Sample Text")
            .font(.system(size: element.properties.fontSize ?? 16, weight: .medium))
            .foregroundColor(element.properties.textColor?.color ?? .white)
            .frame(width: size.width, height: size.height)
            .background(element.properties.backgroundColor?.color ?? .clear)
            .cornerRadius(element.properties.cornerRadius ?? 0)
    }
}

struct StreamInfoElementView: View {
    let element: OverlayElement
    let size: CGSize

    var body: some View {
        VStack(spacing: 2) {
            Text("Stream Title")
                .font(.system(size: (element.properties.fontSize ?? 16) * 0.8))
                .fontWeight(.medium)

            Text("Category • 1.2K viewers")
                .font(.system(size: (element.properties.fontSize ?? 16) * 0.6))
                .opacity(0.8)
        }
        .foregroundColor(element.properties.textColor?.color ?? .white)
        .frame(width: size.width, height: size.height)
        .background(element.properties.backgroundColor?.color ?? .clear)
        .cornerRadius(element.properties.cornerRadius ?? 0)
    }
}

struct ChatElementView: View {
    let element: OverlayElement
    let size: CGSize

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text("viewer1: Great gameplay!")
            Text("viewer2: Amazing moves")
            Text("viewer3: Keep it up!")
            Spacer()
        }
        .font(.system(size: element.properties.fontSize ?? 12))
        .foregroundColor(element.properties.textColor?.color ?? .white)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .padding(DesignSystem.Spacing.sm)
        .background(element.properties.backgroundColor?.color ?? .clear)
        .cornerRadius(element.properties.cornerRadius ?? 0)
    }
}

struct PlaceholderElementView: View {
    let element: OverlayElement
    let size: CGSize

    var body: some View {
        RoundedRectangle(cornerRadius: element.properties.cornerRadius ?? 0)
            .fill(.regularMaterial)
            .overlay(
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: element.type.iconName)
                        .font(.title2)
                        .foregroundColor(.secondary)

                    Text(element.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            )
    }
}

#if DEBUG
struct StreamOverlayEditor_Previews: PreviewProvider {
    static var previews: some View {
        StreamOverlayEditor()
            .frame(width: 1200, height: 800)
    }
}
#endif
