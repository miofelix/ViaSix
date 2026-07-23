package dev.viasix.app.tun

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TcpSendWindowTest {
    @Test
    fun allowanceTracksBytesInFlightAndAcknowledgements() {
        val window = TcpSendWindow()

        assertTrue(
            window.update(
                segmentSequence = 1L,
                acknowledgement = 100L,
                advertisedWindow = 1_000,
                nextSequence = 100L,
            ),
        )
        assertEquals(1_000, window.awaitAllowance(maxBytes = 16_384, timeoutMs = 0L))
        assertTrue(window.recordSent(sequence = 100L, sequenceLength = 600))
        assertEquals(400, window.awaitAllowance(maxBytes = 16_384, timeoutMs = 0L))
        assertTrue(
            window.update(
                segmentSequence = 2L,
                acknowledgement = 700L,
                advertisedWindow = 1_000,
                nextSequence = 700L,
            ),
        )
        assertEquals(1_000, window.awaitAllowance(maxBytes = 16_384, timeoutMs = 0L))
    }

    @Test
    fun zeroWindowAndAcknowledgementBeyondSentDataDoNotReleaseReads() {
        val window = TcpSendWindow()

        assertTrue(
            window.update(
                segmentSequence = 1L,
                acknowledgement = 50L,
                advertisedWindow = 0,
                nextSequence = 50L,
            ),
        )
        assertEquals(0, window.awaitAllowance(maxBytes = 1_024, timeoutMs = 0L))
        assertFalse(
            window.update(
                segmentSequence = 2L,
                acknowledgement = 60L,
                advertisedWindow = 1_024,
                nextSequence = 50L,
            ),
        )
        assertEquals(0, window.awaitAllowance(maxBytes = 1_024, timeoutMs = 0L))
    }

    @Test
    fun sequenceWrapKeepsInFlightAccountingCorrect() {
        val window = TcpSendWindow()

        assertTrue(
            window.update(
                segmentSequence = 1L,
                acknowledgement = 0xffff_ff00L,
                advertisedWindow = 1_024,
                nextSequence = 0xffff_ff00L,
            ),
        )
        assertTrue(window.recordSent(sequence = 0xffff_ff00L, sequenceLength = 256))
        assertEquals(768, window.awaitAllowance(maxBytes = 1_024, timeoutMs = 0L))
    }

    @Test
    fun sentReservationAcceptsFastAcknowledgementBeforeExternalSequenceAdvances() {
        val window = TcpSendWindow()

        assertTrue(
            window.update(
                segmentSequence = 1L,
                acknowledgement = 100L,
                advertisedWindow = 1_000,
                nextSequence = 100L,
            ),
        )
        assertTrue(window.recordSent(sequence = 100L, sequenceLength = 300))
        assertTrue(
            window.update(
                segmentSequence = 2L,
                acknowledgement = 400L,
                advertisedWindow = 1_000,
                nextSequence = 100L,
            ),
        )
        assertEquals(1_000, window.awaitAllowance(maxBytes = 1_024, timeoutMs = 0L))
    }

    @Test
    fun backwardAcknowledgementAndMismatchedReservationAreRejected() {
        val window = TcpSendWindow()

        assertTrue(
            window.update(
                segmentSequence = 1L,
                acknowledgement = 1_000L,
                advertisedWindow = 2_000,
                nextSequence = 1_000L,
            ),
        )
        assertFalse(window.recordSent(sequence = 1_001L, sequenceLength = 100))
        assertTrue(window.recordSent(sequence = 1_000L, sequenceLength = 100))
        assertTrue(
            window.update(
                segmentSequence = 2L,
                acknowledgement = 1_050L,
                advertisedWindow = 2_000,
                nextSequence = 1_100L,
            ),
        )
        assertFalse(
            window.update(
                segmentSequence = 3L,
                acknowledgement = 1_025L,
                advertisedWindow = 2_000,
                nextSequence = 1_100L,
            ),
        )
        assertEquals(1_950, window.awaitAllowance(maxBytes = 2_000, timeoutMs = 0L))
    }

    @Test
    fun exposesLatestAcceptedAcknowledgementForConnectionReset() {
        val window = TcpSendWindow()

        assertNull(window.acknowledgedSequence())
        assertTrue(
            window.update(
                segmentSequence = 1L,
                acknowledgement = 100L,
                advertisedWindow = 1_000,
                nextSequence = 100L,
            ),
        )
        assertTrue(window.recordSent(sequence = 100L, sequenceLength = 300))
        assertTrue(
            window.update(
                segmentSequence = 2L,
                acknowledgement = 250L,
                advertisedWindow = 1_000,
                nextSequence = 400L,
            ),
        )
        assertEquals(250L, window.acknowledgedSequence())
        window.cancel()
        assertNull(window.acknowledgedSequence())
    }

    @Test
    fun scaledPeerWindowIsCappedByRetransmissionCapacity() {
        val window = TcpSendWindow(maxInFlightBytes = 131_070)

        assertTrue(
            window.update(
                segmentSequence = 1L,
                acknowledgement = 100L,
                advertisedWindow = 1_073_725_440,
                nextSequence = 100L,
            ),
        )
        assertEquals(131_070, window.awaitAllowance(maxBytes = 1_000_000, timeoutMs = 0L))
        assertTrue(window.recordSent(sequence = 100L, sequenceLength = 100_000))
        assertEquals(31_070, window.awaitAllowance(maxBytes = 1_000_000, timeoutMs = 0L))
    }

    @Test
    fun staleSegmentMayAdvanceAcknowledgementWithoutOverwritingNewerWindow() {
        val window = TcpSendWindow()

        assertTrue(
            window.update(
                segmentSequence = 200L,
                acknowledgement = 100L,
                advertisedWindow = 1_000,
                nextSequence = 100L,
            ),
        )
        assertTrue(window.recordSent(sequence = 100L, sequenceLength = 100))
        assertTrue(
            window.update(
                segmentSequence = 201L,
                acknowledgement = 100L,
                advertisedWindow = 2_000,
                nextSequence = 200L,
            ),
        )
        assertTrue(
            window.update(
                segmentSequence = 200L,
                acknowledgement = 150L,
                advertisedWindow = 0,
                nextSequence = 200L,
            ),
        )

        assertEquals(1_950, window.awaitAllowance(maxBytes = 2_000, timeoutMs = 0L))
        assertEquals(150L, window.acknowledgedSequence())
    }

    @Test
    fun windowUpdateSequenceOrderingHandlesWrap() {
        val window = TcpSendWindow()

        assertTrue(
            window.update(
                segmentSequence = 0xffff_fffeL,
                acknowledgement = 100L,
                advertisedWindow = 1_000,
                nextSequence = 100L,
            ),
        )
        assertTrue(
            window.update(
                segmentSequence = 1L,
                acknowledgement = 100L,
                advertisedWindow = 2_000,
                nextSequence = 100L,
            ),
        )
        assertTrue(
            window.update(
                segmentSequence = 0xffff_fffdL,
                acknowledgement = 100L,
                advertisedWindow = 0,
                nextSequence = 100L,
            ),
        )

        assertEquals(2_000, window.awaitAllowance(maxBytes = 2_000, timeoutMs = 0L))
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsNonPositiveInFlightLimit() {
        TcpSendWindow(maxInFlightBytes = 0)
    }
}
