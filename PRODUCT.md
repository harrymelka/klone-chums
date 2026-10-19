# Klone Chums

## Register

product

## Users and purpose

Harry uses a personal Hermes companion from iPhone and Apple Watch. The main
workflow is to speak or write, follow a real task, answer an exact approval and
retrieve the result. Hermes owns memory and tools; locally hosted audio avoids
adding paid transcription or voice APIs.

## Product direction

Keep the existing Chums character engine, gestures and native SwiftUI interface.
Prefer small, isolated changes that remain easy to merge with upstream.
The companion should feel present, approachable and useful on each device.
On iPhone, show the character directly in the phone interface: a simulated
Apple Watch case and Digital Crown are explicitly unwanted. On Watch, retain
the native watch interface and its real Crown interactions.

## Accessibility and behavior

Preserve existing accessibility labels, Reduce Motion support, touch targets
and microphone cancellation. Reflect actual agent state and confirmed approvals.
Do not trade working interactions for decorative redesign.
