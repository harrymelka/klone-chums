import SwiftUI
import AppKit

@main
struct KloneMacApp: App {
    @NSApplicationDelegateAdaptor(MacDelegate.self) private var delegate
    init() { UserDefaults.standard.register(defaults: ["noodleLook": "lit"]) }
    var body: some Scene { Settings { EmptyView() } }
}

final class CompanionPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class MacDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = MacModel()
    var pet: NSPanel!
    var chat: NSPanel!
    var item: NSStatusItem!
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let dir = UserDefaults.standard.string(forKey: "renderDir") {
            MacRender.export(to: dir)
            NSApp.terminate(nil); return
        }
        if UserDefaults.standard.bool(forKey: "selfCheck") {
            Task { let ok = await model.checkConnection(); exit(ok ? 0 : 1) }
            return
        }
        NSApp.setActivationPolicy(.accessory)
        pet = CompanionPanel(contentRect: NSRect(x: 0, y: 0, width: 260, height: 390),
                             styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        pet.title = "Klone Chums · compagnon"
        pet.isOpaque = false; pet.backgroundColor = .clear; pet.hasShadow = false
        pet.level = .floating; pet.hidesOnDeactivate = false
        pet.isMovableByWindowBackground = true
        pet.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        pet.setFrameAutosaveName("klone.desktop.character")
        if !pet.setFrameUsingName("klone.desktop.character"), let area = NSScreen.main?.visibleFrame {
            pet.setFrameOrigin(NSPoint(x: area.maxX - 260, y: area.minY + 30))
        }
        // Older saved frames were too short for recording controls and transcript preview.
        if pet.frame.height < 390 || pet.frame.width < 260 {
            var frame = pet.frame; frame.size = NSSize(width: 260, height: 390)
            pet.setFrame(frame, display: false)
        }
        let petHost = NSHostingView(rootView: PetView(model: model, open: { [weak self] in self?.showChat() }))
        // Keep AppKit's content rect authoritative: an intrinsically small SwiftUI
        // label must never shrink the transparent character canvas or its controls.
        petHost.sizingOptions = []
        petHost.frame = NSRect(origin: .zero, size: pet.contentRect(forFrameRect: pet.frame).size)
        petHost.autoresizingMask = [.width, .height]
        pet.contentView = petHost
        pet.orderFrontRegardless()
        chat = CompanionPanel(contentRect: NSRect(x: 0, y: 0, width: 430, height: 610),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        chat.title = "Hermès · conversation partagée"
        chat.isReleasedWhenClosed = false; chat.hidesOnDeactivate = false
        chat.minSize = NSSize(width: 360, height: 440)
        chat.delegate = self
        chat.setFrameAutosaveName("klone.desktop.chat")
        if !chat.setFrameUsingName("klone.desktop.chat") { chat.center() }
        chat.contentView = NSHostingView(rootView: MacChatView(model: model))
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "bubble.left.and.bubble.right", accessibilityDescription: "Klone Chums")
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        let versionLabel = "Klone Chums Mac · \(version) (\(build))"
        item.button?.toolTip = versionLabel
        let menu = NSMenu()
        let versionItem = NSMenuItem(title: versionLabel, action: nil, keyEquivalent: "")
        versionItem.isEnabled = false; menu.addItem(versionItem)
        menu.addItem(.separator())
        for (title, action, key) in [("Parler à Hermès", #selector(talk), ""), ("Ouvrir la conversation", #selector(openChat), ""), ("Afficher / masquer le personnage", #selector(togglePet), ""), ("Replacer le personnage", #selector(resetPet), "")] {
            let entry = NSMenuItem(title: title, action: action, keyEquivalent: key); entry.target = self; menu.addItem(entry)
        }
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quitter Klone Chums Mac", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self; menu.addItem(quit); item.menu = menu
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        model.start()
    }
    func showChat() {
        chat.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func talk() { pet.orderFrontRegardless(); model.microphone() }
    @objc func openChat() { showChat() }
    @objc func togglePet() {
        if pet.isVisible { pet.orderOut(nil) } else { pet.orderFrontRegardless() }
    }
    @objc func resetPet() {
        if let area = NSScreen.main?.visibleFrame { pet.setFrameOrigin(NSPoint(x: area.maxX - 260, y: area.minY + 30)) }
        pet.orderFrontRegardless()
    }
    @objc func quitApp() { NSApp.terminate(nil) }
    @objc func willSleep() { model.cancelRecording(); model.hush() }
    func windowWillClose(_ notification: Notification) { model.cancelRecording() }
    func applicationWillTerminate(_ notification: Notification) { model.stop() }
}

struct PetView: View {
    @Bindable var model: MacModel
    let open: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clock = RigClock()
    var body: some View {
        VStack(spacing: 0) {
            // This explicit handle moves the transparent window without competing with the talk button.
            Capsule().fill(.secondary.opacity(0.45)).frame(width: 28, height: 4).padding(.top, 8).padding(.bottom, 4)
                .help("Fais glisser cette zone pour déplacer Noodle")
            TimelineView(.animation(minimumInterval: reduceMotion ? 0.5 : 1.0 / 24)) { timeline in
                Canvas { ctx, size in
                    let dt = clock.last.map { timeline.date.timeIntervalSince($0) } ?? 1.0 / 24
                    clock.last = timeline.date
                    model.rig.voiceInput = model.listening ? model.level : nil
                    model.rig.tick(max(0, min(dt, 0.05)))
                    Renderer.draw(model.rig, ctx, size: size, background: nil)
                }
            }
            .frame(width: 248, height: 250)
            .contentShape(Rectangle()).onTapGesture(perform: open)
            .accessibilityLabel("Noodle. \(model.status)")
            .accessibilityAddTraits(.isButton).accessibilityAction { open() }
            if model.listening || model.transcribing || model.voiceDraft != nil {
                MacVoiceControls(model: model, compact: true)
                if let transcript = model.voiceDraft {
                    Button(action: open) {
                        Text(transcript).font(.system(size: 11)).lineLimit(2)
                            .foregroundStyle(.white)
                            .frame(height: 34, alignment: .top)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .background {
                                RoundedRectangle(cornerRadius: 12).fill(.regularMaterial)
                                RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.72))
                            }
                    }.buttonStyle(.plain).padding(.top, 5)
                        .help("Ouvrir et corriger la transcription avant envoi")
                }
            } else {
                Button { model.microphone() } label: {
                    Label(model.requestingMicrophone ? "Autoriser le micro…" : model.status,
                          systemImage: model.approval != nil ? "questionmark.bubble" : "mic.fill")
                        .font(.system(size: 12, weight: .medium)).lineLimit(1)
                        .padding(.horizontal, 13).padding(.vertical, 9)
                        .background(.regularMaterial, in: Capsule())
                }
                .buttonStyle(.plain).disabled(!model.maySend)
                .help("Enregistrer un message dans le compagnon du bureau")
            }
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 6)
        .frame(width: 260, height: 390, alignment: .top)
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
    }
}
final class RigClock { var last: Date? }

struct MacChatView: View {
    @Bindable var model: MacModel
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Circle().fill(model.connected ? Color.green : Color.orange).frame(width: 6, height: 6)
                Text(model.status).font(.system(size: 12))
                Spacer()
                Button { model.muted.toggle() } label: { Image(systemName: model.muted ? "speaker.slash" : "speaker.wave.2") }
                    .help(model.muted ? "Activer les réponses vocales" : "Couper les réponses vocales")
                    .accessibilityLabel(model.muted ? "Activer les réponses vocales" : "Couper les réponses vocales")
                if model.speaking { Button("Arrêter la voix") { model.hush() } }
            }
            .padding(14)
            Divider()
            ScrollViewReader { scroll in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        if model.lines.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("On reprend ici.").font(.system(size: 24, weight: .semibold))
                                Text("La même conversation que sur ton iPhone et ta Watch.").foregroundStyle(.secondary)
                            }.padding(.vertical, 30)
                        }
                        ForEach(model.lines) { line in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(line.kind == "echo" ? "TOI" : "HERMÈS")
                                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                                Text(line.text).font(.system(size: 14)).textSelection(.enabled)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading).id(line.id)
                        }
                        Color.clear.frame(height: 1).id("end")
                    }.padding(18)
                }
                .onChange(of: model.lines.last?.id) { _, _ in scroll.scrollTo("end", anchor: .bottom) }
            }
            if let approval = model.approval {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Hermès demande ton accord", systemImage: "questionmark.bubble").font(.headline)
                    ScrollView { Text(approval.description).font(.system(size: 12, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 110)
                    HStack {
                        Button("Refuser") { model.verdict(approval, allow: false) }
                        Spacer()
                        Button("Autoriser cette fois") { model.verdict(approval, allow: true) }
                            .buttonStyle(.borderedProminent).tint(.orange)
                    }.disabled(model.deciding)
                }.padding(14).background(Color.orange.opacity(0.09))
            }
            if let notice = model.notice {
                Text(notice).font(.system(size: 12)).foregroundStyle(.orange).frame(maxWidth: .infinity, alignment: .leading).padding(14)
            }
            Divider()
            VStack(spacing: 10) {
                if model.listening || model.transcribing || model.voiceDraft != nil {
                    if model.voiceDraft != nil {
                        Text("Ta transcription · modifiable avant envoi")
                            .font(.caption).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        TextEditor(text: Binding(get: { model.voiceDraft ?? "" }, set: { model.voiceDraft = $0 }))
                            .font(.system(size: 14)).frame(minHeight: 64, maxHeight: 130)
                            .disabled(model.sending)
                            .accessibilityLabel("Transcription du message vocal")
                    }
                    MacVoiceControls(model: model)
                } else {
                    HStack(alignment: .bottom, spacing: 8) {
                        TextField("Écrire à Hermès…", text: $model.draft, axis: .vertical)
                            .lineLimit(1...5).textFieldStyle(.roundedBorder).onSubmit { model.sendText() }
                            .disabled(model.sending)
                        Button { model.sendText() } label: { Image(systemName: "arrow.up") }
                            .disabled(!model.maySend || model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityLabel("Envoyer le message écrit")
                    }
                    HStack {
                        Button { model.microphone() } label: {
                            Label(model.requestingMicrophone ? "Autoriser le micro…" : "Parler", systemImage: "mic.fill")
                        }.disabled(!model.maySend).buttonStyle(.borderedProminent)
                        if model.sending { ProgressView().controlSize(.small); Text("Envoi…").font(.caption) }
                        Spacer()
                        Text("Même fil · iPhone et Watch").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
            }.padding(14)
        }
        .background(Color(red: 0.06, green: 0.065, blue: 0.08))
        .preferredColorScheme(.dark)
        .onExitCommand { model.cancelRecording() }
    }
}

/// The same explicit recording actions live in both the desktop pet and chat.
struct MacVoiceControls: View {
    @Bindable var model: MacModel
    var compact = false
    var body: some View {
        VStack(spacing: 8) {
            if model.listening {
                HStack(spacing: 8) {
                    VoiceLevelView(model: model).frame(width: compact ? 60 : 80, height: 22)
                    Text(model.paused ? "En pause" : "Je t’écoute…")
                        .font(.system(size: compact ? 11 : 12)).foregroundStyle(.secondary)
                    if !compact { Spacer() }
                }
            } else if model.transcribing {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Transcription…").font(.caption)
                }
            }
            HStack(spacing: compact ? 7 : 10) {
                Button { model.cancelRecording() } label: {
                    if compact { Image(systemName: "xmark") } else { Text("Annuler") }
                }.help("Annuler le message vocal").accessibilityLabel("Annuler le message vocal")
                    .disabled(model.sending)
                if model.listening {
                    Button { model.togglePause() } label: {
                        Label(model.paused ? "Reprendre" : "Pause", systemImage: model.paused ? "play.fill" : "pause.fill")
                    }
                    .accessibilityLabel(model.paused ? "Reprendre l’enregistrement" : "Mettre l’enregistrement en pause")
                    Button("Terminer") { model.finishRecording() }
                        .buttonStyle(.borderedProminent).help("Arrêter et voir la transcription avant envoi")
                } else if model.voiceDraft != nil {
                    if !compact { Spacer() }
                    Button { model.sendVoiceDraft() } label: {
                        Label(model.sending ? "Envoi…" : "Envoyer", systemImage: "arrow.up")
                    }.buttonStyle(.borderedProminent)
                        .disabled(!model.maySend || (model.voiceDraft ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }.controlSize(compact ? .small : .regular)
        }
        .padding(compact ? 10 : 0)
        .background {
            if compact { RoundedRectangle(cornerRadius: 16).fill(.regularMaterial) }
        }
    }
}
struct VoiceLevelView: View {
    let model: MacModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.5 : 1.0 / 15)) { _ in
            let power = model.paused ? 0 : model.level
            HStack(spacing: 3) {
                ForEach(0..<9) { index in
                    let weight = 1 - abs(Double(index) - 4) / 6
                    Capsule().fill(model.paused ? Color.secondary : Color.orange)
                        .frame(width: 3, height: max(3, 22 * power * weight))
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityLabel(model.paused ? "Microphone en pause" : "Niveau du microphone")
    }
}
