import SwiftUI

/// One line of the conversation: what you said, what Chums said, or a note (an approval answered, an action Claude
/// Code's auto mode refused).
struct ChatLine: Identifiable, Equatable {
    enum Who { case you, chums, note }
    let id: String
    let who: Who
    let text: String
    let artifact: Artifact?
    var refused = false                     // Claude Code's auto mode refused an action, without asking you

    init(_ s: Spoken) {
        id = s.id; artifact = s.artifact; refused = s.kind == "refused"
        switch s.kind {
        case "echo":
            who = .you
            // the hub echoes an order as “what you said” (with the session's name first when there are several)
            text = s.text.replacingOccurrences(of: "“", with: "").replacingOccurrences(of: "”", with: "")
        case "verdict", "refused": who = .note; text = s.text
        default: who = .chums; text = s.text
        }
    }
}

/// A plain native conversation surface. The system ScrollView owns touch and Crown input;
/// its composer stays below the scrolling messages.
struct ChatPanel: View {
    let lines: [ChatLine]
    var open: (Artifact) -> Void = { _ in }
    /// Simulator captures only: request a particular line without handling live scroll input.
    var scroll: (id: String, seconds: Double)? = nil
    var listening = false
    var sending = false
    var talk: (() -> Void)? = nil
    var cancel: (() -> Void)? = nil
    var close: (() -> Void)? = nil
    var character = "noodle"

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 8) {
                        Color.clear.frame(height: 4).id("top")
                        if lines.isEmpty {
                            Text(talk == nil ? "Hold the screen and talk; the conversation shows up here." : "Touche Parler pour commencer la conversation.")
                                .font(.system(size: 14)).foregroundStyle(Pal.gray)
                                .multilineTextAlignment(.center).padding(.top, 16)
                        }
                        ForEach(lines) { line in bubble(line).id(line.id) }
                        Color.clear.frame(height: 8).id("end")
                    }
                    .padding(.horizontal, 6)
                }
                .accessibilityIdentifier("watch-chat-thread")
                .onAppear { proxy.scrollTo("end", anchor: .bottom) }
                .onChange(of: lines.last?.id) { old, _ in
                    // Open initial history at the bottom, and reveal a newly sent message.
                    // Incoming replies never pull someone away from an older message.
                    if old == nil || lines.last?.who == .you {
                        proxy.scrollTo("end", anchor: .bottom)
                    }
                }
                .onChange(of: scroll?.id) { _, id in
                    guard let id, let scroll else { return }
                    withAnimation(.easeInOut(duration: scroll.seconds)) {
                        proxy.scrollTo(id, anchor: id == "end" ? .bottom : .top)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .layoutPriority(1)
            if let talk { composer(talk: talk).fixedSize(horizontal: false, vertical: true) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black)
    }

    private func composer(talk: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            if listening {
                Button { cancel?() } label: {
                    Image(systemName: "xmark").frame(width: 38, height: 44)
                }
                .accessibilityLabel("Annuler l’enregistrement")
            }
            Button(action: talk) {
                HStack(spacing: 6) {
                    if sending { ProgressView().controlSize(.small) }
                    else { Image(systemName: listening ? "arrow.up" : "mic.fill") }
                    Text(sending ? "Envoi…" : listening ? "Envoyer" : "Parler")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(listening ? Pal.green : Color.white.opacity(0.15), in: Capsule())
                .foregroundStyle(listening ? .black : .white)
            }
            .disabled(sending)
            .accessibilityIdentifier("chat-microphone")
            .accessibilityLabel(listening ? "Envoyer le message vocal" : "Parler dans la conversation")
            if let close {
                Button(action: close) {
                    AgentFace(character: character, size: 40)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .accessibilityLabel("Revenir au personnage")
                .accessibilityHint("Ferme la discussion et affiche ton avatar")
                .accessibilityIdentifier("watch-chat-avatar-return")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10).padding(.top, 4).padding(.bottom, 8)
    }

    @ViewBuilder private func bubble(_ l: ChatLine) -> some View {
        switch l.who {
        case .you:
            HStack {
                Spacer(minLength: 24)
                Text(l.text).font(.system(size: 15)).foregroundStyle(Pal.white).fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(Color(hex: 0x3A3D42).opacity(0.92), in: RoundedRectangle(cornerRadius: 14))
            }
        case .chums:
            VStack(alignment: .leading, spacing: 4) {
                if l.artifact.map({ $0.title != l.text }) ?? true {
                    HStack {
                        Text(l.text).font(.system(size: 15)).foregroundStyle(Pal.white).fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(Color(white: 0.17).opacity(0.94), in: RoundedRectangle(cornerRadius: 14))
                        Spacer(minLength: 24)
                    }
                }
                // something it showed you: a pill that opens it
                if let a = l.artifact { ArtifactPill(a: a) { open(a) } }
            }
        case .note:
            Text(l.text).font(.system(size: 11, weight: .medium)).foregroundStyle(Pal.white.opacity(0.75)).frame(maxWidth: .infinity)
                .shadow(color: .black.opacity(0.6), radius: 2)
        }
    }
}

/// Simulator captures: what the scene driver asks screens it can't reach directly (the agents list, a soul) to do,
/// as a finger would: scroll to a row, pick an agent, open a soul, press and let go of its button, save.
@Observable final class Capture {
    static let shared = Capture()
    let touch = TouchShow()
    var listScroll: String?                     // a row of the agents list ("settings" for the Settings row)
    var pick: String?                           // an agent tapped in the list
    var openSoul: String?                       // its soul opened (the Edit in its row)
    var soulScroll: String?                     // "top" or "end"
    var soulPress: Bool?                        // the soul's hold-to-change button: pressed (true), let go (false)
    var soulSave = false                        // Save tapped
}

/// Simulator captures: where a finger is on the screen, drawn as a fingertip on the glass (a soft disc that presses in,
/// holds, slides and lifts off), so a recording shows what was touched.
@Observable final class TouchShow {
    var at: CGPoint = .zero
    var down = false
    var visible = false
}

struct TouchSpot: View {
    let show: TouchShow
    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [.white.opacity(0.42), .white.opacity(0.22)], center: .center, startRadius: 0, endRadius: 17))
            .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1))
            .frame(width: 34, height: 34)
            .shadow(color: .black.opacity(0.35), radius: 5, y: 1)
            .scaleEffect(show.visible ? (show.down ? 0.92 : 1.0) : 1.35)
            .opacity(show.visible ? 1 : 0)
            .position(show.at)
            .animation(.easeOut(duration: 0.22), value: show.visible)
            .animation(.spring(duration: 0.25, bounce: 0.3), value: show.down)
            .allowsHitTesting(false)
    }
}

/// The handle: on the screen's bottom edge to pull the conversation up, and on the card's top edge to put it away.
struct Grabber: View {
    /// Under the character: gray and short, so it doesn't read as a mouth under the eyes.
    var quiet = false
    var body: some View {
        Capsule().fill(Color(white: quiet ? 0.4 : 0.86)).frame(width: quiet ? 28 : 46, height: quiet ? 4 : 5)
            .shadow(color: .black.opacity(0.45), radius: 1.5, y: 0.5)
    }
}
