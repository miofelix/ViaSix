package dev.viasix.app.tun

import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class BoundedConcurrencyGateTest {
    @Test
    fun capacityIsRecoveredWhenPermitCloses() {
        val gate = BoundedConcurrencyGate(maxInFlight = 2)
        val first = gate.tryAcquire()
        val second = gate.tryAcquire()

        assertNotNull(first)
        assertNotNull(second)
        assertNull(gate.tryAcquire())

        first!!.close()
        assertNotNull(gate.tryAcquire())
    }

    @Test
    fun closingPermitTwiceDoesNotOverReleaseCapacity() {
        val gate = BoundedConcurrencyGate(maxInFlight = 1)
        val permit = gate.tryAcquire()!!

        permit.close()
        permit.close()

        assertNotNull(gate.tryAcquire())
        assertNull(gate.tryAcquire())
    }
}
