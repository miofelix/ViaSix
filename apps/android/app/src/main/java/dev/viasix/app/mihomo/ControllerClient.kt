package dev.viasix.app.mihomo

import dev.viasix.core.formatting.ByteRateFormatter
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.util.concurrent.TimeUnit

data class ControllerHealth(
    val ok: Boolean,
    val message: String,
    val version: String? = null,
)

data class TrafficTotals(
    val live: Boolean,
    val message: String,
    val uploadTotal: Long = 0,
    val downloadTotal: Long = 0,
    val connectionCount: Int = 0,
)

/** Full UI snapshot: rates (derived), totals, optional memory. */
data class TrafficSnapshot(
    val live: Boolean = false,
    val upBps: Long = 0,
    val downBps: Long = 0,
    val uploadTotal: Long = 0,
    val downloadTotal: Long = 0,
    val memoryInUse: Long = 0,
    val connectionCount: Int = 0,
    val message: String = "—",
    val history: List<SpeedPoint> = emptyList(),
) {
    companion object {
        val Idle = TrafficSnapshot()
    }
}

data class SpeedPoint(
    val upBps: Long,
    val downBps: Long,
    val atMillis: Long = System.currentTimeMillis(),
)

data class ProxyDelayResult(
    val ok: Boolean,
    val delayMs: Int? = null,
    val message: String,
)

/**
 * Mihomo external-controller HTTP client: health, traffic totals/rates, memory,
 * mode patch, and proxy delay tests.
 */
object ControllerClient {
    fun probe(host: String, port: Int, secret: String, timeoutMs: Int = 3000): ControllerHealth {
        return try {
            val conn = open("http://$host:$port/version", secret, timeoutMs)
            val code = conn.responseCode
            val body = readBody(conn)
            if (code !in 200..299) {
                ControllerHealth(false, "HTTP $code")
            } else {
                val version =
                    runCatching { JSONObject(body).optString("version").ifBlank { null } }
                        .getOrNull()
                ControllerHealth(
                    ok = true,
                    message = version?.let { "controller ok (version $it)" } ?: "controller ok",
                    version = version,
                )
            }
        } catch (error: Exception) {
            ControllerHealth(false, "unreachable: ${error.message}")
        }
    }

    fun connectionsTotals(
        host: String,
        port: Int,
        secret: String,
        timeoutMs: Int = 3000,
    ): TrafficTotals {
        return try {
            val conn = open("http://$host:$port/connections", secret, timeoutMs)
            val code = conn.responseCode
            val body = readBody(conn)
            if (code !in 200..299) {
                return TrafficTotals(false, "HTTP $code")
            }
            val json = JSONObject(body)
            val up = json.optLong("uploadTotal", 0)
            val down = json.optLong("downloadTotal", 0)
            val count =
                when {
                    json.has("connections") -> json.optJSONArray("connections")?.length() ?: 0
                    else -> 0
                }
            TrafficTotals(
                live = true,
                message =
                    "Σ ↑ ${ByteRateFormatter.formatBytes(up)}  ↓ ${ByteRateFormatter.formatBytes(down)}",
                uploadTotal = up,
                downloadTotal = down,
                connectionCount = count,
            )
        } catch (error: Exception) {
            TrafficTotals(false, "traffic unavailable: ${error.message}")
        }
    }

    /** Best-effort HTTP GET /memory (some builds expose it without WebSocket). */
    fun memoryInUse(host: String, port: Int, secret: String, timeoutMs: Int = 2000): Long {
        return try {
            val conn = open("http://$host:$port/memory", secret, timeoutMs)
            if (conn.responseCode !in 200..299) return 0
            val json = JSONObject(readBody(conn))
            when {
                json.has("inuse") -> json.optLong("inuse", 0)
                json.has("inUse") -> json.optLong("inUse", 0)
                else -> 0
            }
        } catch (_: Exception) {
            0
        }
    }

    fun patchMode(
        host: String,
        port: Int,
        secret: String,
        mode: String,
        timeoutMs: Int = 3000,
    ): Boolean {
        return try {
            val conn = open("http://$host:$port/configs", secret, timeoutMs, method = "PATCH")
            conn.doOutput = true
            conn.setRequestProperty("Content-Type", "application/json")
            conn.outputStream.use { out ->
                out.write("""{"mode":"$mode"}""".toByteArray(StandardCharsets.UTF_8))
            }
            conn.responseCode in 200..299
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Proxy delay against a URL (Clash/Mihomo `/proxies/{name}/delay`).
     */
    fun proxyDelay(
        host: String,
        port: Int,
        secret: String,
        proxyName: String,
        testUrl: String = "https://www.gstatic.com/generate_204",
        timeoutMs: Int = 5000,
    ): ProxyDelayResult {
        return try {
            val encoded =
                URLEncoder.encode(proxyName, StandardCharsets.UTF_8.name())
                    .replace("+", "%20")
            val urlEncoded =
                URLEncoder.encode(testUrl, StandardCharsets.UTF_8.name())
            val path =
                "http://$host:$port/proxies/$encoded/delay?url=$urlEncoded&timeout=$timeoutMs"
            val conn = open(path, secret, timeoutMs + 1000)
            val code = conn.responseCode
            val body = readBody(conn)
            if (code !in 200..299) {
                return ProxyDelayResult(false, message = "HTTP $code")
            }
            val delay = JSONObject(body).optInt("delay", -1)
            if (delay < 0) {
                ProxyDelayResult(false, message = "no delay field")
            } else {
                ProxyDelayResult(true, delayMs = delay, message = "${delay} ms")
            }
        } catch (error: Exception) {
            ProxyDelayResult(false, message = error.message ?: "delay failed")
        }
    }

    fun open(
        url: String,
        secret: String,
        timeoutMs: Int,
        method: String = "GET",
    ): HttpURLConnection {
        val conn = (URL(url).openConnection() as HttpURLConnection)
        conn.connectTimeout = timeoutMs
        conn.readTimeout = timeoutMs
        conn.requestMethod = method
        if (secret.isNotBlank()) {
            conn.setRequestProperty("Authorization", "Bearer $secret")
        }
        return conn
    }

    fun readBody(conn: HttpURLConnection): String {
        val stream =
            try {
                conn.inputStream
            } catch (_: Exception) {
                conn.errorStream
            } ?: return ""
        return stream.bufferedReader().use { it.readText() }
    }

    @Deprecated("Use ByteRateFormatter", ReplaceWith("ByteRateFormatter.formatBytes(bytes)"))
    fun formatBytes(bytes: Long): String = ByteRateFormatter.formatBytes(bytes)

    fun sleepQuietly(ms: Long) {
        try {
            TimeUnit.MILLISECONDS.sleep(ms)
        } catch (_: InterruptedException) {
        }
    }
}

/**
 * Derives instantaneous rates from successive `/connections` totals
 * (same approach as the Windows traffic sampler).
 */
class TrafficSampler(
    private val maxHistory: Int = 120,
) {
    private var lastUpload: Long? = null
    private var lastDownload: Long? = null
    private var lastAtMillis: Long? = null
    private val points = ArrayDeque<SpeedPoint>()

    fun reset() {
        lastUpload = null
        lastDownload = null
        lastAtMillis = null
        points.clear()
    }

    fun sample(host: String, port: Int, secret: String): TrafficSnapshot {
        val totals = ControllerClient.connectionsTotals(host, port, secret)
        if (!totals.live) {
            return TrafficSnapshot(
                live = false,
                upBps = 0,
                downBps = 0,
                uploadTotal = lastUpload ?: 0,
                downloadTotal = lastDownload ?: 0,
                memoryInUse = 0,
                connectionCount = 0,
                message = totals.message,
                history = points.toList(),
            )
        }

        val now = System.currentTimeMillis()
        val (upBps, downBps) =
            when {
                lastUpload != null && lastDownload != null && lastAtMillis != null -> {
                    val secs = ((now - lastAtMillis!!) / 1000.0).coerceAtLeast(0.001)
                    val up = ((totals.uploadTotal - lastUpload!!).coerceAtLeast(0) / secs).toLong()
                    val down =
                        ((totals.downloadTotal - lastDownload!!).coerceAtLeast(0) / secs).toLong()
                    up to down
                }
                else -> 0L to 0L
            }
        lastUpload = totals.uploadTotal
        lastDownload = totals.downloadTotal
        lastAtMillis = now

        points.addLast(SpeedPoint(upBps, downBps, now))
        while (points.size > maxHistory) points.removeFirst()

        val memory = ControllerClient.memoryInUse(host, port, secret)
        return TrafficSnapshot(
            live = true,
            upBps = upBps,
            downBps = downBps,
            uploadTotal = totals.uploadTotal,
            downloadTotal = totals.downloadTotal,
            memoryInUse = memory,
            connectionCount = totals.connectionCount,
            message =
                "↑ ${ByteRateFormatter.formatRate(upBps)}  ↓ ${ByteRateFormatter.formatRate(downBps)}" +
                    "  ·  Σ ↑ ${ByteRateFormatter.formatBytes(totals.uploadTotal)}" +
                    "  ↓ ${ByteRateFormatter.formatBytes(totals.downloadTotal)}",
            history = points.toList(),
        )
    }
}
