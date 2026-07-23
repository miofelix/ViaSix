package dev.viasix.app.tun

import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

class TcpHandshakeGate {
    private val completed = AtomicBoolean(false)
    private val released = CountDownLatch(1)

    val isComplete: Boolean
        get() = completed.get()

    fun acknowledge(
        acknowledgement: Long,
        expected: Long,
    ): Boolean {
        if (acknowledgement != expected) return false
        if (completed.compareAndSet(false, true)) released.countDown()
        return true
    }

    fun await(timeoutMs: Long): Boolean {
        try {
            released.await(timeoutMs.coerceAtLeast(0L), TimeUnit.MILLISECONDS)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        }
        return completed.get()
    }

    fun cancel() {
        released.countDown()
    }
}
