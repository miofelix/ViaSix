package dev.viasix.app.tun

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class Ipv4FragmentSurfaceTest {
    @Test
    fun parserRejectsIpv4FragmentsBeforeTransportDispatch() {
        val packet =
            resolve(
                "src/main/java/dev/viasix/app/tun/Packet.kt",
                "app/src/main/java/dev/viasix/app/tun/Packet.kt",
            ).readText()

        assertTrue(packet.contains("val moreFragments = fragmentBits and 0x2000 != 0"))
        assertTrue(packet.contains("val fragmentOffset = fragmentBits and 0x1fff"))
        assertTrue(packet.contains("reservedFlag || moreFragments || fragmentOffset != 0"))
    }

    private fun resolve(vararg paths: String): File =
        paths.map { File(it) }.firstOrNull { it.isFile }
            ?: error("file not found from cwd=${File(".").absolutePath}: ${paths.toList()}")
}
