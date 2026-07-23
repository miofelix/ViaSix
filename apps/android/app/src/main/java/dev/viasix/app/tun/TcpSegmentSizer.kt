package dev.viasix.app.tun

/** Sizes synthesized downstream TCP packets so they never exceed the configured TUN MTU. */
internal object TcpSegmentSizer {
    fun maxPayloadBytes(mtu: Int, ipv6: Boolean): Int {
        val headerBytes =
            if (ipv6) {
                Packet.IP6_HEADER_SIZE + Packet.TCP_HEADER_SIZE
            } else {
                Packet.IP4_HEADER_SIZE + Packet.TCP_HEADER_SIZE
            }
        require(mtu > headerBytes) { "MTU $mtu is too small for a TCP packet" }
        return mtu - headerBytes
    }
}
