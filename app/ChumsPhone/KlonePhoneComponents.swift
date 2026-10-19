import SwiftUI

/// Conversation bubbles sit over the same character canvas; only the thread scrolls.
struct KloneMessageBubble: View {
    let line: ChatLine
    let character: String
    let ink: Color
    let ground: Color
    let open: (Artifact) -> Void
    private var mine: Bool { line.who == .you }
    private var note: Bool { line.who == .note }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if mine { Spacer(minLength: 35) }
            if !mine && !note {
                AgentFace(character: character, size: 28)
                    .background(ink, in: Circle())
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(mine ? "Toi" : note ? "Information" : "Hermès")
                    .font(.caption2.weight(.semibold))
                    .opacity(0.65)
                Text(line.text).font(.subheadline).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                if let artifact = line.artifact {
                    Button { open(artifact) } label: {
                        Label(artifact.title, systemImage: "doc.text")
                            .font(.subheadline.weight(.medium))
                            .padding(.vertical, 7)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .foregroundStyle(mine ? ground : ink)
            .background(mine ? ink : note ? ink.opacity(0.06) : Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 19))
            if mine {
                Image(systemName: "person.crop.circle.fill").font(.system(size: 25))
                    .foregroundStyle(ink.opacity(0.65)).accessibilityHidden(true)
            } else { Spacer(minLength: note ? 0 : 35) }
        }
        .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
    }
}
