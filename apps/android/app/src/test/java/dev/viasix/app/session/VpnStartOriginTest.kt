package dev.viasix.app.session

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VpnStartOriginTest {
    @Test
    fun explicitAppStartsUseIntentExtras() {
        val origin =
            VpnStartOrigin.detect(
                intentPresent = true,
                action = VpnStartOrigin.ACTION_START,
            )

        assertEquals(VpnStartOrigin.APP, origin)
        assertFalse(origin.restoreSavedSession)
    }

    @Test
    fun stickyAndAlwaysOnStartsRestoreSavedSession() {
        val sticky = VpnStartOrigin.detect(intentPresent = false, action = null)
        val alwaysOn =
            VpnStartOrigin.detect(
                intentPresent = true,
                action = "android.net.VpnService",
            )

        assertEquals(VpnStartOrigin.STICKY_RESTART, sticky)
        assertEquals("system-restart", sticky.reason)
        assertTrue(sticky.restoreSavedSession)
        assertEquals(VpnStartOrigin.SYSTEM, alwaysOn)
        assertEquals("system-start", alwaysOn.reason)
        assertTrue(alwaysOn.restoreSavedSession)
    }
}
