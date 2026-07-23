package dev.viasix.app.session

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class VpnMtuPolicyTest {
    @Test
    fun acceptsMacOsSafeRangeAndTrimsWhitespace() {
        assertEquals(1_280, VpnMtuPolicy.normalize(" 1280 "))
        assertEquals(1_500, VpnMtuPolicy.normalize("1500"))
        assertEquals(9_000, VpnMtuPolicy.normalize("9000"))
    }

    @Test
    fun rejectsOutOfRangeAndNonDecimalValues() {
        listOf("", "1279", "9001", "1.5k", "+1500", "1500.0").forEach { value ->
            assertNull(value, VpnMtuPolicy.normalize(value))
            assertFalse(value, VpnMtuPolicy.isValid(value))
        }
        assertTrue(VpnMtuPolicy.isValid(VpnMtuPolicy.DEFAULT.toString()))
    }
}
