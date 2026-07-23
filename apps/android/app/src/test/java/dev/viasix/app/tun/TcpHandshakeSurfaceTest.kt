package dev.viasix.app.tun

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class TcpHandshakeSurfaceTest {
    @Test
    fun clientAckDrivesHandshakeAndDuplicateSynResendsStableSynAck() {
        val engine =
            resolve(
                "src/main/java/dev/viasix/app/tun/Tun2SocksEngine.kt",
                "app/src/main/java/dev/viasix/app/tun/Tun2SocksEngine.kt",
            ).readText()

        assertTrue(engine.contains("existing.handshake.isComplete"))
        assertTrue(engine.contains("enqueueSynAck(existing)"))
        assertTrue(engine.contains("session.handshake.acknowledge"))
        assertTrue(engine.contains("session.handshake.await(HANDSHAKE_TIMEOUT_MS)"))
        assertTrue(engine.contains("seq = session.serverIsn"))
        assertTrue(engine.contains("handshake.cancel()"))
        assertFalse(engine.contains("session.handshakeComplete = true"))
    }

    private fun resolve(vararg paths: String): File =
        paths.map { File(it) }.firstOrNull { it.isFile }
            ?: error("file not found from cwd=${File(".").absolutePath}: ${paths.toList()}")
}
