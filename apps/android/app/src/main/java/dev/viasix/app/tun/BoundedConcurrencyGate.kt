package dev.viasix.app.tun

import java.util.concurrent.Semaphore
import java.util.concurrent.atomic.AtomicBoolean

class BoundedConcurrencyGate(maxInFlight: Int) {
    private val permits: Semaphore

    init {
        require(maxInFlight > 0) { "maxInFlight must be positive" }
        permits = Semaphore(maxInFlight)
    }

    fun tryAcquire(): Permit? =
        if (permits.tryAcquire()) {
            Permit(this)
        } else {
            null
        }

    class Permit internal constructor(
        private val gate: BoundedConcurrencyGate,
    ) : AutoCloseable {
        private val released = AtomicBoolean(false)

        override fun close() {
            if (released.compareAndSet(false, true)) gate.permits.release()
        }
    }
}
