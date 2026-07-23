package dev.viasix.app.tun

import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

class TcpHandshakeGate {
    private val state = AtomicInteger(STATE_PENDING)
    private val released = CountDownLatch(1)

    val isComplete: Boolean
        get() = state.get() == STATE_COMPLETE

    fun acknowledge(
        sequence: Long,
        expectedSequence: Long,
        acknowledgement: Long,
        expectedAcknowledgement: Long,
        flags: Int,
    ): Boolean {
        if (
            sequence != expectedSequence ||
                acknowledgement != expectedAcknowledgement ||
                flags and Packet.ACK == 0 ||
                flags and (Packet.SYN or Packet.RST) != 0
        ) {
            return false
        }
        while (true) {
            when (state.get()) {
                STATE_COMPLETE -> return true
                STATE_CANCELLED -> return false
                STATE_PENDING -> {
                    if (state.compareAndSet(STATE_PENDING, STATE_COMPLETE)) {
                        released.countDown()
                        return true
                    }
                }
            }
        }
    }

    fun await(timeoutMs: Long): Boolean {
        try {
            released.await(timeoutMs.coerceAtLeast(0L), TimeUnit.MILLISECONDS)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        }
        return isComplete
    }

    fun cancel() {
        state.compareAndSet(STATE_PENDING, STATE_CANCELLED)
        released.countDown()
    }

    private companion object {
        const val STATE_PENDING = 0
        const val STATE_COMPLETE = 1
        const val STATE_CANCELLED = 2
    }
}
