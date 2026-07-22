package dev.viasix.app.tun

import java.net.InetAddress
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Minimal IPv4 packet helpers for the userspace TCP/DNS forwarder.
 */
internal object Packet {
    const val IP4_HEADER_SIZE = 20
    const val TCP_HEADER_SIZE = 20
    const val UDP_HEADER_SIZE = 8

    const val PROTO_TCP: Byte = 6
    const val PROTO_UDP: Byte = 17

    // TCP flags
    const val FIN = 0x01
    const val SYN = 0x02
    const val RST = 0x04
    const val PSH = 0x08
    const val ACK = 0x10

    data class Ip4(
        val versionIhl: Int,
        val totalLength: Int,
        val protocol: Int,
        val source: InetAddress,
        val destination: InetAddress,
        val headerLength: Int,
        val payloadOffset: Int,
    )

    data class Tcp(
        val sourcePort: Int,
        val destPort: Int,
        val seq: Long,
        val ack: Long,
        val dataOffset: Int,
        val flags: Int,
        val payloadOffset: Int,
        val payloadLength: Int,
    )

    data class Udp(
        val sourcePort: Int,
        val destPort: Int,
        val length: Int,
        val payloadOffset: Int,
        val payloadLength: Int,
    )

    fun parseIp4(buffer: ByteBuffer): Ip4? {
        if (buffer.remaining() < IP4_HEADER_SIZE) return null
        val start = buffer.position()
        val versionIhl = buffer.get(start).toInt() and 0xff
        val version = versionIhl ushr 4
        if (version != 4) return null
        val ihl = (versionIhl and 0x0f) * 4
        if (ihl < IP4_HEADER_SIZE || buffer.remaining() < ihl) return null
        val totalLength = buffer.getShort(start + 2).toInt() and 0xffff
        val protocol = buffer.get(start + 9).toInt() and 0xff
        val src = ByteArray(4)
        val dst = ByteArray(4)
        buffer.position(start + 12)
        buffer.get(src)
        buffer.get(dst)
        buffer.position(start)
        return Ip4(
            versionIhl = versionIhl,
            totalLength = totalLength,
            protocol = protocol,
            source = InetAddress.getByAddress(src),
            destination = InetAddress.getByAddress(dst),
            headerLength = ihl,
            payloadOffset = start + ihl,
        )
    }

    fun parseTcp(buffer: ByteBuffer, ip: Ip4): Tcp? {
        val start = ip.payloadOffset
        if (buffer.limit() - start < TCP_HEADER_SIZE) return null
        val sourcePort = buffer.getShort(start).toInt() and 0xffff
        val destPort = buffer.getShort(start + 2).toInt() and 0xffff
        val seq = buffer.getInt(start + 4).toLong() and 0xffffffffL
        val ack = buffer.getInt(start + 8).toLong() and 0xffffffffL
        val dataOffset = ((buffer.get(start + 12).toInt() and 0xf0) ushr 4) * 4
        val flags = buffer.get(start + 13).toInt() and 0xff
        val payloadOffset = start + dataOffset
        val payloadLength = (ip.totalLength - ip.headerLength - dataOffset).coerceAtLeast(0)
        return Tcp(sourcePort, destPort, seq, ack, dataOffset, flags, payloadOffset, payloadLength)
    }

    fun parseUdp(buffer: ByteBuffer, ip: Ip4): Udp? {
        val start = ip.payloadOffset
        if (buffer.limit() - start < UDP_HEADER_SIZE) return null
        val sourcePort = buffer.getShort(start).toInt() and 0xffff
        val destPort = buffer.getShort(start + 2).toInt() and 0xffff
        val length = buffer.getShort(start + 4).toInt() and 0xffff
        val payloadOffset = start + UDP_HEADER_SIZE
        val payloadLength = (length - UDP_HEADER_SIZE).coerceAtLeast(0)
        return Udp(sourcePort, destPort, length, payloadOffset, payloadLength)
    }

    fun buildIp4Tcp(
        source: InetAddress,
        destination: InetAddress,
        sourcePort: Int,
        destPort: Int,
        seq: Long,
        ack: Long,
        flags: Int,
        payload: ByteArray,
    ): ByteArray {
        val total = IP4_HEADER_SIZE + TCP_HEADER_SIZE + payload.size
        val buf = ByteBuffer.allocate(total).order(ByteOrder.BIG_ENDIAN)
        // IPv4
        buf.put(0x45.toByte())
        buf.put(0)
        buf.putShort(total.toShort())
        buf.putShort(0) // id
        buf.putShort(0x4000.toShort()) // don't fragment
        buf.put(64) // ttl
        buf.put(PROTO_TCP)
        buf.putShort(0) // checksum placeholder
        buf.put(source.address)
        buf.put(destination.address)
        // TCP
        buf.putShort(sourcePort.toShort())
        buf.putShort(destPort.toShort())
        buf.putInt(seq.toInt())
        buf.putInt(ack.toInt())
        buf.put(((5 shl 4).toByte())) // data offset = 5
        buf.put(flags.toByte())
        buf.putShort(0xffff.toShort()) // window
        buf.putShort(0) // checksum
        buf.putShort(0) // urgent
        if (payload.isNotEmpty()) buf.put(payload)

        val bytes = buf.array()
        writeChecksum(bytes, 10, ipChecksum(bytes, 0, IP4_HEADER_SIZE))
        writeChecksum(
            bytes,
            IP4_HEADER_SIZE + 16,
            tcpChecksum(bytes, source.address, destination.address, IP4_HEADER_SIZE, TCP_HEADER_SIZE + payload.size),
        )
        return bytes
    }

    fun buildIp4Udp(
        source: InetAddress,
        destination: InetAddress,
        sourcePort: Int,
        destPort: Int,
        payload: ByteArray,
    ): ByteArray {
        val udpLen = UDP_HEADER_SIZE + payload.size
        val total = IP4_HEADER_SIZE + udpLen
        val buf = ByteBuffer.allocate(total).order(ByteOrder.BIG_ENDIAN)
        buf.put(0x45.toByte())
        buf.put(0)
        buf.putShort(total.toShort())
        buf.putShort(0)
        buf.putShort(0x4000.toShort())
        buf.put(64)
        buf.put(PROTO_UDP)
        buf.putShort(0)
        buf.put(source.address)
        buf.put(destination.address)
        buf.putShort(sourcePort.toShort())
        buf.putShort(destPort.toShort())
        buf.putShort(udpLen.toShort())
        buf.putShort(0)
        buf.put(payload)
        val bytes = buf.array()
        writeChecksum(bytes, 10, ipChecksum(bytes, 0, IP4_HEADER_SIZE))
        // UDP checksum optional for IPv4; leave 0.
        return bytes
    }

    private fun writeChecksum(bytes: ByteArray, offset: Int, value: Int) {
        bytes[offset] = ((value ushr 8) and 0xff).toByte()
        bytes[offset + 1] = (value and 0xff).toByte()
    }

    private fun ipChecksum(buf: ByteArray, offset: Int, length: Int): Int {
        var sum = 0
        var i = offset
        val end = offset + length
        while (i + 1 < end) {
            sum += ((buf[i].toInt() and 0xff) shl 8) or (buf[i + 1].toInt() and 0xff)
            i += 2
        }
        if (i < end) sum += (buf[i].toInt() and 0xff) shl 8
        while (sum ushr 16 != 0) sum = (sum and 0xffff) + (sum ushr 16)
        return sum.inv() and 0xffff
    }

    private fun tcpChecksum(
        packet: ByteArray,
        src: ByteArray,
        dst: ByteArray,
        tcpOffset: Int,
        tcpLength: Int,
    ): Int {
        var sum = 0
        // pseudo header
        sum += ((src[0].toInt() and 0xff) shl 8) or (src[1].toInt() and 0xff)
        sum += ((src[2].toInt() and 0xff) shl 8) or (src[3].toInt() and 0xff)
        sum += ((dst[0].toInt() and 0xff) shl 8) or (dst[1].toInt() and 0xff)
        sum += ((dst[2].toInt() and 0xff) shl 8) or (dst[3].toInt() and 0xff)
        sum += PROTO_TCP.toInt() and 0xff
        sum += tcpLength
        var i = tcpOffset
        val end = tcpOffset + tcpLength
        while (i + 1 < end) {
            sum += ((packet[i].toInt() and 0xff) shl 8) or (packet[i + 1].toInt() and 0xff)
            i += 2
        }
        if (i < end) sum += (packet[i].toInt() and 0xff) shl 8
        while (sum ushr 16 != 0) sum = (sum and 0xffff) + (sum ushr 16)
        return sum.inv() and 0xffff
    }
}
