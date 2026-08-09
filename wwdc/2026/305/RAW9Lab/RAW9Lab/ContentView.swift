import SwiftUI
import CoreImage
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var document: RAWDocument?
    @State private var previewImage: CIImage?
    @State private var isImporterPresented = false
    @State private var exportMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let document {
                    editor(for: document)
                } else {
                    emptyState
                }
            }
            .navigationTitle("RAW 9 Lab")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Open RAW") { isImporterPresented = true }
                }
            }
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: rawContentTypes,
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No RAW file", systemImage: "camera.aperture")
        } description: {
            Text("Open a RAW file (CR2/CR3, NEF, ARW, RAF, DNG…) to start editing with RAW 9.")
        } actions: {
            Button("Open RAW") { isImporterPresented = true }
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Editor

    private func editor(for document: RAWDocument) -> some View {
        @Bindable var doc = document
        return VStack(spacing: 0) {
            statusBar(for: document)

            MetalCIImageView(image: previewImage)
                .background(Color.black)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            controls(doc: doc)
                .padding()
                .background(.bar)
        }
        .onChange(of: doc.edits) { _, _ in refreshPreview() }
        .onAppear { refreshPreview() }
    }

    private func statusBar(for document: RAWDocument) -> some View {
        HStack(spacing: 12) {
            Image(systemName: document.usingRAW9 ? "checkmark.seal.fill" : "seal")
                .foregroundStyle(document.usingRAW9 ? .green : .secondary)
            Text(document.usingRAW9 ? "RAW 9 enabled" : "RAW 9 unavailable — using latest supported")
                .font(.footnote)
            Spacer()
            if let model = document.cameraModel {
                Text(model).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal).padding(.vertical, 8)
        .background(.thinMaterial)
    }

    private func controls(doc: Bindable<RAWDocument>) -> some View {
        VStack(spacing: 14) {
            slider("Exposure", value: doc.edits.exposure, range: -2...2, format: "%.2f EV")
            slider("Luma NR", value: doc.edits.luminanceNoiseReductionAmount, range: 0...1)
            slider("Sharpness", value: doc.edits.sharpnessAmount, range: 0...1)
            slider("Contrast", value: doc.edits.contrastAmount, range: 0...1)

            HStack {
                Button("Reset") { doc.wrappedValue.edits = RAWEdits() }
                Spacer()
                Menu("Export") {
                    Button("HEIF (.heic)") { export(format: .heif) }
                    Button("JPEG (.jpg)") { export(format: .jpeg) }
                }
                .buttonStyle(.borderedProminent)
            }

            if let exportMessage {
                Text(exportMessage).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func slider(
        _ title: String,
        value: Binding<Float>,
        range: ClosedRange<Float>,
        format: String = "%.2f"
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(.subheadline.weight(.medium))
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }

    // MARK: - Actions

    private var rawContentTypes: [UTType] {
        // Broad net: RAW image UTType plus DNG. The system maps most vendor
        // RAW formats under public.camera-raw-image.
        var types: [UTType] = []
        if let raw = UTType("public.camera-raw-image") { types.append(raw) }
        types.append(.image)   // fallback so the picker isn't empty
        return types
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            // Security-scoped access for files outside the sandbox.
            let didAccess = url.startAccessingSecurityScopedResource()
            let doc = RAWDocument(url: url)
            document = doc
            refreshPreview()
            if didAccess { url.stopAccessingSecurityScopedResource() }
        case .failure(let error):
            exportMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    /// Rebuild the preview. Uses scaleFactor < 1 for speed (session tip).
    private func refreshPreview() {
        guard let document else { return }
        // Render at a reduced size for interactivity. In a production app you'd
        // compute this from the view size and screen scale.
        previewImage = document.makeImage(scaleFactor: 0.5)
    }

    private func export(format: RAWExporter.Format) {
        guard let document,
              let image = document.makeFullResolutionImage() else { return }
        do {
            let context = RAWExporter.makeExportContext(memoryLimitMB: 1024)
            let dir = FileManager.default.temporaryDirectory
            let ext = format == .heif ? "heic" : "jpg"
            let out = dir.appendingPathComponent(
                document.url.deletingPathExtension().lastPathComponent + "-edited." + ext)
            try RAWExporter.export(image: image, to: out, format: format, context: context)
            exportMessage = "Exported to \(out.lastPathComponent)"
        } catch {
            exportMessage = "Export failed: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ContentView()
}
