package dev.viasix.core.formatting

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class ByteRateFormatterTest {
    @Test
    fun formatsSmallBytes() {
        assertEquals("0 B", ByteRateFormatter.formatBytes(0))
        assertEquals("512 B", ByteRateFormatter.formatBytes(512))
    }

    @Test
    fun formatsKiloAndMega() {
        val kb = ByteRateFormatter.formatBytes(1024)
        assertTrue(kb.contains("KB") || kb.contains("1"))
        val mb = ByteRateFormatter.formatBytes(5L * 1024 * 1024)
        assertTrue(mb.contains("MB"))
    }

    @Test
    fun formatsRates() {
        val rate = ByteRateFormatter.formatRate(2048)
        assertTrue(rate.endsWith("/s"))
    }
}
