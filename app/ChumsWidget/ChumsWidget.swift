import WidgetKit
import SwiftUI

/// A stateful glance, not a continuously running miniature app. WidgetKit owns refresh timing.
@main
struct ChumsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "chums", provider: Provider()) { ChumsWidgetView(entry: $0) }
            .configurationDisplayName("Klone Chums")
            .description("Ton compagnon Hermès et son dernier état. Touche pour ouvrir le chat et parler.")
            .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner, .accessoryInline])
    }
}

struct Entry: TimelineEntry {
    let date: Date
    let agent: WAgent?
    let updatedAt: Date?
    var stale: Bool {
        guard let updatedAt else { return true }
        return date.timeIntervalSince(updatedAt) >= 15 * 60
    }
    var label: String {
        guard !stale, let agent else { return "Parler" }
        if agent.needs || agent.status == "waiting" { return "Une question" }
        switch agent.status {
        case "working": return "Travaille"
        case "compacting": return "Réfléchit"
        case "blocked": return "À vérifier"
        case "limited": return "En attente"
        case "offline": return "Hors ligne"
        default: return "Parler"
        }
    }
    var attention: Bool { !stale && (agent?.needs == true || agent?.status == "waiting") }
    var pose: String {
        if attention { return "needs" }
        guard !stale else { return "idle" }
        if agent?.status == "working" { return "working" }
        if agent?.status == "compacting" { return "thinking" }
        return "idle"
    }
    var symbol: String {
        guard !stale, let agent else { return "arrow.clockwise" }
        if agent.needs || agent.status == "waiting" { return "questionmark" }
        switch agent.status {
        case "working", "compacting": return "ellipsis"
        case "blocked", "limited", "offline": return "exclamationmark"
        default: return "mic.fill"
        }
    }
    var tint: Color {
        guard !stale, let agent else { return .secondary }
        if agent.needs || agent.status == "waiting" { return .orange }
        if agent.status == "blocked" { return .red }
        if ["working", "compacting"].contains(agent.status) { return .blue }
        return .green
    }
}

struct Provider: TimelineProvider {
    private let agentKey = "klone.complication.agent"
    private let dateKey = "klone.complication.date"
    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, agent: WAgent(id: "noodle", name: "Hermès", character: "noodle", status: "idle", line: nil, needs: false), updatedAt: .now)
    }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        if context.isPreview { completion(placeholder(in: context)) }
        else { Task { completion(await current()) } }
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        Task {
            let entry = await current()
            // If the system defers the next reload, explicitly age out an old working/approval state.
            let expiry = (entry.updatedAt ?? entry.date).addingTimeInterval(15 * 60)
            let stale = Entry(date: max(expiry, entry.date.addingTimeInterval(1)), agent: entry.agent, updatedAt: entry.updatedAt)
            completion(Timeline(entries: [entry, stale], policy: .after(entry.date.addingTimeInterval(15 * 60))))
        }
    }
    private func current() async -> Entry {
        let now = Date()
        if let state = await WidgetHub.state(), let a = state.current {
            // Never cache conversation text for a watch-face complication.
            let agent = WAgent(id: a.id, name: a.name, character: a.character, status: a.status, line: nil, needs: a.needs)
            if let data = try? JSONEncoder().encode(agent) {
                UserDefaults.standard.set(data, forKey: agentKey)
                UserDefaults.standard.set(now, forKey: dateKey)
            }
            return Entry(date: now, agent: agent, updatedAt: now)
        }
        let cached = UserDefaults.standard.data(forKey: agentKey).flatMap { try? JSONDecoder().decode(WAgent.self, from: $0) }
        return Entry(date: now, agent: cached, updatedAt: UserDefaults.standard.object(forKey: dateKey) as? Date)
    }
}

struct ChumsWidgetView: View {
    let entry: Entry
    @Environment(\.widgetFamily) private var family
    @Environment(\.isLuminanceReduced) private var reduced
    private var character: String {
        let value = entry.agent?.character ?? "noodle"
        return ["noodle", "stretch", "peeps", "squint", "ray", "tangle", "crunch", "nana"].contains(value) ? value : "noodle"
    }
    private var face: some View {
        ZStack(alignment: .topTrailing) {
            Image(character == "noodle" ? "noodle-\(entry.pose)" : "avatar-\(character)")
                .resizable().widgetAccentedRenderingMode(.fullColor).scaledToFit()
                .scaleEffect(character == "noodle" ? 1.4 : 1)
                .id(entry.pose)
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
            if entry.attention {
                Text("?").font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange).padding(2)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(reduced ? nil : .easeOut(duration: 0.45), value: entry.pose)
        .accessibilityHidden(true)
    }
    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                HStack(spacing: 8) {
                    face.frame(width: 56, height: 56)
                    if entry.label == "Parler" {
                        Label("Parler", systemImage: "mic.fill").font(.headline).lineLimit(1)
                    } else {
                        Text(entry.label).font(.headline).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
            case .accessoryInline:
                Label(entry.label, systemImage: entry.symbol)
            case .accessoryCorner:
                face.padding(4).widgetLabel { Text(entry.label) }
            default:
                face.padding(5)
            }
        }
        .containerBackground(for: .widget) { Color.black }
        .widgetURL(URL(string: "klonechums://talk"))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hermès, \(entry.label). Ouvrir le chat et commencer un message vocal.")
    }
}
