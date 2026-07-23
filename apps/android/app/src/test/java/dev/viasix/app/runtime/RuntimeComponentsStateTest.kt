package dev.viasix.app.runtime

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RuntimeComponentsStateTest {
    @Test
    fun repairEligibilityDistinguishesReadyMissingInvalidAndUnsupported() {
        assertFalse(RuntimeComponentInfo(RuntimeComponentCondition.READY).needsRepair)
        assertTrue(RuntimeComponentInfo(RuntimeComponentCondition.MISSING).needsRepair)
        assertTrue(RuntimeComponentInfo(RuntimeComponentCondition.INVALID).needsRepair)
        assertTrue(RuntimeComponentInfo(RuntimeComponentCondition.ERROR).needsRepair)
        assertFalse(RuntimeComponentInfo(RuntimeComponentCondition.UNSUPPORTED).needsRepair)
    }

    @Test
    fun componentUpdatesDoNotOverwriteTheOtherStatus() {
        val ready = RuntimeComponentInfo(RuntimeComponentCondition.READY, "ok")
        val missing = RuntimeComponentInfo(RuntimeComponentCondition.MISSING, "missing")
        val state =
            RuntimeComponentsState(cfst = missing)
                .withInfo(RuntimeComponentId.MIHOMO, ready)

        assertEquals(ready, state.mihomo)
        assertEquals(missing, state.cfst)
        assertFalse(state.busy)
        assertTrue(state.copy(repairing = RuntimeComponentId.CFST).busy)
    }
}
