package dev.viasix.app.tun

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.io.IOException
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import kotlin.concurrent.thread

class ProtectedSocketConnectorTest {
    @Test
    fun protectsSocketBeforeConnecting() {
        val loopback = InetAddress.getLoopbackAddress()
        ServerSocket(0, 1, loopback).use { server ->
            val accepted = thread(start = true, isDaemon = true) { server.accept().use { } }
            var protectedBeforeConnect = false

            ProtectedSocketConnector.connect(
                targetHost = loopback,
                targetPort = server.localPort,
                protect = { socket ->
                    protectedBeforeConnect = !socket.isConnected && !socket.isClosed
                    true
                },
            ).use { socket ->
                assertTrue(socket.isConnected)
            }
            accepted.join(2_000)
            assertFalse(accepted.isAlive)
            assertTrue(protectedBeforeConnect)
        }
    }

    @Test
    fun protectFailureClosesSocketWithoutConnecting() {
        var socketWasOpen = false
        var rejectedSocket: Socket? = null
        try {
            ProtectedSocketConnector.connect(
                targetHost = InetAddress.getLoopbackAddress(),
                targetPort = 53,
                protect = { socket ->
                    rejectedSocket = socket
                    socketWasOpen = !socket.isClosed && !socket.isConnected
                    false
                },
            )
            fail("expected protect failure")
        } catch (error: IOException) {
            assertTrue(error.message.orEmpty().contains("protect"))
        }
        assertTrue(socketWasOpen)
        assertTrue(rejectedSocket?.isClosed == true)
    }
}
