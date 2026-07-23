package dev.viasix.app.tun

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import java.net.InetAddress

class TcpSegmentSizerTest {
    @Test
    fun subtractsFixedIpv4AndIpv6TcpHeaders() {
        assertEquals(1_460, TcpSegmentSizer.maxPayloadBytes(mtu = 1_500, ipv6 = false))
        assertEquals(1_440, TcpSegmentSizer.maxPayloadBytes(mtu = 1_500, ipv6 = true))
        assertEquals(1_240, TcpSegmentSizer.maxPayloadBytes(mtu = 1_280, ipv6 = false))
        assertEquals(1_220, TcpSegmentSizer.maxPayloadBytes(mtu = 1_280, ipv6 = true))
    }

    @Test
    fun maximumPayloadBuildsPacketsExactlyAtMtu() {
        val mtu = 1_420
        val client4 = InetAddress.getByName("10.10.0.2")
        val remote4 = InetAddress.getByName("192.0.2.10")
        val client6 = InetAddress.getByName("fd00:10:10::2")
        val remote6 = InetAddress.getByName("2001:db8::10")

        val packet4 =
            Packet.buildIp4Tcp(
                source = remote4,
                destination = client4,
                sourcePort = 443,
                destPort = 40_000,
                seq = 1,
                ack = 2,
                flags = Packet.PSH or Packet.ACK,
                payload = ByteArray(TcpSegmentSizer.maxPayloadBytes(mtu, ipv6 = false)),
            )
        val packet6 =
            Packet.buildIp6Tcp(
                source = remote6,
                destination = client6,
                sourcePort = 443,
                destPort = 40_000,
                seq = 1,
                ack = 2,
                flags = Packet.PSH or Packet.ACK,
                payload = ByteArray(TcpSegmentSizer.maxPayloadBytes(mtu, ipv6 = true)),
            )

        assertEquals(mtu, packet4.size)
        assertEquals(mtu, packet6.size)
    }

    @Test
    fun rejectsMtuWithoutRoomForHeaders() {
        assertThrows(IllegalArgumentException::class.java) {
            TcpSegmentSizer.maxPayloadBytes(
                mtu = Packet.IP6_HEADER_SIZE + Packet.TCP_HEADER_SIZE,
                ipv6 = true,
            )
        }
    }

    @Test
    fun capsPayloadToPeerMssAndUsesProtocolDefaultsWhenAbsent() {
        assertEquals(
            536,
            TcpSegmentSizer.negotiatedPayloadBytes(mtu = 1_500, ipv6 = false, peerMss = null),
        )
        assertEquals(
            1_220,
            TcpSegmentSizer.negotiatedPayloadBytes(mtu = 1_500, ipv6 = true, peerMss = null),
        )
        assertEquals(
            1_000,
            TcpSegmentSizer.negotiatedPayloadBytes(mtu = 1_500, ipv6 = false, peerMss = 1_000),
        )
        assertEquals(
            1_460,
            TcpSegmentSizer.negotiatedPayloadBytes(mtu = 1_500, ipv6 = false, peerMss = 2_000),
        )
        assertThrows(IllegalArgumentException::class.java) {
            TcpSegmentSizer.negotiatedPayloadBytes(mtu = 1_500, ipv6 = false, peerMss = 0)
        }
    }
}
