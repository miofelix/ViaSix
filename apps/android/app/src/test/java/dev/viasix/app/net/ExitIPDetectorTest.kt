package dev.viasix.app.net

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ExitIPDetectorTest {
    @Test
    fun parsesPlainTextIp() {
        val info = ExitIPDetector.parsePrimary("1.2.3.4\n")
        assertEquals("1.2.3.4", info.ip)
        assertEquals("IPv4", info.family)
    }

    @Test
    fun parsesJsonMyIpLaStyle() {
        val body =
            """
            {"ip":"2001:db8::1","location":{"city":"Tokyo","country_name":"Japan"}}
            """.trimIndent()
        val info = ExitIPDetector.parsePrimary(body)
        assertEquals("2001:db8::1", info.ip)
        assertEquals("IPv6", info.family)
        assertTrue(info.location.contains("Tokyo"))
    }

    @Test
    fun endpointSelection() {
        assertEquals(
            ExitIPDetector.IPV4_ENDPOINT,
            ExitIPDetector.endpointFor(ExitIPDetectionMode.IPV4, "https://example"),
        )
        assertEquals(
            "https://custom",
            ExitIPDetector.endpointFor(ExitIPDetectionMode.AUTOMATIC, "https://custom"),
        )
    }
}
