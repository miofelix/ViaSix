package dev.viasix.app.ui

import org.junit.Assert.assertEquals
import org.junit.Test

class AppNavigationLayoutTest {
    @Test
    fun sectionWireRestoresSafely() {
        assertEquals(AppSection.PROFILES, AppSection.parse("profiles"))
        assertEquals(AppSection.OVERVIEW, AppSection.parse("unknown"))
        assertEquals(AppSection.OVERVIEW, AppSection.parse(null))
    }

    @Test
    fun compactWidthsUseBottomNavigation() {
        assertEquals(AppNavigationLayout.BOTTOM_BAR, AppNavigationLayout.forWidthDp(360))
        assertEquals(AppNavigationLayout.BOTTOM_BAR, AppNavigationLayout.forWidthDp(599))
    }

    @Test
    fun mediumWidthsUseNavigationRail() {
        assertEquals(AppNavigationLayout.NAVIGATION_RAIL, AppNavigationLayout.forWidthDp(600))
        assertEquals(AppNavigationLayout.NAVIGATION_RAIL, AppNavigationLayout.forWidthDp(839))
    }

    @Test
    fun expandedWidthsUseContextualSidebar() {
        assertEquals(AppNavigationLayout.SIDEBAR, AppNavigationLayout.forWidthDp(840))
        assertEquals(AppNavigationLayout.SIDEBAR, AppNavigationLayout.forWidthDp(1280))
    }
}
