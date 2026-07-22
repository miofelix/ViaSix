package dev.viasix.core.profile

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class ProfileSummaryParserTest {
    @Test
    fun parsesManagedProfile() {
        val yaml =
            """
            proxies:
              - name: My VLESS
                type: vless
                server: origin.example.com
                port: 443
            x-viasix:
              version: 1
              primary-server: selected-ip
            """.trimIndent()
        val summary = ProfileSummaryParser.parse(yaml)
        assertTrue(summary.isManaged)
        assertEquals("My VLESS", summary.primary?.name)
        assertEquals("vless", summary.primary?.type)
        assertEquals("selected-ip", summary.primaryServerMarker)
        assertEquals("IPv6 托管入口", summary.statusLabel)
    }

    @Test
    fun flagsMissingXViasix() {
        val summary =
            ProfileSummaryParser.parse(
                """
                proxies:
                  - name: a
                    type: ss
                    server: 1.2.3.4
                    port: 1
                """.trimIndent(),
            )
        assertFalse(summary.hasXViasix)
        assertTrue(summary.warnings.any { it.contains("x-viasix") })
    }

    @Test
    fun emptyIsWarned() {
        val summary = ProfileSummaryParser.parse("")
        assertEquals(0, summary.proxyCount)
        assertTrue(summary.warnings.isNotEmpty())
    }
}
