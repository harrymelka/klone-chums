import SwiftUI
import AVFoundation
import AppKit
import Observation

struct MacLine: Decodable, Identifiable {
    let id: String
    let text: String
    let kind: String
    let agent: String?
    let device: String?
    let audio: String?
    let audioData: String?
}
struct MacAgent: Decodable { let id: String; let status: String; let needs: Bool }
struct MacApproval: Decodable, Identifiable {
    let requestId: String
    let session: String
    let description: String
    var id: String { requestId }
}
struct MacState: Decodable {
    let rev: Int
    let agents: [MacAgent]
    let spoken: [MacLine]
    let approvals: [MacApproval]
}
struct MacRoute: Decodable { let kind: String; let error: String? }

/// A client of the existing device API, not another Hermes session or server.
@MainActor @Observable
final class MacModel: NSObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    let rig = Rig()
    var lines: [MacLine] = []
    var approval: MacApproval?
    var connected = false
    var listening = false
    var requestingMicrophone = false
    var sending = false
    var deciding = false
    var speaking = false
    var notice: String?
    var draft = ""
    var status = "Connexion…"
    var muted = UserDefaults.standard.bool(forKey: "macMuted") {
        didSet {
            UserDefaults.standard.set(muted, forKey: "macMuted")
            if muted { hush() }
        }
    }
    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var clip: URL?
    @ObservationIgnored private var approvalAtRecord: String?
    @ObservationIgnored private var poll: Task<Void, Never>?
    @ObservationIgnored private var recordingLimit: Task<Void, Never>?
    @ObservationIgnored private var permissionGeneration = 0
    @ObservationIgnored private var seen = Set<String>()
    @ObservationIgnored private var loaded = false
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private let speech = AVSpeechSynthesizer()
    @ObservationIgnored private var audioTask: Task<Void, Never>?
    @ObservationIgnored private var agentStatus = "offline"
    @ObservationIgnored private var agentNeeds = false
    @ObservationIgnored private let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 30
        c.timeoutIntervalForResource = 100
        return URLSession(configuration: c)
    }()
    override init() {
        super.init()
        rig.character = .noodle; rig.chrome = false; rig.mode = .portrait
        speech.delegate = self
    }
    var maySend: Bool { connected && !sending && !requestingMicrophone && !["working", "compacting"].contains(agentStatus) }
    var level: Double {
        guard let recorder, recorder.isRecording else { return 0 }
        recorder.updateMeters()
        return min(1, max(0, (Double(recorder.averagePower(forChannel: 0)) + 50) / 40))
    }
    func start() {
        guard poll == nil else { return }
        poll = Task { [weak self] in
            var rev = 0
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    let data = try await self.request("/v1/state?since=\(rev)")
                    let state = try JSONDecoder().decode(MacState.self, from: data)
                    if Task.isCancelled { break }
                    rev = state.rev; self.apply(state)
                } catch {
                    if Task.isCancelled { break }
                    self.connected = false; self.status = "Hermès indisponible"
                    self.updateRig()
                    try? await Task.sleep(for: .seconds(2))
                }
            }
        }
    }
    func stop() { poll?.cancel(); poll = nil; cancelRecording(); hush(); session.invalidateAndCancel() }
    private func request(_ path: String, body: Data? = nil, type: String = "application/json", headers: [String: String] = [:]) async throws -> Data {
        // Only loopback; no new tunnel, port, backend or credential store.
        guard path.hasPrefix("/v1/"), !path.contains("://"), let url = URL(string: "http://127.0.0.1:17772" + path) else { throw URLError(.badURL) }
        var r = URLRequest(url: url, timeoutInterval: body == nil ? 28 : 90)
        r.setValue("Bearer \(HubConfig.token)", forHTTPHeaderField: "Authorization")
        if let body { r.httpMethod = "POST"; r.httpBody = body; r.setValue(type, forHTTPHeaderField: "Content-Type") }
        for (key, value) in headers { r.setValue(value, forHTTPHeaderField: key) }
        let (data, response) = try await session.data(for: r)
        guard let code = (response as? HTTPURLResponse)?.statusCode, code == 200 else {
            let error = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
            throw NSError(domain: "Klone", code: (response as? HTTPURLResponse)?.statusCode ?? 0,
                          userInfo: [NSLocalizedDescriptionKey: error ?? "La passerelle Hermès ne répond pas."])
        }
        return data
    }
    func checkConnection() async -> Bool {
        do {
            let data = try await request("/v1/state?since=0")
            let state = try JSONDecoder().decode(MacState.self, from: data)
            apply(state)
            let ok = state.agents.contains { $0.id == "noodle" }
            print("Mac device API: \(ok ? "OK" : "NO AGENT"); shared lines: \(lines.count); initial audio: silent.")
            return ok
        } catch { print("Mac device API check failed."); return false }
    }
    private func apply(_ state: MacState) {
        connected = true
        let agent = state.agents.first { $0.id == "noodle" }
        agentStatus = agent?.status ?? "offline"; agentNeeds = agent?.needs ?? false
        approval = state.approvals.first { $0.session == "noodle" }
        lines = state.spoken.filter { ($0.agent ?? "noodle") == "noodle" }
        let fresh = lines.filter { !seen.contains($0.id) }
        seen.formUnion(lines.map(\.id))
        if seen.count > 600 { seen = Set(lines.map(\.id)) }
        if loaded, !muted, let reply = fresh.last(where: { $0.device == "mac" && $0.kind != "echo" }) { play(reply) }
        loaded = true
        updateRig()
    }
    private func updateRig() {
        let state: ChumsState
        if listening { status = "Je t’écoute"; state = .listening }
        else if sending { status = "Envoi à Hermès…"; state = .thinking }
        else if speaking { status = "Hermès te répond"; state = .speaking }
        else if !connected { status = "Hermès indisponible"; state = .sleep }
        else if approval != nil || agentNeeds || agentStatus == "waiting" { status = "Une question pour toi"; state = .needs }
        else if agentStatus == "working" { status = "Hermès travaille"; state = .working }
        else if agentStatus == "compacting" { status = "Hermès réfléchit"; state = .thinking }
        else if ["blocked", "limited", "offline"].contains(agentStatus) { status = "À vérifier dans le chat"; state = .blocked }
        else { status = "Parler à Hermès"; state = .idle }
        rig.restState = state; rig.setState(state)
    }
    func microphone() {
        if listening { sendRecording(); return }
        guard maySend else { return }
        hush(); notice = nil; requestingMicrophone = true
        permissionGeneration += 1
        let generation = permissionGeneration
        Task {
            let allowed = await AVCaptureDevice.requestAccess(for: .audio)
            guard generation == permissionGeneration else { return }
            requestingMicrophone = false
            guard allowed else {
                notice = "Autorise Klone Chums Mac dans Réglages Système → Confidentialité et sécurité → Microphone."
                return
            }
            guard maySend else { return }
            do {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("klone-mac-\(UUID().uuidString).m4a")
                let r = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 16000, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue])
                r.isMeteringEnabled = true
                guard r.record() else { throw NSError(domain: "Klone", code: 1) }
                recorder = r; clip = url; approvalAtRecord = approval?.requestId; listening = true; updateRig()
                recordingLimit = Task {
                    try? await Task.sleep(for: .seconds(60))
                    if !Task.isCancelled, listening {
                        cancelRecording(); notice = "Enregistrement annulé après une minute. Relance Parler pour un message plus court."
                    }
                }
            } catch { notice = "Impossible de démarrer le microphone." }
        }
    }
    func cancelRecording() {
        permissionGeneration += 1; requestingMicrophone = false
        recordingLimit?.cancel(); recordingLimit = nil
        recorder?.stop(); recorder = nil; listening = false
        if let clip { try? FileManager.default.removeItem(at: clip) }; clip = nil; approvalAtRecord = nil
        updateRig()
    }
    private func sendRecording() {
        guard listening, let r = recorder, let url = clip else { return }
        let duration = r.currentTime
        r.stop(); recorder = nil; listening = false; clip = nil
        recordingLimit?.cancel(); recordingLimit = nil
        let approvalID = approvalAtRecord; approvalAtRecord = nil
        guard duration >= 0.3 else {
            try? FileManager.default.removeItem(at: url); notice = "Message trop court. Réessaie en parlant un peu plus longtemps."; updateRig(); return
        }
        sending = true; updateRig()
        Task {
            defer { try? FileManager.default.removeItem(at: url); sending = false; updateRig() }
            do {
                let data = try Data(contentsOf: url)
                var headers = ["X-Chums-Agent": "noodle", "X-Chums-Device": "mac"]
                if let approvalID { headers["X-Chums-Approval"] = approvalID }
                let result = try await request("/v1/utterance", body: data, type: "audio/m4a", headers: headers)
                try checkRoute(result)
            } catch { notice = "\(error.localizedDescription) Vérifie le fil avant de renvoyer le message." }
        }
    }
    func sendText() {
        let text = String(draft.trimmingCharacters(in: .whitespacesAndNewlines).prefix(4000))
        guard !text.isEmpty, maySend, !listening else { return }
        sending = true; notice = nil; hush(); updateRig()
        let approvalID = approval?.requestId
        Task {
            defer { sending = false; updateRig() }
            do {
                var body: [String: String] = ["text": text, "agent": "noodle", "device": "mac"]
                if let approvalID { body["approval"] = approvalID }
                let data = try await request("/v1/say", body: JSONEncoder().encode(body))
                try checkRoute(data)
                if draft.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(text) { draft = "" }
            } catch { notice = "\(error.localizedDescription) Vérifie le fil avant de renvoyer le message." }
        }
    }
    private func checkRoute(_ data: Data) throws {
        let result = try JSONDecoder().decode(MacRoute.self, from: data)
        if let error = result.error { throw NSError(domain: "Klone", code: 1, userInfo: [NSLocalizedDescriptionKey: error]) }
        if ["busy", "error", "empty", "ask"].contains(result.kind) { throw NSError(domain: "Klone", code: 1, userInfo: [NSLocalizedDescriptionKey: "Hermès n’a pas accepté ce message."]) }
    }
    func verdict(_ item: MacApproval, allow: Bool) {
        guard !deciding, approval?.requestId == item.requestId else { return }
        deciding = true; notice = nil
        Task {
            defer { deciding = false }
            do {
                let data = try await request("/v1/verdict", body: JSONEncoder().encode(["requestId": item.requestId, "behavior": allow ? "allow" : "deny"]))
                try checkRoute(data)
                // The next state from the hub confirms removal. Do not fabricate a completed task.
            } catch { notice = error.localizedDescription }
        }
    }
    private func play(_ line: MacLine) {
        hush()
        audioTask = Task {
            var audio = line.audioData.flatMap { Data(base64Encoded: $0) }
            if audio == nil, let path = line.audio, path.hasPrefix("/v1/speech/") { audio = try? await request(path) }
            guard !Task.isCancelled, !muted, !listening else { return }
            if let audio, let p = try? AVAudioPlayer(data: audio) {
                player = p; p.delegate = self
                speaking = p.play(); updateRig()
                if speaking { return }
            }
            let u = AVSpeechUtterance(string: line.text)
            u.voice = AVSpeechSynthesisVoice(language: "fr-FR")
            speaking = true; updateRig(); speech.speak(u)
        }
    }
    func hush() {
        audioTask?.cancel(); audioTask = nil
        player?.stop(); player = nil; speech.stopSpeaking(at: .immediate)
        speaking = false; updateRig()
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.speaking = false; self.updateRig() }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speaking = false; self.updateRig() }
    }
}
