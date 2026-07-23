package dev.viasix.app.tun

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class BoundedWorkerPoolTest {
    @Test
    fun rejectsWhenAllWorkersAreBusyWithoutQueuingBlockingWork() {
        val pool = BoundedWorkerPool(maxThreads = 2, threadNamePrefix = "test-worker")
        val started = CountDownLatch(2)
        val release = CountDownLatch(1)
        try {
            assertTrue(pool.execute {
                started.countDown()
                release.await()
            })
            assertTrue(pool.execute {
                started.countDown()
                release.await()
            })
            assertTrue(started.await(1, TimeUnit.SECONDS))
            assertFalse(pool.execute { error("must not run on the submitting thread") })
        } finally {
            release.countDown()
            pool.close()
        }
        assertTrue(pool.largestPoolSize <= 2)
    }

    @Test
    fun acceptsWorkAgainAfterAWorkerReturns() {
        val pool = BoundedWorkerPool(maxThreads = 1, threadNamePrefix = "test-worker")
        val firstDone = CountDownLatch(1)
        val secondDone = CountDownLatch(1)
        try {
            assertTrue(pool.execute { firstDone.countDown() })
            assertTrue(firstDone.await(1, TimeUnit.SECONDS))
            assertTrue(executeEventually(pool) { secondDone.countDown() })
            assertTrue(secondDone.await(1, TimeUnit.SECONDS))
        } finally {
            pool.close()
        }
    }

    private fun executeEventually(
        pool: BoundedWorkerPool,
        task: () -> Unit,
    ): Boolean {
        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(1)
        while (System.nanoTime() < deadline) {
            if (pool.execute(task)) return true
            Thread.yield()
        }
        return false
    }
}
