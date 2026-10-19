import SwiftUI
import UIKit

/// The watch's screen for one agent, as a picture: the same character, faces, status, caption and approval card the
/// watch draws (Renderer, with its chrome), for widget snapshots, which transition when their data changes. The rig runs a moment first, so the
/// character has settled into its state.
@MainActor enum WatchScreen {
    static func image(_ agent: WAgent, in state: WState?, size: CGSize, scale: CGFloat = 3, date: Date = .now) async -> UIImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        let r = Rig()
        r.cardControls = false                       // the widget's own Deny and Allow answer it
        if let k = CharacterKind(id: agent.character) { r.character = k }
        let look = Self.look(agent, state, at: date)
        if let a = state?.approval(for: agent.id) {
            r.approvalTitle = a.summary ?? a.description
            r.approvalDetail = a.tool == "Bash" ? a.description : a.tool
        }
        r.restState = look.state
        r.setState(look.state)
        r.label = look.label
        r.caption = look.caption
        r.faces = faces(agent, state)
        for _ in 0..<45 { r.tick(1.0 / 30) }
        let view = Canvas { ctx, sz in Renderer.draw(r, ctx, size: sz) }
            .frame(width: size.width, height: size.height)
            .environment(\.displayScale, scale)
        func draw() -> UIImage? { let ir = ImageRenderer(content: view); ir.scale = scale; return ir.uiImage }
        // Stretch's frames are decoded off the main thread: the first drawing asks for them, a second one has them
        if r.character == .stretch { _ = draw(); try? await Task.sleep(for: .milliseconds(300)) }
        return draw()
    }

    /// The watch's state, status and caption for an agent (Controller.restFor, from what the widgets get).
    static func look(_ a: WAgent, _ s: WState?, at date: Date = .now) -> (state: ChumsState, label: String, caption: String) {
        guard let s else { return (.sleep, "HORS LIGNE", "Je ne joins pas le Mac") }
        if s.approval(for: a.id) != nil { return (.approval, "TU M’AUTORISES ?", "") }
        switch a.status {
        case "offline": return (.sleep, "HORS LIGNE", "Je ne joins pas le Mac")
        case "blocked": return (.blocked, "UN COUP DE MAIN ?", a.line ?? "J’ai besoin de toi")
        case "limited": return (.blocked, "JE PATIENTE", "Je reprendrai quand ce sera possible")
        case "compacting": return (.thinking, "JE RANGE MES IDÉES", "")
        case "working": return (.working, "JE M’EN OCCUPE", "")
        default: return a.needs || a.status == "waiting"
            ? (.needs, "UNE QUESTION", a.line ?? "Tu peux me répondre ?")
            : (.idle, "", companionInvitation(in: s, at: date))
        }
    }

    /// The faces at the top left, as on the watch: this agent, then at most two others, the ones that need you first.
    static func faces(_ a: WAgent, _ s: WState?) -> [(character: String, needs: Bool)] {
        let others = (s?.byUrgency ?? []).filter { $0.id != a.id }
        return [(a.character, false)] + others.prefix(2).map { ($0.character, $0.needs) }
    }
}
