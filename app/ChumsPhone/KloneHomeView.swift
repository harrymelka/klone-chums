import SwiftUI
import WidgetKit

/// Klone's light, full-screen presentation. Upstream HomeView stays available for merges.
/// Audio, the rig, approvals and history still use the shared Chums screen engine.
struct KloneHomeView: View {
    let hub: HubClient
    @State private var model: ScreenModel
    @State private var draft = ""
    @State private var notice: String?
    @State private var sending = false
    @State private var deciding = false
    @State private var settings = false
    @State private var fullThread = false
    @State private var showWriting = false
    @State private var prepared = false
    @State private var pendingTalk = false
    @State private var viewing: Artifact?
    @State private var lastWidgetReload = Date.distantPast
    @FocusState private var typing: Bool
    @AppStorage("voice") private var voice = true
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    private let ground = Color(red: 0.918, green: 0.902, blue: 0.867)
    private let ink = Color(red: 0.19, green: 0.17, blue: 0.21)
    private let quiet = Color(red: 0.43, green: 0.40, blue: 0.44)

    init(hub: HubClient) {
        self.hub = hub
        let m = ScreenModel(hub: hub)
        m.rig.chrome = false; m.rig.character = .noodle; m.rig.mode = .portrait
        _model = State(initialValue: m)
    }
    private var agent: AgentInfo { model.controller.info("noodle") }
    private var approval: Approval? { hub.state?.approvals.first { $0.session == "noodle" } }
    private var busy: Bool { sending || model.controller.talk == .sending }
    private var working: Bool { ["working", "compacting"].contains(agent.status) }
    private var canStart: Bool { prepared && hub.connected && !busy && !working }
    private var title: String {
        if model.listening { return "Je t’écoute." }
        if busy { return "Je transmets…" }
        if !hub.connected { return hub.state == nil ? "Connexion à Hermès…" : "Je me reconnecte…" }
        if approval != nil || agent.needs || agent.status == "waiting" { return "Une question pour toi." }
        if working { return "Je m’en occupe." }
        if model.controller.talk == .speaking { return "Voici ce que j’ai trouvé." }
        if ["blocked", "limited", "offline"].contains(agent.status) { return "Regardons ça ensemble." }
        return "Je suis là."
    }
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header
                VStack(spacing: 5) {
                    Text(model.listening ? "À TOI" : "AVEC TOI")
                        .font(.system(size: 10, weight: .medium)).tracking(2).foregroundStyle(quiet)
                    Text(title).font(.system(.title2, design: .rounded, weight: .semibold))
                        .multilineTextAlignment(.center).padding(.horizontal, 20)
                }.padding(.top, 10)
                if !typing && !typeSize.isAccessibilitySize {
                    CharacterStage(model: model, agent: agent, small: false,
                                   paused: settings || fullThread || phase != .active,
                                   open: { fullThread = true }, settings: { settings = true },
                                   background: nil, magnification: 1.34, verticalOffset: -0.08)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(canStart || model.listening)
                        .accessibilityHint("Personnage Hermès. Maintiens pour parler, ou utilise le bouton Parler.")
                }
                VStack(spacing: 0) {
                    HStack {
                        Text("NOTRE CONVERSATION").font(.system(size: 10, weight: .semibold)).tracking(1.4)
                        Spacer()
                        Button { fullThread = true } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                            .frame(width: 44, height: 44).accessibilityLabel("Agrandir la conversation")
                    }.foregroundStyle(quiet)
                    thread
                }
                .padding(.horizontal, 24)
                .frame(height: typing || typeSize.isAccessibilitySize ? nil : max(150, geometry.size.height * 0.31))
                .frame(maxHeight: typing || typeSize.isAccessibilitySize ? .infinity : nil)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { composer }
        .background(ground.ignoresSafeArea())
        .foregroundStyle(ink)
        .task {
            guard !prepared else { return }
            model.onNotice = { text in notice = text == ScreenModel.micRefused ? "Autorise le microphone pour Klone Chums dans les Réglages de l’iPhone." : text }
            await model.prepare()
            model.setAgent("noodle"); prepared = true
            await hub.focus("noodle")
            if pendingTalk { pendingTalk = false; talk() }
        }
        .onChange(of: phase) { _, value in
            if value == .background {
                model.micUp(cancel: true)
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        .onChange(of: typing) { _, on in if on { hush(); hub.nudge() } }
        .onChange(of: hub.state?.rev) { _, _ in
            if Date().timeIntervalSince(lastWidgetReload) > 20 {
                lastWidgetReload = Date(); WidgetCenter.shared.reloadAllTimelines()
            }
        }
        .onOpenURL { url in
            guard let link = PhoneLink(url) else { return }
            switch link {
            case .agent: fullThread = true
            case .talk:
                if prepared { talk() } else { pendingTalk = true }
            }
        }
        .accessibilityAction(.magicTap) { talk() }
        .sheet(isPresented: $settings) {
            AppSettings(hub: hub, character: agent.character).preferredColorScheme(.dark)
        }
        .sheet(isPresented: $fullThread, onDismiss: { model.micUp(cancel: true) }) {
            VStack(spacing: 0) {
                HStack {
                    Text("Notre conversation").font(.headline)
                    Spacer()
                    Button("Fermer") { fullThread = false }
                }.padding(20)
                thread.padding(.horizontal, 24)
                composer
            }
            .background(ground.ignoresSafeArea()).foregroundStyle(ink)
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $viewing) { ArtifactSheet(artifact: $0, character: agent.character).preferredColorScheme(.dark) }
    }
    private var header: some View {
        HStack {
            Button { fullThread = true } label: { Image(systemName: "text.bubble") }
                .frame(width: 44, height: 44).accessibilityLabel("Ouvrir toute la conversation")
            Spacer()
            Text("Hermès").font(.system(.body, weight: .semibold))
            Spacer()
            Button { model.micUp(cancel: true); settings = true } label: { Image(systemName: "ellipsis") }
                .frame(width: 44, height: 44).accessibilityLabel("Réglages")
        }.padding(.horizontal, 14).frame(height: 50)
    }
    private var thread: some View {
        ScrollViewReader { scroll in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if model.conversation.isEmpty {
                        Text(hub.connected ? "Dis-moi ce que tu veux faire. Ton fil sera le même sur l’iPhone, la Watch et le Mac." : "Je retrouve notre conversation…")
                            .font(.body).foregroundStyle(quiet).padding(.vertical, 12)
                    }
                    ForEach(model.conversation) { line in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(line.who == .you ? "TOI" : line.who == .note ? "INFORMATION" : "HERMÈS")
                                .font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(quiet)
                            Text(line.text).font(.system(.subheadline)).textSelection(.enabled)
                            if let artifact = line.artifact {
                                Button(artifact.title) { viewing = artifact }.font(.subheadline)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).id(line.id)
                    }
                    Color.clear.frame(height: 4).id("end")
                }.padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear { scroll.scrollTo("end", anchor: .bottom) }
            .onChange(of: model.conversation.last?.id) { _, _ in
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { scroll.scrollTo("end", anchor: .bottom) }
            }
        }
    }
    private var composer: some View {
        VStack(spacing: 9) {
            if let approval {
                VStack(alignment: .leading, spacing: 9) {
                    Label("Hermès demande ton accord", systemImage: "questionmark.bubble").font(.subheadline.weight(.semibold))
                    ScrollView { Text(approval.description).font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                        .frame(maxHeight: 100)
                    HStack {
                        Button("Refuser") { decide(approval, allow: false) }
                        Spacer()
                        Button("Autoriser cette fois") { decide(approval, allow: true) }.fontWeight(.semibold)
                    }.disabled(deciding)
                }.padding(14).background(ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
            }
            if let notice {
                HStack(alignment: .top) {
                    Text(notice).font(.caption)
                    Spacer()
                    Button { self.notice = nil } label: { Image(systemName: "xmark") }.frame(width: 32, height: 32).accessibilityLabel("Fermer le message")
                }
            }
            if showWriting && !model.listening {
                HStack(alignment: .bottom) {
                    TextField("Écrire à Hermès…", text: $draft, axis: .vertical)
                        .lineLimit(1...4).focused($typing).padding(12)
                        .background(ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                        .onSubmit { send() }
                    Button(action: send) { Image(systemName: "arrow.up").frame(width: 44, height: 44) }
                        .disabled(!canStart || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityLabel("Envoyer le message écrit")
                }
            }
            HStack(spacing: 10) {
                if model.listening {
                    Button { model.micUp(cancel: true) } label: { Image(systemName: "xmark").frame(width: 46, height: 46) }
                        .accessibilityLabel("Annuler l’enregistrement")
                } else {
                    Button {
                        showWriting.toggle(); typing = showWriting
                    } label: { Image(systemName: showWriting ? "keyboard.chevron.compact.down" : "keyboard").frame(width: 46, height: 46) }
                        .accessibilityLabel(showWriting ? "Masquer le clavier" : "Écrire un message")
                }
                Button(action: talk) {
                    HStack(spacing: 9) {
                        if busy { ProgressView().tint(ground) }
                        else { Image(systemName: model.listening ? "arrow.up" : "mic.fill") }
                        Text(model.listening ? "Envoyer" : busy ? "Envoi…" : "Parler").fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(ink, in: Capsule()).foregroundStyle(ground)
                }
                .disabled(!model.listening && !canStart)
                .opacity(!model.listening && !canStart ? 0.5 : 1)
                .accessibilityIdentifier("klone-phone-microphone")
                Button {
                    if model.controller.talk == .speaking { hush() }
                    else { voice.toggle() }
                } label: {
                    Image(systemName: model.controller.talk == .speaking ? "stop.fill" : voice ? "speaker.wave.2" : "speaker.slash")
                        .frame(width: 46, height: 46)
                }.accessibilityLabel(model.controller.talk == .speaking ? "Arrêter la voix" : voice ? "Désactiver les réponses vocales" : "Activer les réponses vocales")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 12)
        .background(ground)
    }
    private func hush() {
        model.hush()
        if model.controller.talk == .speaking { model.controller.talk = .none }
    }
    private func talk() {
        typing = false; notice = nil
        if model.listening { model.micUp(cancel: false) }
        else if canStart { model.micDown() }
    }
    private func send() {
        let text = String(draft.trimmingCharacters(in: .whitespacesAndNewlines).prefix(4000))
        guard canStart, !model.listening, !text.isEmpty else { return }
        sending = true; notice = nil
        Task {
            defer { sending = false }
            if let result = await model.send(text: text), result.kind == "order" || result.kind == "verdict" {
                if draft.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(text) { draft = "" }
                typing = false
            } else { notice = "Message non confirmé. Vérifie la conversation avant de le renvoyer." }
        }
    }
    private func decide(_ approval: Approval, allow: Bool) {
        guard !deciding else { return }
        deciding = true
        Task {
            defer { deciding = false }
            if !(await hub.verdict(approval.requestId, allow: allow)) { notice = "L’accord n’a pas été confirmé. Vérifie la connexion et la demande affichée." }
        }
    }
}
