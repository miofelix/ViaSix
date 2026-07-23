package dev.viasix.app.session

import dev.viasix.app.mihomo.TrafficSnapshot
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SessionRuntimeStatusTest {
    @Test
    fun persistedRuntimeMapsToImmediateUiSnapshot() {
        val traffic =
            TrafficSnapshot(
                live = true,
                upBps = 1_024L,
                downBps = 2_048L,
                connectionCount = 3,
            )
        val snapshot =
            SessionRuntimeStatus(
                running = true,
                health = "ok",
                controllerPort = 9191,
                mixedPort = 11888,
                secret = "secret",
                mihomoVersion = "v1.2.3",
                startedAtMillis = 42L,
            ).toUiSnapshot(traffic)

        assertTrue(snapshot.running)
        assertEquals("ok", snapshot.health)
        assertEquals(9191, snapshot.controllerPort)
        assertEquals(11888, snapshot.mixedPort)
        assertEquals("v1.2.3", snapshot.mihomoVersion)
        assertEquals(42L, snapshot.startedAtMillis)
        assertEquals(traffic, snapshot.traffic)
        assertTrue(snapshot.secretPresent)
    }
}
