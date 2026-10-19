# Klone Chums visual context

Native SwiftUI product interface inherited from Chums. Preserve the system
typography, native controls and character artwork. The Watch and existing settings
retain their dark surfaces; the iPhone uses the warm light presentation selected
by Harry below. Existing upstream tokens stay in the Chums Swift files.

The iPhone character appears directly on the app background, with no simulated
watch border or decorative Digital Crown. The canvas can still use the shared
character coordinate system. Preserve its touch, hold-to-talk, petting, rotation
and compact conversation placement. Watch rendering remains device-specific.

Changes should be scoped and documented in docs/klone/UPSTREAM.md.

## Selected Klone iPhone surface

Warm light ground (RGB 0.918, 0.902, 0.867), plum-tinted dark text and controls
(RGB 0.19, 0.17, 0.21). Native rounded heading, system body type. Large Noodle
stage, transparent renderer background, visible scrollable thread, fixed composer.
The original dark HomeView is retained for upstream merges. On Mac the companion
is transparent; its separate conversation panel is dark. Watch retains native dark.
