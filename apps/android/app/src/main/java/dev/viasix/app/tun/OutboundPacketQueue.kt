package dev.viasix.app.tun

import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/** A bounded TUN writer queue where datagrams may yield, but TCP stream packets never do. */
class OutboundPacketQueue(capacity: Int) {
    private class Entry(
        val packet: ByteArray,
        val lossless: Boolean,
    )

    private val queue = LinkedBlockingQueue<Entry>(capacity)
    private val offerLock = Any()
    private val cancelled = AtomicBoolean(false)

    fun offer(
        packet: ByteArray,
        lossless: Boolean,
        timeoutMs: Long = 0L,
    ): Boolean =
        synchronized(offerLock) {
            if (cancelled.get()) return@synchronized false
            val entry = Entry(packet, lossless)
            if (queue.offer(entry)) return@synchronized keepUnlessCancelled(entry)
            if (removeDroppable() && queue.offer(entry)) {
                return@synchronized keepUnlessCancelled(entry)
            }
            if (lossless) {
                return@synchronized try {
                    queue.offer(entry, timeoutMs.coerceAtLeast(0L), TimeUnit.MILLISECONDS) &&
                        keepUnlessCancelled(entry)
                } catch (_: InterruptedException) {
                    Thread.currentThread().interrupt()
                    false
                }
            }
            false
        }

    fun poll(timeoutMs: Long): ByteArray? =
        if (cancelled.get()) {
            null
        } else {
            pollEntry(timeoutMs)?.takeUnless { cancelled.get() }?.packet
        }

    fun cancel() {
        if (cancelled.compareAndSet(false, true)) queue.clear()
    }

    private fun pollEntry(timeoutMs: Long): Entry? =
        try {
            queue.poll(timeoutMs.coerceAtLeast(0L), TimeUnit.MILLISECONDS)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
            null
        }

    private fun keepUnlessCancelled(entry: Entry): Boolean {
        if (!cancelled.get()) return true
        queue.remove(entry)
        return false
    }

    private fun removeDroppable(): Boolean {
        val droppable = queue.firstOrNull { !it.lossless } ?: return false
        return queue.remove(droppable)
    }
}
