package dev.viasix.app.ui

/**
 * Adaptive app-shell breakpoints following Material window-width guidance.
 *
 * Phones keep the fast Clash-style bottom navigation, medium windows use a
 * compact rail, and tablets/desktop windows regain the contextual sidebar used
 * by the macOS product.
 */
enum class AppNavigationLayout {
    BOTTOM_BAR,
    NAVIGATION_RAIL,
    SIDEBAR,
    ;

    companion object {
        const val MEDIUM_BREAKPOINT_DP = 600
        const val EXPANDED_BREAKPOINT_DP = 840

        fun forWidthDp(widthDp: Int): AppNavigationLayout =
            when {
                widthDp < MEDIUM_BREAKPOINT_DP -> BOTTOM_BAR
                widthDp < EXPANDED_BREAKPOINT_DP -> NAVIGATION_RAIL
                else -> SIDEBAR
            }
    }
}
