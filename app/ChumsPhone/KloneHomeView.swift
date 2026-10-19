import SwiftUI
import PhotosUI
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
    @State private var choosingAvatar = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var composerHeight: CGFloat = 80
    @State private var detent = 0
    @GestureState private var sheetDrag: CGFloat = 0
    @State private var photos: [PhotosPickerItem] = []
    @State private var attachments: [Attachment] = []
    @State private var choosingPhotos = false
    @State private var loadingPhotos = false
    @AppStorage("kloneShowThread") private var showThread = true
    @AppStorage("character") private var character = "noodle"
    @AppStorage("kloneLastInteraction") private var lastInteraction = 0.0
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
    private var appearance: CharacterKind { CharacterKind(id: character) ?? .noodle }
    private var shownAgent: AgentInfo {
        AgentInfo(id: agent.id, name: agent.name, character: appearance.rawValue,
                  status: agent.status, line: agent.line, needs: agent.needs, runtime: agent.runtime)
    }
    private var approval: Approval? { hub.state?.approvals.first { $0.session == "noodle" } }
    private var busy: Bool { sending || loadingPhotos || model.controller.talk == .sending }
    private var working: Bool { ["working", "compacting"].contains(agent.status) }
    private var canStart: Bool { prepared && hub.connected && !busy && !working }
    private var title: String {
        if model.listening { return "Je t’écoute." }
        if loadingPhotos { return "Je prépare tes photos…" }
        if busy { return "Je transmets…" }
        if !hub.connected { return hub.state == nil ? "Connexion à Hermès…" : "Je me reconnecte…" }
        if approval != nil { return "J’ai besoin de ton accord." }
        if agent.needs || agent.status == "waiting" { return "J’ai une question pour toi." }
        if working { return "Je m’en occupe." }
        if model.controller.talk == .speaking { return "Voici ce que j’ai trouvé." }
        if ["blocked", "limited", "offline"].contains(agent.status) { return "Regardons ça ensemble." }
        if lastInteraction > 0 && Date().timeIntervalSince1970 - lastInteraction > 4 * 3600 { return "Alors, quoi de neuf ?" }
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "On commence la journée ?"
        case 12..<18: return "Qu’est-ce qu’on fait ensemble ?"
        case 18..<23: return "Comment s’est passée ta journée ?"
        default: return "Encore un petit moment ensemble ?"
        }
    }
    var body: some View {
        GeometryReader { geometry in
            let keyboardInset = max(0, keyboardHeight - geometry.safeAreaInsets.bottom)
            let available = max(160, geometry.size.height - keyboardInset)
            ZStack {
                ground.ignoresSafeArea().onTapGesture { dismissKeyboard() }
                CharacterStage(model: model, agent: shownAgent, small: false,
                               paused: settings || choosingAvatar || phase != .active,
                               open: { revealThread() }, settings: { settings = true },
                               background: nil, magnification: keyboardHeight > 0 ? 0.76 : 1.34,
                               verticalOffset: keyboardHeight > 0 ? -0.28 : -0.05)
                    .colorMultiply(appearance == .peeps ? ink : .white)
                    .frame(width: geometry.size.width, height: geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom)
                    .offset(y: (geometry.safeAreaInsets.bottom - geometry.safeAreaInsets.top) / 2)
                    .allowsHitTesting(canStart || model.listening || typing)
                    .simultaneousGesture(TapGesture().onEnded { if typing { dismissKeyboard() } })
                    .accessibilityHint("Personnage Hermès. Maintiens pour parler, ou utilise le bouton Parler.")
                VStack(spacing: 0) {
                    header
                    TimelineView(.periodic(from: .now, by: 60)) { _ in
                        Text(title).font(.system(.title3, design: .rounded, weight: .semibold))
                            .multilineTextAlignment(.center).padding(.horizontal, 30)
                    }
                    .padding(.bottom, 16)
                    .background(LinearGradient(colors: [ground.opacity(0.94), ground.opacity(0.7), ground.opacity(0)], startPoint: .top, endPoint: .bottom))
                    Spacer(minLength: 0)
                    if showThread {
                        conversationPanel(available: available)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    composer
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { composerHeight = $0 }
                        .padding(.horizontal, 12).padding(.bottom, 10)
                }
                .padding(.bottom, keyboardInset)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: keyboardInset)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea(.keyboard)
        .background(ground.ignoresSafeArea())
        .foregroundStyle(ink)
        .preferredColorScheme(.light)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { event in
            guard let frame = event.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                  let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive })?.windows.first(where: \.isKeyWindow) else { return }
            let local = window.convert(frame, from: window.screen.coordinateSpace)
            keyboardHeight = max(0, window.bounds.maxY - local.minY)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardHeight = 0 }
        .task {
            guard !prepared else { return }
            model.onNotice = { text in notice = text == ScreenModel.micRefused ? "Autorise le microphone pour Klone Chums dans les Réglages de l’iPhone." : text }
            await model.prepare()
            model.setAgent("noodle"); model.rig.character = appearance; prepared = true
            await hub.focus("noodle")
            if pendingTalk { pendingTalk = false; talk() }
        }
        .onChange(of: phase) { _, value in
            if value == .background {
                dismissKeyboard()
                model.micUp(cancel: true)
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        .onChange(of: character) { _, _ in model.rig.character = appearance }
        .photosPicker(isPresented: $choosingPhotos, selection: $photos, maxSelectionCount: max(1, 4 - attachments.count), matching: .images)
        .onChange(of: photos) { _, items in
            guard !items.isEmpty else { return }
            Task { await loadPhotos(items) }
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
            case .agent: revealThread(expanded: true)
            case .talk:
                if prepared { talk() } else { pendingTalk = true }
            }
        }
        .accessibilityAction(.magicTap) { talk() }
        .sheet(isPresented: $settings) {
            AppSettings(hub: hub, character: agent.character).preferredColorScheme(.dark)
        }
        .sheet(isPresented: $choosingAvatar) {
            NavigationStack {
                List {
                    Section {
                        ForEach(SoulView.looks, id: \.self) { id in
                            if let kind = CharacterKind(id: id) {
                                Button {
                                    character = kind.rawValue
                                    choosingAvatar = false
                                } label: {
                                    HStack(spacing: 16) {
                                        AgentFace(character: kind.rawValue, size: 52)
                                            .background(ink, in: RoundedRectangle(cornerRadius: 15))
                                        Text(kind.name).font(.body.weight(.medium)).foregroundStyle(ink)
                                        Spacer()
                                        if appearance == kind { Image(systemName: "checkmark.circle.fill").foregroundStyle(ink) }
                                    }.padding(.vertical, 4)
                                }
                                .accessibilityLabel("\(kind.name)\(appearance == kind ? ", sélectionné" : "")")
                            }
                        }
                    } footer: { Text("Tu changes son apparence. Hermès et notre conversation restent les mêmes.") }
                }
                .navigationTitle("Choisir son avatar")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { choosingAvatar = false } } }
            }.presentationDetents([.medium, .large]).preferredColorScheme(.light)
        }
        .sheet(item: $viewing) { ArtifactSheet(artifact: $0, character: agent.character).preferredColorScheme(.dark) }
    }
    private var header: some View {
        HStack {
            Button { toggleThread() } label: { Image(systemName: showThread ? "text.bubble.fill" : "text.bubble") }
                .frame(width: 44, height: 44)
                .frame(width: 88, alignment: .leading)
                .accessibilityLabel(showThread ? "Masquer la conversation" : "Afficher la conversation")
                .accessibilityValue(showThread ? "Visible" : "Masquée")
            Spacer()
            Text("Hermès").font(.system(.body, weight: .semibold))
            Spacer()
            Button { dismissKeyboard(); choosingAvatar = true } label: {
                AgentFace(character: appearance.rawValue, size: 30)
                    .background(ink, in: Circle()).frame(width: 44, height: 44)
            }.accessibilityLabel("Changer d’avatar, \(appearance.name)")
            Button { model.micUp(cancel: true); settings = true } label: { Image(systemName: "ellipsis") }
                .frame(width: 44, height: 44).accessibilityLabel("Réglages")
        }.padding(.horizontal, 14).frame(height: 50)
    }
    private func conversationPanel(available: CGFloat) -> some View {
        let maxHeight = max(100, available - composerHeight - 116)
        let heights = [min(maxHeight, available * 0.30), min(maxHeight, available * 0.50), maxHeight]
        let height = min(maxHeight, max(72, heights[min(detent, 2)] - sheetDrag))
        return VStack(spacing: 0) {
            VStack(spacing: 2) {
                Capsule().fill(quiet.opacity(0.45)).frame(width: 36, height: 4).padding(.top, 10)
                HStack {
                    Text("Notre conversation").font(.subheadline.weight(.semibold))
                    Spacer()
                    if keyboardHeight > 0 {
                        Button { dismissKeyboard() } label: { Image(systemName: "keyboard.chevron.compact.down").frame(width: 44, height: 44) }
                            .accessibilityLabel("Masquer le clavier")
                    }
                    Button { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) { detent = detent == 2 ? 0 : 2 } } label: {
                        Image(systemName: detent == 2 ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right").frame(width: 44, height: 44)
                    }.accessibilityLabel(detent == 2 ? "Réduire la conversation" : "Agrandir la conversation")
                    Button { toggleThread() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                        .accessibilityLabel("Masquer la conversation")
                }.padding(.horizontal, 20)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 8)
                .updating($sheetDrag) { value, state, _ in state = value.translation.height }
                .onEnded { value in
                    let projected = heights[min(detent, 2)] - value.predictedEndTranslation.height
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
                        if projected < heights[0] * 0.5 { showThread = false; dismissKeyboard() }
                        else { detent = heights.indices.min(by: { abs(heights[$0] - projected) < abs(heights[$1] - projected) }) ?? 0 }
                    }
                })
            thread.padding(.horizontal, 16)
        }
        .frame(height: height)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                .fill(ground.opacity(0.96))
                .shadow(color: ink.opacity(0.06), radius: 18, y: -3)
        }
        .padding(.horizontal, 6)
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
                        KloneMessageBubble(line: line, character: appearance.rawValue, ink: ink, ground: ground) { viewing = $0 }
                            .id(line.id)
                    }
                    Color.clear.frame(height: 4).id("end")
                }.padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(TapGesture().onEnded { if typing { dismissKeyboard() } })
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.035), .init(color: .black, location: 0.96), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
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
            if !attachments.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(attachments) { item in
                            HStack(spacing: 6) {
                                if let preview = item.preview {
                                    Image(uiImage: preview).resizable().scaledToFill().frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                Text(item.name).font(.caption).lineLimit(1)
                                Button { attachments.removeAll { $0.id == item.id } } label: { Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44) }
                                    .accessibilityLabel("Retirer \(item.name)").disabled(sending)
                            }
                        }
                    }
                }.scrollIndicators(.hidden)
            }
            if showWriting && !model.listening {
                HStack(alignment: .bottom) {
                    TextField("Écrire à Hermès…", text: $draft, axis: .vertical)
                        .lineLimit(1...4).focused($typing).padding(12)
                        .background(ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                        .onSubmit { send() }
                    Button { dismissKeyboard() } label: { Image(systemName: "keyboard.chevron.compact.down").frame(width: 36, height: 44) }
                        .accessibilityLabel("Masquer le clavier")
                    Button(action: send) { Image(systemName: "arrow.up").frame(width: 44, height: 44) }
                        .disabled(!canStart || (draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachments.isEmpty))
                        .accessibilityLabel(attachments.isEmpty ? "Envoyer le message écrit" : "Envoyer le message et les photos")
                }
            }
            HStack(spacing: 10) {
                if !model.listening {
                    Menu {
                        Button { dismissKeyboard(); choosingPhotos = true } label: { Label("Ajouter une photo", systemImage: "photo") }.disabled(busy || attachments.count >= 4)
                        Button { beginWriting() } label: { Label("Écrire à Hermès", systemImage: "square.and.pencil") }
                    } label: { Image(systemName: "plus").frame(width: 44, height: 46) }
                    .accessibilityLabel("Ajouter une photo ou écrire")
                }
                if model.listening {
                    Button { model.micUp(cancel: true) } label: { Image(systemName: "xmark").frame(width: 46, height: 46) }
                        .accessibilityLabel("Annuler l’enregistrement")
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
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(ground.opacity(0.97), in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: ink.opacity(0.09), radius: 18, y: 4)
    }
    private func hush() {
        model.hush()
        if model.controller.talk == .speaking { model.controller.talk = .none }
    }
    private func talk() {
        typing = false; notice = nil
        if model.listening { lastInteraction = Date().timeIntervalSince1970; model.micUp(cancel: false) }
        else if canStart { model.micDown() }
    }
    private func dismissKeyboard() {
        typing = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    private func beginWriting() {
        showWriting = true
        revealThread()
        Task { @MainActor in
            await Task.yield()
            typing = true
        }
    }
    private func revealThread(expanded: Bool = false) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
            showThread = true
            if expanded { detent = 2 }
        }
    }
    private func toggleThread() {
        dismissKeyboard()
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) { showThread.toggle() }
    }
    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        loadingPhotos = true
        defer { loadingPhotos = false; photos = [] }
        for item in items.prefix(max(0, 4 - attachments.count)) {
            guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data),
                  let photo = compactPhoto(image, name: "photo-\(UUID().uuidString.prefix(8)).jpg") else {
                notice = "Cette photo n’a pas pu être lue. Choisis une autre image. Seules les photos sont prises en charge."
                continue
            }
            guard photo.data.count <= 1_500_000 else {
                notice = "Cette photo dépasse 1,5 Mo après compression. Choisis une image plus petite."
                continue
            }
            attachments.append(photo)
        }
        if !attachments.isEmpty { showWriting = true }
    }
    private func compactPhoto(_ image: UIImage, name: String) -> Attachment? {
        guard let original = Attachment.photo(image, name: name) else { return nil }
        if original.data.count <= 1_500_000 { return original }
        var current = UIImage(data: original.data) ?? image
        for _ in 0..<4 {
            let size = CGSize(width: max(1, current.size.width * 0.75), height: max(1, current.size.height * 0.75))
            let format = UIGraphicsImageRendererFormat(); format.scale = 1
            let source = current
            current = UIGraphicsImageRenderer(size: size, format: format).image { _ in source.draw(in: CGRect(origin: .zero, size: size)) }
            if let data = current.jpegData(compressionQuality: 0.7), data.count <= 1_500_000 {
                return Attachment(name: name, type: "image/jpeg", data: data, preview: original.preview)
            }
        }
        return nil
    }
    private func send() {
        let text = String(draft.trimmingCharacters(in: .whitespacesAndNewlines).prefix(4000))
        let files = attachments
        guard canStart, !model.listening, !text.isEmpty || !files.isEmpty else { return }
        sending = true; notice = nil
        Task {
            defer { sending = false }
            var paths: [String] = []
            for file in files {
                guard let upload = await hub.upload(file.data, name: file.name, type: file.type) else {
                    notice = "La photo n’a pas été envoyée. Elle reste ici pour réessayer."
                    return
                }
                paths.append(upload.path)
            }
            let prompt = text.isEmpty && !files.isEmpty ? (files.count == 1 ? "Regarde cette photo." : "Regarde ces photos.") : text
            if let result = await model.send(text: prompt, files: paths), result.kind == "order" || result.kind == "verdict" {
                if draft.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(text) { draft = "" }
                attachments.removeAll { file in files.contains(file) }
                lastInteraction = Date().timeIntervalSince1970
                typing = false
            } else { notice = "Message non confirmé. Le texte et les photos restent ici. Vérifie la conversation avant de réessayer." }
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
