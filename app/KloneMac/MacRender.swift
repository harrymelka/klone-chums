import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Offline previews: bundled character only, no microphone or network.
@MainActor
enum MacRender {
    static func export(to path: String) {
        let dir = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let rig = Rig(); rig.character = .noodle; rig.chrome = false; rig.mode = .portrait
        for state in [ChumsState.idle, .needs, .working, .listening, .thinking, .speaking] {
            rig.restState = state; rig.setState(state)
            for _ in 0..<100 { rig.tick(1.0 / 30) }
            let view = Canvas { context, size in Renderer.draw(rig, context, size: size, background: nil) }
                .frame(width: 198, height: 242)
            let renderer = ImageRenderer(content: view); renderer.scale = 3
            if let image = renderer.cgImage {
                let file = dir.appendingPathComponent("noodle-\(state.rawValue).png")
                if let destination = CGImageDestinationCreateWithURL(file as CFURL, UTType.png.identifier as CFString, 1, nil) {
                    CGImageDestinationAddImage(destination, image, nil); CGImageDestinationFinalize(destination)
                }
            }
        }
        for mode in ["idle", "recording", "paused", "review"] {
            let model = MacModel()
            model.connected = true
            model.status = "On fait quoi ensemble ?"
            model.listening = mode == "recording" || mode == "paused"
            model.paused = mode == "paused"
            if mode == "review" { model.voiceDraft = "Peux-tu reprendre notre tâche et me résumer la prochaine étape ?" }
            model.rig.restState = model.listening && !model.paused ? .listening : .idle
            model.rig.setState(model.rig.restState)
            for _ in 0..<100 { model.rig.tick(1.0 / 30) }
            let renderer = ImageRenderer(content: PetView(model: model, open: {}).environment(\.colorScheme, .dark))
            renderer.proposedSize = ProposedViewSize(width: 260, height: 390)
            renderer.scale = 2
            if let image = renderer.cgImage {
                let file = dir.appendingPathComponent("pet-ui-\(mode).png")
                if let destination = CGImageDestinationCreateWithURL(file as CFURL, UTType.png.identifier as CFString, 1, nil) {
                    CGImageDestinationAddImage(destination, image, nil); CGImageDestinationFinalize(destination)
                }
            }
        }
        print("Exported offline Noodle poses and pet UI states (no microphone or network).")
    }
}
