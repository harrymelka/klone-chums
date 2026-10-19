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
        guard !stale, let agent else { return "Ouvrir" }
        if agent.needs || agent.status == "waiting" { return "Besoin de toi" }
        switch agent.status {
        case "working": return "Travaille"
        case "compacting": return "Réfléchit"
        case "blocked": return "À vérifier"
        case "limited": return "En attente"
        case "offline": return "Hors ligne"
        default: return "Prêt"
        }
    }
    var symbol: String {
        guard !stale, let agent else { return "arrow.clockwise" }
        if agent.needs || agent.status == "waiting" { return "exclamationmark.bubble.fill" }
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
    private var character: String {
        let value = entry.agent?.character ?? "noodle"
        return ["noodle", "stretch", "peeps", "squint", "ray", "tangle", "crunch", "nana"].contains(value) ? value : "noodle"
    }
    private var face: some View {
        Image("avatar-\(character)")
            .resizable().widgetAccentedRenderingMode(.fullColor).scaledToFit()
            .accessibilityHidden(true)
    }
    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                HStack(spacing: 6) {
                    face.frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Parler", systemImage: "mic.fill").font(.headline).lineLimit(1)
                        Label(entry.label, systemImage: entry.symbol)
                            .font(.caption2).foregroundStyle(entry.tint).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            case .accessoryInline:
                Label("Parler · \(entry.label)", systemImage: "mic.fill")
            case .accessoryCorner:
                face.padding(4).widgetLabel { Text(entry.label) }
            default:
                ZStack(alignment: .bottomTrailing) {
                    face.padding(5)
                    Image(systemName: entry.symbol).font(.system(size: 9, weight: .bold))
                        .foregroundStyle(entry.tint).padding(3)
                        .background(.black, in: Circle()).padding(1)
                }
            }
        }
        .containerBackground(for: .widget) { Color.black }
        .widgetURL(URL(string: "klonechums://talk"))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hermès, \(entry.label). Ouvrir le chat et commencer un message vocal.")
    }
}
