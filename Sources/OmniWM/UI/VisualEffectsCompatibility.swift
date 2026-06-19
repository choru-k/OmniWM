// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import SwiftUI

// ponytail: macOS 26 "Liquid Glass" APIs (glassEffect / backgroundExtensionEffect) are absent
// from the macOS 15 SDK this fork is built against, so the #available(macOS 26) branches won't
// compile here. We keep only the macOS 15 fallbacks. Restore the glass branches (see git history /
// upstream) once building against the Xcode 26 SDK.
extension View {
    @ViewBuilder
    func omniGlassEffect<S: Shape>(in shape: S, prominent: Bool = false) -> some View {
        if prominent {
            self
                .background(Color.accentColor.opacity(0.22))
                .overlay {
                    shape
                        .stroke(Color.accentColor.opacity(0.45), lineWidth: 1)
                }
                .clipShape(shape)
        } else {
            self
                .background(.ultraThinMaterial)
                .clipShape(shape)
        }
    }

    @ViewBuilder
    func omniBackgroundExtensionEffect() -> some View {
        self
    }
}
