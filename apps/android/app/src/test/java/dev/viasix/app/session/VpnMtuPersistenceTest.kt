package dev.viasix.app.session

import dev.viasix.app.prefs.SessionPrefs
import dev.viasix.app.state.SessionUiState
import org.junit.Assert.assertEquals
import org.junit.Test

class VpnMtuPersistenceTest {
    @Test
    fun preferencesAndUiStateRoundTripMtu() {
        val state = SessionUiState.fromPrefs(SessionPrefs(vpnMtu = "1420"))

        assertEquals("1420", state.vpnMtu)
        assertEquals("1420", state.toPrefs().vpnMtu)
    }

    @Test
    fun invalidDraftRemainsVisibleUntilUserFixesIt() {
        val state = SessionUiState.fromPrefs(SessionPrefs(vpnMtu = "999"))

        assertEquals("999", state.vpnMtu)
        assertEquals("999", state.toPrefs().vpnMtu)
    }
}
