package dev.viasix.app.tun

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TcpHandshakeGateTest {
    @Test
    fun onlyExpectedAcknowledgementCompletesHandshake() {
        val gate = TcpHandshakeGate()

        assertFalse(
            gate.acknowledge(
                sequence = 100L,
                expectedSequence = 100L,
                acknowledgement = 41L,
                expectedAcknowledgement = 42L,
                flags = Packet.ACK,
            ),
        )
        assertFalse(gate.isComplete)
        assertFalse(
            gate.acknowledge(
                sequence = 99L,
                expectedSequence = 100L,
                acknowledgement = 42L,
                expectedAcknowledgement = 42L,
                flags = Packet.ACK,
            ),
        )
        assertFalse(
            gate.acknowledge(
                sequence = 100L,
                expectedSequence = 100L,
                acknowledgement = 42L,
                expectedAcknowledgement = 42L,
                flags = Packet.SYN or Packet.ACK,
            ),
        )
        assertTrue(
            gate.acknowledge(
                sequence = 100L,
                expectedSequence = 100L,
                acknowledgement = 42L,
                expectedAcknowledgement = 42L,
                flags = Packet.PSH or Packet.ACK,
            ),
        )
        assertTrue(gate.await(timeoutMs = 0L))
    }

    @Test
    fun cancellationReleasesWaitWithoutCompletingHandshake() {
        val gate = TcpHandshakeGate()

        gate.cancel()

        assertFalse(gate.await(timeoutMs = 0L))
        assertFalse(gate.isComplete)
        assertFalse(
            gate.acknowledge(
                sequence = 100L,
                expectedSequence = 100L,
                acknowledgement = 42L,
                expectedAcknowledgement = 42L,
                flags = Packet.ACK,
            ),
        )
    }
}
