package dev.viasix.app.net

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import java.net.InetSocketAddress
import java.net.Proxy

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

    @Test
    fun runningRuntimeUsesLoopbackMixedHttpProxy() {
        val selected = ExitIPRoutePolicy.proxyForRuntime(running = true, mixedPort = 11451)
        val javaProxy = requireNotNull(selected).asJavaProxy()
        val address = javaProxy.address() as InetSocketAddress

        assertEquals(Proxy.Type.HTTP, javaProxy.type())
        assertEquals("127.0.0.1", address.hostString)
        assertEquals(11451, address.port)
        assertEquals(ExitIPRoute.MIXED_PROXY, ExitIPRoutePolicy.routeFor(selected))
        assertEquals(ExitIPRoute.MIXED_PROXY, ExitIPRoutePolicy.routeForRuntime(running = true))
        assertEquals(ExitIPRoute.DIRECT, ExitIPRoutePolicy.routeForRuntime(running = false))
        assertNull(ExitIPRoutePolicy.proxyForRuntime(running = false, mixedPort = 11451))
    }

    @Test
    fun explicitAddressFamilyRejectsMismatchedResponse() {
        val error =
            assertThrows(IllegalArgumentException::class.java) {
                ExitIPDetector.validateExpectedFamily(
                    mode = ExitIPDetectionMode.IPV6,
                    info = ExitIPInfo(ip = "203.0.113.1", family = "IPv4"),
                )
            }

        assertTrue(error.message.orEmpty().contains("IPv6"))
    }
}
