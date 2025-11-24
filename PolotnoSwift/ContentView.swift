import SwiftUI
import UIKit

struct ContentView: View {
    @State private var isPresentingEditor = false
    @State private var currentDocJSON = SampleDocument.loadJSON()
    @State private var latestPreviewImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                canvasPreview
                Button(action: { isPresentingEditor = true }) {
                    Text("Open Editor")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding()
            .navigationTitle("Polotno Swift Demo")
        }
        .sheet(isPresented: $isPresentingEditor) {
            EditorContainerView(
                initialDocumentJSON: currentDocJSON,
                onSave: { payload in
                    currentDocJSON = payload.docJson
                    latestPreviewImage = payload.previewImage()
                    isPresentingEditor = false
                },
                onCancel: {
                    isPresentingEditor = false
                }
            )
            .interactiveDismissDisabled(true)
        }
    }

    private var canvasPreview: some View {
        Group {
            if let image = latestPreviewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .overlay(alignment: .bottomTrailing) {
                        Text("Saved preview")
                            .font(.caption)
                            .padding(6)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .padding(8)
                    }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No design saved yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Tap “Open Editor” to customize a Polotno design.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 320)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(uiColor: .separator), lineWidth: 1)
        )
    }
}

struct EditorContainerView: View {
    let initialDocumentJSON: String
    let onSave: (EditorSavePayload) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            EditorWebView(initialDocumentJSON: initialDocumentJSON, onSave: onSave)
                .ignoresSafeArea()
                .navigationBarHidden(true)
                .statusBar(hidden: true)
        }
    }
}

enum SampleDocument {
    static func loadJSON() -> String {
        guard let url = Bundle.main.url(forResource: "SampleDocument", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let string = String(data: data, encoding: .utf8) else {
            return defaultJSON
        }
        return string
    }

    static let defaultJSON: String = """
    {
      "width": 1080,
      "height": 1080,
      "pages": [
        {
          "id": "page-1",
          "children": [
            {
              "type": "background",
              "name": "background",
              "x": 0,
              "y": 0,
              "width": 1080,
              "height": 1080,
              "fill": "#f3f4f6"
            },
            {
              "type": "text",
              "name": "title",
              "x": 140,
              "y": 160,
              "fontSize": 64,
              "fontFamily": "Arial",
              "fill": "#0f172a",
              "text": "Welcome to Polotno"
            },
            {
              "type": "text",
              "name": "subtitle",
              "x": 140,
              "y": 260,
              "fontSize": 32,
              "fontFamily": "Arial",
              "fill": "#475569",
              "text": "Edit this design inside the embedded editor."
            }
          ]
        }
      ]
    }
    """
}

#Preview {
    ContentView()
}


