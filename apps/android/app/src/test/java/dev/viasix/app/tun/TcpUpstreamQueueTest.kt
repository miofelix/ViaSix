package dev.viasix.app.tun

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TcpUpstreamQueueTest {
    @Test
    fun preservesOrderAndBoundsQueuedPayloads() {
        val queue = TcpUpstreamQueue(maxBytes = 4, maxSegments = 2)

        assertTrue(queue.offer(byteArrayOf(1, 2)))
        assertTrue(queue.offer(byteArrayOf(3, 4)))
        assertTrue(queue.hasPending)
        assertFalse(queue.offer(byteArrayOf(5)))
        assertArrayEquals(byteArrayOf(1, 2), queue.poll(timeoutMs = 0L))
        assertFalse(queue.offer(byteArrayOf(5)))
        queue.complete(payloadLength = 2)
        assertArrayEquals(byteArrayOf(3, 4), queue.poll(timeoutMs = 0L))
        queue.complete(payloadLength = 2)
        assertTrue(queue.awaitEmpty(timeoutMs = 0L))
        assertFalse(queue.hasPending)
        assertNull(queue.poll(timeoutMs = 0L))
    }

    @Test
    fun cancelledQueueRejectsAndWakesConsumers() {
        val queue = TcpUpstreamQueue()

        queue.cancel()

        assertFalse(queue.offer(byteArrayOf(1)))
        assertNull(queue.poll(timeoutMs = 0L))
        assertFalse(queue.awaitEmpty(timeoutMs = 0L))
    }
}
