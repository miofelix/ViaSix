package dev.viasix.app.net

import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets

enum class ExitIPDetectionMode(val wire: String, val label: String) {
    AUTOMATIC("automatic", "自动"),
    IPV4("ipv4", "IPv4"),
    IPV6("ipv6", "IPv6");

    companion object {
        fun parse(raw: String?): ExitIPDetectionMode =
            entries.firstOrNull { it.wire == raw || it.name.equals(raw, ignoreCase = true) }
                ?: AUTOMATIC
    }
}

data class ExitIPInfo(
    val ip: String,
    val location: String = "",
    val details: String = "",
    val family: String = "",
)

/**
 * Exit IP detection aligned with macOS endpoints and parsers.
 * JSON parsing is intentionally dependency-light so unit tests run on the JVM
 * without Android's stubbed org.json.
 */
object ExitIPDetector {
    const val DEFAULT_ENDPOINT = "https://api.myip.la/cn?json"
    const val IPV4_ENDPOINT = "https://api-ipv4.ip.sb/ip"
    const val IPV6_ENDPOINT = "https://api-ipv6.ip.sb/ip"
    const val GEO_ENDPOINT = "https://ipwho.is"

    fun endpointFor(mode: ExitIPDetectionMode, automaticEndpoint: String): String =
        when (mode) {
            ExitIPDetectionMode.AUTOMATIC -> automaticEndpoint.ifBlank { DEFAULT_ENDPOINT }
            ExitIPDetectionMode.IPV4 -> IPV4_ENDPOINT
            ExitIPDetectionMode.IPV6 -> IPV6_ENDPOINT
        }

    fun detect(
        mode: ExitIPDetectionMode = ExitIPDetectionMode.AUTOMATIC,
        automaticEndpoint: String = DEFAULT_ENDPOINT,
        timeoutMs: Int = 8000,
        enrich: Boolean = true,
    ): Result<ExitIPInfo> {
        return try {
            val endpoint = endpointFor(mode, automaticEndpoint)
            val raw = httpGet(endpoint, timeoutMs)
            var info = parsePrimary(raw)
            if (enrich) {
                info = enrichWithGeo(info, timeoutMs) ?: info
            }
            Result.success(info)
        } catch (error: Exception) {
            Result.failure(error)
        }
    }

    fun parsePrimary(body: String): ExitIPInfo {
        val trimmed = body.trim()
        if (trimmed.startsWith("{")) {
            val ip =
                stringField(trimmed, "ip")
                    ?: stringField(trimmed, "IP")
                    ?: stringField(trimmed, "query")
                    ?: stringField(trimmed, "origin")
                    ?: throw IllegalArgumentException("no ip field")
            val city =
                nestedStringField(trimmed, "location", "city")
                    ?: stringField(trimmed, "city")
            val country =
                nestedStringField(trimmed, "location", "country_name")
                    ?: stringField(trimmed, "country")
            val region = stringField(trimmed, "region")
            val location =
                listOfNotNull(city, region, country)
                    .filter { it.isNotBlank() }
                    .distinct()
                    .joinToString(" · ")
            return ExitIPInfo(
                ip = normalizeIp(ip),
                location = location,
                family = addressFamily(ip),
            )
        }
        val ip = normalizeIp(trimmed.lineSequence().first().trim())
        return ExitIPInfo(ip = ip, family = addressFamily(ip))
    }

    private fun enrichWithGeo(info: ExitIPInfo, timeoutMs: Int): ExitIPInfo? {
        return try {
            val url = "$GEO_ENDPOINT/${info.ip}?lang=zh-CN"
            val body = httpGet(url, timeoutMs)
            if (body.contains("\"success\":false")) return null
            val location =
                listOfNotNull(
                    stringField(body, "country"),
                    stringField(body, "region"),
                    stringField(body, "city"),
                ).filter { it.isNotBlank() }.joinToString(" · ")
            val details =
                listOfNotNull(
                    nestedStringField(body, "connection", "isp"),
                    nestedStringField(body, "connection", "org"),
                    stringField(body, "isp"),
                    stringField(body, "org"),
                    stringField(body, "timezone"),
                ).filter { it.isNotBlank() }.distinct().joinToString(" · ")
            info.copy(
                location = location.ifBlank { info.location },
                details = details.ifBlank { info.details },
            )
        } catch (_: Exception) {
            null
        }
    }

    private fun stringField(json: String, key: String): String? {
        val pattern = Regex("\"${Regex.escape(key)}\"\\s*:\\s*\"([^\"]*)\"")
        return pattern.find(json)?.groupValues?.get(1)?.takeIf { it.isNotBlank() }
    }

    private fun nestedStringField(json: String, parent: String, key: String): String? {
        val parentPattern =
            Regex("\"${Regex.escape(parent)}\"\\s*:\\s*\\{([^}]*)\\}")
        val block = parentPattern.find(json)?.groupValues?.get(1) ?: return null
        return stringField("{$block}", key)
    }

    private fun httpGet(url: String, timeoutMs: Int): String {
        val conn = (URL(url).openConnection() as HttpURLConnection)
        conn.connectTimeout = timeoutMs
        conn.readTimeout = timeoutMs
        conn.requestMethod = "GET"
        conn.setRequestProperty("User-Agent", "ViaSix-Android/0.1")
        conn.setRequestProperty("Accept", "application/json,text/plain,*/*")
        val code = conn.responseCode
        val stream =
            try {
                conn.inputStream
            } catch (_: Exception) {
                conn.errorStream
            } ?: throw IllegalStateException("empty body")
        val body = stream.bufferedReader(StandardCharsets.UTF_8).use { it.readText() }
        if (code !in 200..299) {
            throw IllegalStateException("HTTP $code")
        }
        return body
    }

    fun normalizeIp(raw: String): String {
        var value = raw.trim().removePrefix("\"").removeSuffix("\"")
        if (value.startsWith('[') && value.endsWith(']')) {
            value = value.substring(1, value.length - 1)
        }
        if (value.isEmpty()) throw IllegalArgumentException("empty ip")
        return value
    }

    fun addressFamily(ip: String): String =
        if (ip.contains(':')) "IPv6" else "IPv4"
}
