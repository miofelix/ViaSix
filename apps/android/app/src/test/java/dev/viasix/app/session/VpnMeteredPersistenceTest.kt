package dev.viasix.app.session

import dev.viasix.app.prefs.SessionPrefs
import dev.viasix.app.state.SessionUiState
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VpnMeteredPersistenceTest {
    @Test
    fun defaultsToPlatformCompatibleMeteredBehavior() {
        val state = SessionUiState.fromPrefs(SessionPrefs())

        assertTrue(state.vpnMetered)
        assertTrue(state.toPrefs().vpnMetered)
    }

    @Test
    fun unmeteredChoiceRoundTripsThroughUiState() {
        val state = SessionUiState.fromPrefs(SessionPrefs(vpnMetered = false))

        assertFalse(state.vpnMetered)
        assertFalse(state.toPrefs().vpnMetered)
    }
}
