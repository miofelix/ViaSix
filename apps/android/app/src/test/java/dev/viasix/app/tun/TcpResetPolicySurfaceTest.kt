package dev.viasix.app.tun

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class TcpResetPolicySurfaceTest {
    @Test
    fun synchronizedResetUsesRfc5961SequenceValidation() {
        val engine =
            resolve(
                "src/main/java/dev/viasix/app/tun/Tun2SocksEngine.kt",
                "app/src/main/java/dev/viasix/app/tun/Tun2SocksEngine.kt",
            ).readText()
        val classification = engine.indexOf("TcpResetPolicy.classify(")
        val actionDispatch = engine.indexOf("TcpResetPolicy.Action.CLOSE", classification)

        assertTrue(classification >= 0)
        assertTrue(actionDispatch > classification)
        assertTrue(engine.contains("if (session.socket == null) return"))
        assertTrue(engine.contains("nextExpected = session.clientNextSeq"))
        assertTrue(
            engine.substring(classification, actionDispatch).contains("receiveWindow = receiveWindow"),
        )
        assertTrue(engine.contains("TcpResetPolicy.Action.CLOSE -> removeSession(key, session)"))
        assertTrue(engine.contains("TcpResetPolicy.Action.CHALLENGE_ACK"))
        assertTrue(engine.contains("enqueueChallengeAck(session)"))
        assertTrue(engine.contains("TcpResetPolicy.Action.DROP -> Unit"))
    }

    private fun resolve(vararg paths: String): File =
        paths.map { File(it) }.firstOrNull { it.isFile }
            ?: error("file not found from cwd=${File(".").absolutePath}: ${paths.toList()}")
}
