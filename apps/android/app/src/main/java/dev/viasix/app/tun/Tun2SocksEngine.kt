package dev.viasix.app.tun

import android.net.VpnService
import android.os.ParcelFileDescriptor
import android.util.Log
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Socket
import java.nio.ByteBuffer
import java.nio.channels.FileChannel
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.random.Random

/**
 * Userspace IPv4 forwarder:
 * - TCP → SOCKS5 (mihomo mixed port)
 * - UDP/53 → protected DatagramSocket to upstream DNS
 *
 * Full UDP and IPv6 are intentionally out of scope for this milestone.
 */
class Tun2SocksEngine(
    private val vpnService: VpnService,
    private val tun: ParcelFileDescriptor,
    private val socksHost: String,
    private val socksPort: Int,
    private val dnsUpstream: InetAddress = InetAddress.getByName("1.1.1.1"),
) {
    private val running = AtomicBoolean(false)
    private val sessions = ConcurrentHashMap<String, TcpSession>()
    private var readerThread: Thread? = null
    private val executor: ExecutorService =
        Executors.newCachedThreadPool { r ->
            Thread(r, "viasix-tun-worker").apply { isDaemon = true }
        }
    private lateinit var inChannel: FileChannel
    private lateinit var outStream: FileOutputStream

    fun start() {
        if (!running.compareAndSet(false, true)) return
        inChannel = FileInputStream(tun.fileDescriptor).channel
        outStream = FileOutputStream(tun.fileDescriptor)
        readerThread =
            Thread(
                {
                    val buffer = ByteBuffer.allocate(32767)
                    while (running.get()) {
                        buffer.clear()
                        val len =
                            try {
                                inChannel.read(buffer)
                            } catch (_: Exception) {
                                break
                            }
                        if (len <= 0) continue
                        buffer.flip()
                        handlePacket(buffer)
                    }
                    running.set(false)
                },
                "viasix-tun-reader",
            ).also {
                it.isDaemon = true
                it.start()
            }
        Log.i(TAG, "Tun2SocksEngine started socks=$socksHost:$socksPort")
    }

    fun stop() {
        running.set(false)
        try {
            readerThread?.interrupt()
        } catch (_: Exception) {
        }
        readerThread = null
        sessions.values.forEach { it.close() }
        sessions.clear()
        executor.shutdownNow()
        try {
            inChannel.close()
        } catch (_: Exception) {
        }
        try {
            outStream.close()
        } catch (_: Exception) {
        }
        Log.i(TAG, "Tun2SocksEngine stopped")
    }

    private fun handlePacket(buffer: ByteBuffer) {
        val ip = Packet.parseIp4(buffer) ?: return
        when (ip.protocol) {
            Packet.PROTO_TCP.toInt() -> handleTcp(buffer, ip)
            Packet.PROTO_UDP.toInt() -> handleUdp(buffer, ip)
        }
    }

    private fun handleTcp(buffer: ByteBuffer, ip: Packet.Ip4) {
        val tcp = Packet.parseTcp(buffer, ip) ?: return
        val key = key(ip.source, tcp.sourcePort, ip.destination, tcp.destPort)

        if (tcp.flags and Packet.SYN != 0 && tcp.flags and Packet.ACK == 0) {
            if (sessions.containsKey(key)) return
            val session =
                TcpSession(
                    clientIp = ip.source,
                    clientPort = tcp.sourcePort,
                    remoteIp = ip.destination,
                    remotePort = tcp.destPort,
                    clientIsn = tcp.seq,
                )
            sessions[key] = session
            executor.execute { openTcpSession(key, session) }
            return
        }

        val session = sessions[key] ?: return
        if (tcp.flags and Packet.RST != 0) {
            session.close()
            sessions.remove(key)
            return
        }

        if (tcp.payloadLength > 0 && session.socket != null) {
            val payload = ByteArray(tcp.payloadLength)
            val pos = buffer.position()
            buffer.position(tcp.payloadOffset)
            buffer.get(payload)
            buffer.position(pos)
            try {
                session.socket!!.getOutputStream().write(payload)
                session.socket!!.getOutputStream().flush()
                session.clientNextSeq = tcp.seq + tcp.payloadLength
                // ACK client data
                writePacket(
                    Packet.buildIp4Tcp(
                        source = session.remoteIp,
                        destination = session.clientIp,
                        sourcePort = session.remotePort,
                        destPort = session.clientPort,
                        seq = session.serverSeq,
                        ack = session.clientNextSeq,
                        flags = Packet.ACK,
                        payload = ByteArray(0),
                    ),
                )
            } catch (error: Exception) {
                Log.w(TAG, "tcp write failed: ${error.message}")
                session.close()
                sessions.remove(key)
            }
        }

        if (tcp.flags and Packet.FIN != 0) {
            session.close()
            sessions.remove(key)
        }
    }

    private fun openTcpSession(key: String, session: TcpSession) {
        try {
            val socket =
                Socks5Client.connect(
                    socksHost,
                    socksPort,
                    session.remoteIp,
                    session.remotePort,
                )
            session.socket = socket
            session.serverSeq = Random.nextInt().toLong() and 0xffffffffL
            session.clientNextSeq = session.clientIsn + 1

            // SYN-ACK to client
            writePacket(
                Packet.buildIp4Tcp(
                    source = session.remoteIp,
                    destination = session.clientIp,
                    sourcePort = session.remotePort,
                    destPort = session.clientPort,
                    seq = session.serverSeq,
                    ack = session.clientNextSeq,
                    flags = Packet.SYN or Packet.ACK,
                    payload = ByteArray(0),
                ),
            )
            session.serverSeq = (session.serverSeq + 1) and 0xffffffffL

            executor.execute {
                val buf = ByteArray(16 * 1024)
                try {
                    val input = socket.getInputStream()
                    while (running.get() && !socket.isClosed) {
                        val n = input.read(buf)
                        if (n < 0) break
                        if (n == 0) continue
                        val chunk = buf.copyOf(n)
                        writePacket(
                            Packet.buildIp4Tcp(
                                source = session.remoteIp,
                                destination = session.clientIp,
                                sourcePort = session.remotePort,
                                destPort = session.clientPort,
                                seq = session.serverSeq,
                                ack = session.clientNextSeq,
                                flags = Packet.PSH or Packet.ACK,
                                payload = chunk,
                            ),
                        )
                        session.serverSeq = (session.serverSeq + n) and 0xffffffffL
                    }
                } catch (_: Exception) {
                } finally {
                    session.close()
                    sessions.remove(key)
                }
            }
        } catch (error: Exception) {
            Log.w(TAG, "SOCKS connect ${session.remoteIp}:${session.remotePort}: ${error.message}")
            // RST
            writePacket(
                Packet.buildIp4Tcp(
                    source = session.remoteIp,
                    destination = session.clientIp,
                    sourcePort = session.remotePort,
                    destPort = session.clientPort,
                    seq = 0,
                    ack = session.clientIsn + 1,
                    flags = Packet.RST or Packet.ACK,
                    payload = ByteArray(0),
                ),
            )
            session.close()
            sessions.remove(key)
        }
    }

    private fun handleUdp(buffer: ByteBuffer, ip: Packet.Ip4) {
        val udp = Packet.parseUdp(buffer, ip) ?: return
        if (udp.destPort != 53) return // only DNS for now
        val payload = ByteArray(udp.payloadLength)
        val pos = buffer.position()
        buffer.position(udp.payloadOffset)
        buffer.get(payload)
        buffer.position(pos)

        executor.execute {
            try {
                DatagramSocket().use { socket ->
                    vpnService.protect(socket)
                    socket.soTimeout = 5_000
                    val request =
                        DatagramPacket(
                            payload,
                            payload.size,
                            InetSocketAddress(dnsUpstream, 53),
                        )
                    socket.send(request)
                    val responseBuf = ByteArray(4096)
                    val response = DatagramPacket(responseBuf, responseBuf.size)
                    socket.receive(response)
                    val bytes = response.data.copyOf(response.length)
                    writePacket(
                        Packet.buildIp4Udp(
                            source = ip.destination,
                            destination = ip.source,
                            sourcePort = 53,
                            destPort = udp.sourcePort,
                            payload = bytes,
                        ),
                    )
                }
            } catch (error: Exception) {
                Log.w(TAG, "DNS forward failed: ${error.message}")
            }
        }
    }

    @Synchronized
    private fun writePacket(packet: ByteArray) {
        try {
            outStream.write(packet)
            outStream.flush()
        } catch (error: Exception) {
            Log.w(TAG, "tun write failed: ${error.message}")
        }
    }

    private fun key(
        src: InetAddress,
        srcPort: Int,
        dst: InetAddress,
        dstPort: Int,
    ): String = "${src.hostAddress}:$srcPort-${dst.hostAddress}:$dstPort"

    private class TcpSession(
        val clientIp: InetAddress,
        val clientPort: Int,
        val remoteIp: InetAddress,
        val remotePort: Int,
        val clientIsn: Long,
    ) {
        var socket: Socket? = null
        var serverSeq: Long = 0
        var clientNextSeq: Long = 0

        fun close() {
            try {
                socket?.close()
            } catch (_: Exception) {
            }
            socket = null
        }
    }

    companion object {
        private const val TAG = "Tun2SocksEngine"
    }
}
