import AppIntents
import SwiftUI
import UIKit
import WidgetKit

// What the widgets draw (ChumsPhoneWidgets), here so the app can draw them too: its debug build renders every size to
// pictures (-widgetShots), to check them without putting them on a Home Screen.

struct ChumsEntry: TimelineEntry {
    let date: Date
    let state: WState?
    let pick: String?                       // the agent chosen in the widget's settings; nil: the one you last talked to
    var screen: UIImage? = nil              // the watch's screen for the agent (WatchScreen), on the Home Screen sizes
    var agent: WAgent? { pick.flatMap { id in state?.agents.first { $0.id == id } } ?? state?.current }

    /// An entry with the watch's screen drawn for a Home Screen widget of this family and size.
    static func make(_ state: WState?, pick: String?, family: WidgetFamily, size: CGSize) async -> ChumsEntry {
        var e = ChumsEntry(date: .now, state: state, pick: pick)
        guard let a = e.agent, family == .systemSmall || family == .systemMedium else { return e }
        let h = size.height, sz = family == .systemMedium ? CGSize(width: (h * DESIGN.width / DESIGN.height).rounded(), height: h) : size
        e.screen = await WatchScreen.image(a, in: state, size: sz, date: e.date)
        return e
    }
}

/// What an agent is doing, in a word or two.
func shortStatus(_ a: WAgent) -> String {
    if a.needs || a.status == "waiting" { return "J’ai une question" }
    switch a.status {
    case "offline": return "Je ne joins pas le Mac"
    case "working": return "Je m’en occupe"
    case "compacting": return "Je range mes idées"
    case "limited": return "Je dois patienter"
    case "blocked": return "Un coup de main ?"
    default: return companionInvitation()
    }
}

struct AgentWidgetView: View {
    let entry: ChumsEntry
    var shownAs: WidgetFamily?                       // set by the app's pictures; in a widget, the widget's own size
    @Environment(\.widgetFamily) private var widgetFamily
    private var family: WidgetFamily { shownAs ?? widgetFamily }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var luminanceReduced

    var body: some View {
        if let a = entry.agent {
            switch family {
            case .accessoryCircular: circular(a)
            case .accessoryRectangular: rectangular(a)
            case .accessoryInline: Text("\(a.name) · \(headline(a))")
            case .systemMedium: medium(a)
            default: small(a)
            }
        } else {
            VStack(spacing: 4) {
                Image(systemName: "wifi.exclamationmark").font(.title3)
                Text("Je ne joins pas le Mac").font(.caption).multilineTextAlignment(.center)
            }
            .foregroundStyle(.secondary)
            .padding(12)
        }
    }

    private func headline(_ a: WAgent) -> String {
        if entry.state?.approval(for: a.id) != nil { return "Tu m’autorises ?" }
        if a.status == "idle" && !a.needs { return companionInvitation(in: entry.state, at: entry.date) }
        return shortStatus(a)
    }

    private func poseID(_ a: WAgent) -> String {
        // Do not include rev/date: ordinary polls must not replay the transition.
        "\(a.id):\(a.character):\(a.status):\(a.needs):\(entry.state?.approval(for: a.id)?.requestId ?? "")"
    }

    /// State-specific snapshots share the app renderer. WidgetKit animates their replacement,
    /// not a continuously running Canvas. Always On and Reduce Motion keep the update still.
    @ViewBuilder private func screen(_ a: WAgent) -> some View {
        ZStack {
            Group {
                if let img = entry.screen { Image(uiImage: img).resizable().scaledToFit() }
                else { WidgetFace(character: a.character, size: 64).frame(maxWidth: .infinity, maxHeight: .infinity) }
            }
            .id(poseID(a))
            .transition(reduceMotion || luminanceReduced ? .identity : .opacity.combined(with: .scale(scale: 0.96)))
            if a.needs || a.status == "waiting" || entry.state?.approval(for: a.id) != nil {
                Text("?").font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Pal.amber)
                    .padding(8).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .accessibilityLabel(entry.state?.approval(for: a.id) != nil ? "Autorisation demandée" : "Une question pour toi")
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion || luminanceReduced ? nil : .easeOut(duration: 0.45), value: poseID(a))
    }

    /// Talk (the microphone), or Deny and Allow when it asks: round buttons over the screen's bottom right corner.
    @ViewBuilder private func cornerButtons(_ a: WAgent) -> some View {
        if let ap = entry.state?.approval(for: a.id) {
            HStack(spacing: 6) {
                Button(intent: AnswerApproval(ap.requestId, allow: false)) { RoundIcon(symbol: "xmark", light: false) }.accessibilityLabel("Refuser cette demande")
                Button(intent: AnswerApproval(ap.requestId, allow: true)) { RoundIcon(symbol: "checkmark", light: true) }.accessibilityLabel("Autoriser cette demande")
            }
            .buttonStyle(.plain)
        } else {
            Link(destination: URL(string: "chums://talk/\(a.id)")!) { RoundIcon(symbol: "mic.fill", light: true) }
                .accessibilityLabel("Parler à \(a.name)")
        }
    }

    /// The watch's screen, edge to edge, with the corner buttons.
    private func small(_ a: WAgent) -> some View {
        screen(a)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottomTrailing) { cornerButtons(a).padding(10) }
            .widgetURL(URL(string: "chums://agent/\(a.id)"))
    }

    /// The watch's screen on the left; its name, what it's doing and its last line on the right, the buttons along the
    /// bottom of that column.
    private func medium(_ a: WAgent) -> some View {
        let ap = entry.state?.approval(for: a.id)
        return HStack(spacing: 0) {
            screen(a).frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 0) {
                Text(a.name).font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                Text(headline(a)).contentTransition(.opacity)
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(a.needs || ap != nil ? Pal.amber : Color(white: 0.55))
                Text(ap.map { $0.summary ?? $0.description } ?? ((a.needs || a.status != "idle") ? (a.line ?? "") : "Touche le micro pour discuter"))
                    .font(.system(size: 13)).foregroundStyle(Color(white: 0.8)).lineLimit(3)
                    .padding(.top, 6)
                Spacer(minLength: 8)
                HStack(spacing: 8) {
                    if let ap {
                        Button(intent: AnswerApproval(ap.requestId, allow: false)) { WideButton(symbol: "xmark", text: "Refuser", light: false) }
                        Button(intent: AnswerApproval(ap.requestId, allow: true)) { WideButton(symbol: "checkmark", text: "Autoriser", light: true) }
                    } else {
                        Link(destination: URL(string: "chums://talk/\(a.id)")!) { WideButton(symbol: "mic.fill", text: "Parler", light: true) }
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.vertical, 14).padding(.leading, 6).padding(.trailing, 14)
        }
        .widgetURL(URL(string: "chums://agent/\(a.id)"))
    }

    private func circular(_ a: WAgent) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            WidgetFace(character: a.character, size: 46, plate: false)
            if a.needs || entry.state?.approval(for: a.id) != nil {
                Text("?").font(.headline).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).widgetAccentable()
            }
        }
        .widgetURL(URL(string: "chums://agent/\(a.id)"))
    }

    private func rectangular(_ a: WAgent) -> some View {
        HStack(spacing: 8) {
            WidgetFace(character: a.character, size: 34, plate: false)
            VStack(alignment: .leading, spacing: 1) {
                Text(a.name).font(.headline).widgetAccentable()
                Text(headline(a)).font(.caption).lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "chums://agent/\(a.id)"))
    }
}

// MARK: every agent

struct TeamWidgetView: View {
    let entry: ChumsEntry
    var shownAs: WidgetFamily?                       // set by the app's pictures; in a widget, the widget's own size
    @Environment(\.widgetFamily) private var widgetFamily
    private var family: WidgetFamily { shownAs ?? widgetFamily }

    var body: some View {
        let agents = entry.state?.byUrgency ?? []
        let cols = family == .systemLarge ? 3 : 5
        VStack(alignment: .leading, spacing: 10) {
            if family == .systemLarge {
                HStack {
                    Text("Klone Chums").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                    Spacer()
                    let n = agents.filter(\.needs).count, working = agents.filter { $0.status == "working" }.count
                    Text(entry.state == nil ? "Mac injoignable" : n > 0 ? "\(n) question(s)" : working > 0 ? "\(working) en cours" : companionInvitation(in: entry.state, at: entry.date))
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(n > 0 ? Pal.amber : Color(white: 0.55))
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: cols), spacing: family == .systemLarge ? 12 : 6) {
                ForEach(agents.prefix(family == .systemLarge ? 9 : 5)) { a in
                    Link(destination: URL(string: "chums://agent/\(a.id)")!) {
                        VStack(spacing: 4) {
                            WidgetFace(character: a.character, size: family == .systemLarge ? 52 : 44)
                                .overlay(alignment: .bottomTrailing) { WidgetDot(agent: a).offset(x: 2, y: 2) }
                            Text(a.name).font(.system(size: 11, weight: .medium)).foregroundStyle(.white).lineLimit(1)
                            if family == .systemLarge {
                                Text(shortStatus(a))
                                    .font(.system(size: 10)).foregroundStyle(a.needs ? Pal.amber : Color(white: 0.5))
                            }
                        }
                    }
                }
            }
            if family == .systemLarge, let ap = entry.state?.approvals.first,
               let who = agents.first(where: { $0.id == ap.session }) {
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    WidgetFace(character: who.character, size: 28)
                    Text("\(who.name): \(ap.summary ?? ap.description)").font(.system(size: 12)).foregroundStyle(Color(white: 0.85)).lineLimit(2)
                    Spacer(minLength: 4)
                    Button(intent: AnswerApproval(ap.requestId, allow: false)) { Image(systemName: "xmark") }.tint(Color(white: 0.25))
                    Button(intent: AnswerApproval(ap.requestId, allow: true)) { Text("Autoriser").bold() }.tint(.white).foregroundStyle(.black)
                }
                .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).controlSize(.small)
            }
        }
    }
}

// MARK: parts

/// An agent's face, as in the app: the character on a dark circle (on the Lock Screen, without the circle).
struct WidgetFace: View {
    let character: String
    var size = 40.0
    var plate = true
    var body: some View {
        ZStack {
            if plate { Circle().fill(.black) }
            Image("avatar-\(character)").resizable()
                .interpolation(AgentFace.fullBleed.contains(character) ? .high : .none)
                .scaledToFit()
                .padding(AgentFace.fullBleed.contains(character) ? 0 : size * 0.1)
        }
        .frame(width: size, height: size).clipShape(Circle())
    }
}

/// Amber: needs you. White: working. Red: stuck. Gray: idle. Dim: not running.
struct WidgetDot: View {
    let agent: WAgent
    var body: some View {
        let c: Color = agent.needs ? Pal.amber : agent.status == "working" || agent.status == "compacting" ? .white
            : agent.status == "blocked" ? .red : agent.status == "offline" ? Color(white: 0.25) : Color(white: 0.5)
        Circle().fill(c).frame(width: 10, height: 10).overlay(Circle().strokeBorder(.black, lineWidth: 2))
    }
}

/// A round button for a widget's corner: white with a black symbol, or dark with a white one.
struct RoundIcon: View {
    let symbol: String
    let light: Bool
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(light ? .black : .white)
            .frame(width: 34, height: 34)
            .background(light ? Color.white : Color(white: 0.22), in: Circle())
    }
}

/// A full-width capsule button for the wide widget.
struct WideButton: View {
    let symbol: String
    let text: String
    let light: Bool
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 13, weight: .bold))
            Text(text).font(.system(size: 15, weight: .semibold))
        }
        .foregroundStyle(light ? .black : .white)
        .frame(maxWidth: .infinity).frame(height: 36)
        .background(light ? Color.white : Color(white: 0.2), in: Capsule())
    }
}

