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

/// The conversation as a card of Liquid Glass that slides up from the handle at the bottom of the screen: the
/// character stays visible through it, blurred. It opens at the newest message; the crown scrolls back. Dragging its
/// top edge down puts it away. The balloons are nearly solid so the text reads over anything behind the glass.
struct ChatPanel: View {
    let lines: [ChatLine]
    var open: (Artifact) -> Void = { _ in }
    /// Simulator captures: scroll to a line (or "end"), as a finger would, over that many seconds.
    var scroll: (id: String, seconds: Double)? = nil
    var listening = false
    var sending = false
    var talk: (() -> Void)? = nil
    var cancel: (() -> Void)? = nil
    var close: (() -> Void)? = nil
    var reportScroll: ((String) -> Void)? = nil
    @FocusState private var focused: Bool
    @State private var position = ScrollPosition()
    @State private var crown = 0.0
    @State private var scrollMetrics = ChatScrollMetrics()
    @State private var lastScrollReport = Date.distantPast

    private struct ChatScrollMetrics: Equatable {
        var offset: CGFloat = 0
        var minimum: CGFloat = 0
        var maximum: CGFloat = 0
        var viewport: CGFloat = 0
    }

    static let card = UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22)

    var body: some View {
        // One card owns the thread and composer. Only the messages scroll, so the controls
        // stay inside the card rather than looking like a separate strip below it.
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 8) {
                                Color.clear.frame(height: 18).id("top")
                                if lines.isEmpty {
                                    Text(talk == nil ? "Hold the screen and talk; the conversation shows up here." : "Touche Parler pour commencer la conversation.")
                                        .font(.system(size: 14)).foregroundStyle(Pal.gray)
                                        .multilineTextAlignment(.center).padding(.top, 16)
                                }
                                ForEach(lines) { l in bubble(l).id(l.id) }
                                Color.clear.frame(height: 12).id("end")
                            }
                            .padding(.horizontal, 6)
                        }
                        // Native finger scrolling remains enabled; the card owns a single explicit
                        // Crown receiver instead of competing with the character's receiver.
                        .focusable(false)
                        .scrollPosition($position)
                        .onScrollGeometryChange(for: ChatScrollMetrics.self) { geometry in
                            ChatScrollMetrics(offset: geometry.contentOffset.y,
                                              minimum: -geometry.contentInsets.top,
                                              maximum: max(-geometry.contentInsets.top, geometry.contentSize.height - geometry.containerSize.height + geometry.contentInsets.bottom),
                                              viewport: geometry.containerSize.height)
                        } action: { old, metrics in
                            scrollMetrics = metrics
                            diagnostic("geometry", force: old.viewport == 0 && metrics.viewport > 0)
                        }
                        .accessibilityIdentifier("watch-chat-thread")
                        .task {
                            // Wait for the overlay to enter the focus tree before taking the Crown.
                            await Task.yield()
                            guard !Task.isCancelled else { return }
                            proxy.scrollTo("end", anchor: .bottom)
                            focused = true
                        }
                        .onChange(of: listening) { focused = true }
                        .onChange(of: sending) { focused = true }
                        .onChange(of: lines.count) { withAnimation { proxy.scrollTo("end", anchor: .bottom) } }
                        .onChange(of: scroll?.id) { _, id in
                            guard let id, let s = scroll else { return }
                            withAnimation(.easeInOut(duration: s.seconds)) { proxy.scrollTo(id, anchor: id == "end" ? .bottom : .top) }
                        }
                        .mask {
                            // The last message eases into the fixed composer instead of ending at a hard cut.
                            if talk != nil {
                                VStack(spacing: 0) {
                                    Color.black
                                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                                        .frame(height: 12)
                                }
                            } else { Color.black }
                        }
                    }
                    Grabber().padding(.top, 6).allowsHitTesting(false)
                }
                // A fixed viewport is essential: if the scroll view measures to its content
                // height there is no overflow for either a finger or the Crown to move.
                .frame(height: max(0, geometry.size.height - (talk == nil ? 0 : 58)))
                if let talk { composer(talk: talk) }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .clipShape(Self.card)
        .glassEffect(.regular.tint(.black.opacity(0.32)), in: Self.card)
#if os(watchOS)
        .focusable().focused($focused)
        .digitalCrownRotation($crown, from: 0, through: 60, by: 1, sensitivity: .medium,
                              isContinuous: true, isHapticFeedbackEnabled: true)
        .onChange(of: crown) { old, new in
            var delta = new - old
            if delta > 30 { delta -= 60 } else if delta < -30 { delta += 60 }
            let target = min(scrollMetrics.maximum, max(scrollMetrics.minimum, scrollMetrics.offset + CGFloat(delta) * 14))
            position.scrollTo(y: target)
            diagnostic("crown delta=\(delta) target=\(Int(target))")
        }
#endif
    }

    private func diagnostic(_ event: String, force: Bool = false) {
        guard let reportScroll else { return }
        let now = Date()
        guard force || now.timeIntervalSince(lastScrollReport) >= 1 else { return }
        lastScrollReport = now
        reportScroll("chat scroll \(event) viewport=\(Int(scrollMetrics.viewport)) offset=\(Int(scrollMetrics.offset)) min=\(Int(scrollMetrics.minimum)) max=\(Int(scrollMetrics.maximum))")
    }

    private func composer(talk: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            if listening {
                Button { cancel?(); focused = true } label: {
                    Image(systemName: "xmark").frame(width: 38, height: 44)
                }
                .accessibilityLabel("Annuler l’enregistrement")
            }
            Button { talk(); focused = true } label: {
                HStack(spacing: 6) {
                    if sending { ProgressView().controlSize(.small) }
                    else { Image(systemName: listening ? "arrow.up" : "mic.fill") }
                    Text(sending ? "Envoi…" : listening ? "Envoyer" : "Parler")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(listening ? Pal.green : Color.white.opacity(0.15), in: Capsule())
                .foregroundStyle(listening ? .black : .white)
            }
            .disabled(sending)
            .accessibilityIdentifier("chat-microphone")
            .accessibilityLabel(listening ? "Envoyer le message vocal" : "Parler dans la conversation")
            if !listening, let close {
                Button(action: close) {
                    Image(systemName: "chevron.down").frame(width: 38, height: 44)
                }
                .accessibilityLabel("Fermer la conversation")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10).padding(.top, 2).padding(.bottom, 12)
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
