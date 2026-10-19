# Klone Chums

## Register

product

## Users and purpose

Harry uses a personal Hermes companion from iPhone and Apple Watch. The main
workflow is to speak or write, follow a real task, answer an exact approval and
retrieve the result. Hermes owns memory and tools; locally hosted audio avoids
adding paid transcription or voice APIs.

## Product direction

Keep the existing Chums character engine, gestures and native SwiftUI foundations.
Use the confirmed presentation choices below for each device.
Prefer small, isolated changes that remain easy to merge with upstream.
The companion should feel present, approachable and useful on each device.
On iPhone, show the character directly in the phone interface: a simulated
Apple Watch case and Digital Crown are explicitly unwanted. On Watch, retain
the native watch interface and its real Crown interactions.

## Accessibility and behavior

Preserve existing accessibility labels, Reduce Motion support, touch targets
and microphone cancellation. Reflect actual agent state and confirmed approvals.
Do not trade working interactions for decorative redesign.

## Confirmed October 19 direction

Harry selected iPhone proposal B (warm light background), with the visible
conversation from C, refined after device testing: use a full-screen character
canvas beneath the system bars, with a draggable, hideable conversation overlay.
Keep the avatar visible during typing, with a smaller elevated pose, and keep
speech controls available. Sender bubbles use opposite sides and distinct colors.
Avatar selection uses named illustrated rows; photos live behind a plus menu. macOS gets a transparent animated desktop companion
and a separate chat window, all on the same Hermes conversation. The Watch face
uses one action label and state-specific Noodle poses with a question mark when
Hermes needs a reply, with brief system-managed transitions rather than a loop.
