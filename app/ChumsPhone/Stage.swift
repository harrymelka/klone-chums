import SwiftUI

/// Where the character is: at the bottom left of the conversation once there is one (what it's doing beside it, its
/// newest line just above it), in the middle when there's no conversation yet, or in front when you tap it.
enum StagePlace { case dock, middle, front }

/// The shared character rendered directly in the iPhone interface, without a
/// simulated watch case or Digital Crown. Touches, holds, petting and two-finger
/// rotation remain available; the compact conversation version fades at its edges.
struct CharacterStage: View {
    let model: ScreenModel
    let agent: AgentInfo
    let small: Bool
    let paused: Bool
    let open: () -> Void
    let settings: () -> Void
    var background: Color? = .black
    var magnification = 1.0
    var verticalOffset = 0.0
    @State private var crop = Crop()
    @State private var twisted = 0.0

    /// How far it's cropped in, eased each frame (small: closer in on the character).
    final class Crop { var k = 1.0; var last: Date? }
    /// 30 frames a second when it's small or plays frames; the screen's own rate when it's big and drawn live.
    private var live: Bool { !small && CharacterKind(id: agent.character)?.framed != true }

    var body: some View {
        GeometryReader { g in
            TimelineView(.animation(minimumInterval: live ? nil : 1.0 / 30, paused: paused)) { tl in
                Canvas { ctx, size in
                    let dt = crop.last.map { tl.date.timeIntervalSince($0) } ?? 1
                    crop.last = tl.date
                    crop.k += ((small ? 1.3 : magnification) - crop.k) * min(1, max(0, dt) * 9)
                    var c = ctx
                    c.translateBy(x: size.width / 2, y: size.height / 2 + verticalOffset * size.height)
                    c.scaleBy(x: crop.k, y: crop.k)
                    c.translateBy(x: -size.width / 2, y: -size.height / 2)
                    Renderer.draw(model.rig, c, size: size, background: background)
                }
            }
            .mask {
                if small {
                    Rectangle().fill(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.14),
                                                            .init(color: .black, location: 0.7), .init(color: .clear, location: 1)],
                                                    startPoint: .top, endPoint: .bottom))
                        .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.12),
                                                     .init(color: .black, location: 0.88), .init(color: .clear, location: 1)],
                                             startPoint: .leading, endPoint: .trailing))
                } else {
                    Rectangle().fill(.black)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in model.drag(touchPoint(v.location, size: g.size), in: g.size) }
                    .onEnded { v in _ = model.dragEnd(touchPoint(v.location, size: g.size), in: g.size) },
                including: small ? .none : .all
            )
            .simultaneousGesture(
                RotateGesture()
                    .onChanged { v in model.crown((v.rotation.degrees - twisted) / 12); twisted = v.rotation.degrees }
                    .onEnded { _ in twisted = 0 },
                including: small ? .none : .all
            )
            .overlay {
                if small {
                    Color.clear.contentShape(Rectangle())
                        .onTapGesture(perform: open)
                        .onLongPressGesture(minimumDuration: 0.45) { Haptics.play(.strong); settings() }
                }
            }
        }
        // the big one, drawing live, has the clock run at the screen's rate with it
        .onChange(of: live && !paused, initial: true) { _, on in if !small { model.fullRate = on } }
        .onDisappear { if !small { model.fullRate = false } }
        .accessibilityElement()
        .accessibilityIdentifier("character")
        .accessibilityLabel(agent.name)
        .accessibilityHint(small ? "Shows \(agent.name) in front" : "Hold to talk to \(agent.name)")
        .accessibilityAddTraits(small ? .isButton : [])
    }
    private func touchPoint(_ point: CGPoint, size: CGSize) -> CGPoint {
        let scale = max(0.01, crop.k)
        return CGPoint(x: size.width / 2 + (point.x - size.width / 2) / scale,
                       y: size.height / 2 + (point.y - size.height / 2 - verticalOffset * size.height) / scale)
    }

}

/// A scale that follows your voice while `on` (the character in its row, the microphone held). The voice's level is
/// read from the recorder, not tracked, so it's read here every frame, 30 a second, without redrawing what it scales.
struct VoiceScale: ViewModifier {
    let model: ScreenModel
    let on: Bool
    let base: Double, gain: Double
    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !on)) { _ in
            content.scaleEffect(on ? base + model.talkLevel * gain : 1)
        }
    }
}
