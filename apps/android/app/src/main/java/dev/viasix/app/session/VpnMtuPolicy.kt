package dev.viasix.app.session

/** Safe VPN interface MTU range shared with the mature macOS local-proxy settings. */
object VpnMtuPolicy {
    const val DEFAULT = 1_500
    const val MIN = 1_280
    const val MAX = 9_000

    fun normalize(value: String): Int? {
        val input = value.trim()
        if (input.isEmpty() || input.any { !it.isDigit() }) return null
        return input.toIntOrNull()?.takeIf { it in MIN..MAX }
    }

    fun isValid(value: String): Boolean = normalize(value) != null
}
