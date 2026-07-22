package dev.viasix.core.speedtest

/**
 * CFST CLI parameters aligned with macOS [SpeedTestParameters] and Windows
 * [SpeedTestRequest] defaults used for IPv6 优选.
 */
data class SpeedTestParameters(
    val ipFile: String = "",
    val ipRange: String = "",
    val threads: Int = DEFAULT_THREADS,
    val pingCount: Int = DEFAULT_PING_COUNT,
    val downloadCount: Int = DEFAULT_DOWNLOAD_COUNT,
    val downloadTime: Int = DEFAULT_DOWNLOAD_TIME,
    val latencyUpperBound: Int = DEFAULT_LATENCY_UPPER,
    val latencyLowerBound: Int = DEFAULT_LATENCY_LOWER,
    val lossRateUpperBound: Double = DEFAULT_LOSS_RATE_UPPER,
    val speedLowerBound: Double = DEFAULT_SPEED_LOWER,
    val colo: String = "",
    val port: Int = DEFAULT_PORT,
    val url: String = "",
    val httping: Boolean = true,
    val httpingCode: Int = 0,
    val disableDownload: Boolean = false,
    val allIP: Boolean = false,
    val debug: Boolean = false,
) {
    fun hasIpSource(): Boolean =
        ipRange.trim().isNotEmpty() || ipFile.trim().isNotEmpty()

    /**
     * Build CFST argv after the executable path (no binary name).
     * Requires either [ipRange] or [ipFile]; does not check that [ipFile] exists
     * (caller validates filesystem).
     */
    fun commandLineArguments(resultPath: String): List<String> {
        require(hasIpSource()) { "Either ipRange or ipFile is required" }
        require(threads in 1..1_000) { "threads must be 1..1000" }
        require(pingCount in 1..100) { "pingCount must be 1..100" }
        require(downloadCount in 0..100) { "downloadCount must be 0..100" }
        require(downloadTime in 1..3_600) { "downloadTime must be 1..3600" }
        require(port in 1..65_535) { "port must be 1..65535" }

        val args =
            mutableListOf(
                "-o",
                resultPath,
                "-tp",
                port.toString(),
                "-n",
                threads.toString(),
                "-t",
                pingCount.toString(),
                "-dn",
                downloadCount.toString(),
                "-dt",
                downloadTime.toString(),
                "-tl",
                latencyUpperBound.toString(),
                "-tll",
                latencyLowerBound.toString(),
                "-tlr",
                String.format(java.util.Locale.US, "%.2f", lossRateUpperBound),
                "-sl",
                String.format(java.util.Locale.US, "%.2f", speedLowerBound),
                // Suppress interactive table so CSV is the sole result channel.
                "-p",
                "0",
            )

        val range = ipRange.trim()
        if (range.isNotEmpty()) {
            val normalized =
                range
                    .split(",")
                    .joinToString(",") { it.trim() }
                    .trim(',')
            args += listOf("-ip", normalized)
        } else {
            args += listOf("-f", ipFile.trim())
        }

        if (httping) {
            args += "-httping"
            if (httpingCode > 0) {
                args += listOf("-httping-code", httpingCode.toString())
            }
        }
        val coloTrim = colo.trim()
        if (coloTrim.isNotEmpty()) {
            args += listOf("-cfcolo", coloTrim)
        }
        val urlTrim = url.trim()
        if (urlTrim.isNotEmpty()) {
            args += listOf("-url", urlTrim)
        }
        if (disableDownload) args += "-dd"
        if (allIP) args += "-allip"
        if (debug) args += "-debug"
        return args
    }

    companion object {
        const val DEFAULT_THREADS = 200
        const val DEFAULT_PING_COUNT = 4
        const val DEFAULT_DOWNLOAD_COUNT = 10
        const val DEFAULT_DOWNLOAD_TIME = 10
        const val DEFAULT_LATENCY_UPPER = 9_999
        const val DEFAULT_LATENCY_LOWER = 0
        const val DEFAULT_LOSS_RATE_UPPER = 1.0
        const val DEFAULT_SPEED_LOWER = 0.0
        const val DEFAULT_PORT = 443

        /** Default Cloudflare IPv6 main prefix used when no custom range is set. */
        const val DEFAULT_IPV6_RANGE = "2606:4700::/32"

        fun defaultsForRange(ipRange: String = DEFAULT_IPV6_RANGE): SpeedTestParameters =
            SpeedTestParameters(ipRange = ipRange)

        fun defaultsForFile(ipFile: String): SpeedTestParameters =
            SpeedTestParameters(ipFile = ipFile)
    }
}

/** Built-in IPv6 CIDR presets (subset of macOS ipv6.txt / Windows presets). */
data class Ipv6IpPreset(
    val id: String,
    val title: String,
    val description: String,
    val ipRange: String,
)

object Ipv6IpPresets {
    val all: List<Ipv6IpPreset> =
        listOf(
            Ipv6IpPreset(
                id = "cf-main",
                title = "Cloudflare 主段",
                description = "2606:4700::/32",
                ipRange = "2606:4700::/32",
            ),
            Ipv6IpPreset(
                id = "cf-bundle",
                title = "Cloudflare 常用 IPv6 段",
                description = "macOS 默认 ipv6 列表核心段",
                ipRange =
                    listOf(
                        "2400:cb00::/32",
                        "2606:4700::/32",
                        "2803:f800::/32",
                        "2405:b500::/32",
                        "2405:8100::/32",
                        "2a06:98c0::/29",
                        "2c0f:f248::/32",
                    ).joinToString(","),
            ),
            Ipv6IpPreset(
                id = "cf-apac",
                title = "亚太相关段",
                description = "2400:cb00 + 2405 段",
                ipRange = "2400:cb00::/32,2405:b500::/32,2405:8100::/32",
            ),
        )
}
