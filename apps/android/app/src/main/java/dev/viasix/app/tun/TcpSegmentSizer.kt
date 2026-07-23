package dev.viasix.app.tun

/** Sizes synthesized downstream TCP packets so they never exceed the configured TUN MTU. */
internal object TcpSegmentSizer {
    private const val DEFAULT_IPV4_MSS = 536
    private const val DEFAULT_IPV6_MSS = 1_220

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

    fun negotiatedPayloadBytes(mtu: Int, ipv6: Boolean, peerMss: Int?): Int {
        val interfacePayload = maxPayloadBytes(mtu, ipv6)
        val peerPayload = peerMss ?: if (ipv6) DEFAULT_IPV6_MSS else DEFAULT_IPV4_MSS
        require(peerPayload > 0) { "peer MSS must be positive" }
        return minOf(interfacePayload, peerPayload)
    }
}
