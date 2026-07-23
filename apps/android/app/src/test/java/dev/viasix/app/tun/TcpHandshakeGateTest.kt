package dev.viasix.app.tun

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TcpHandshakeGateTest {
    @Test
    fun onlyExpectedAcknowledgementCompletesHandshake() {
        val gate = TcpHandshakeGate()

        assertFalse(gate.acknowledge(acknowledgement = 41L, expected = 42L))
        assertFalse(gate.isComplete)
        assertTrue(gate.acknowledge(acknowledgement = 42L, expected = 42L))
        assertTrue(gate.await(timeoutMs = 0L))
    }

    @Test
    fun cancellationReleasesWaitWithoutCompletingHandshake() {
        val gate = TcpHandshakeGate()

        gate.cancel()

        assertFalse(gate.await(timeoutMs = 0L))
        assertFalse(gate.isComplete)
    }
}
