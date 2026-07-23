package dev.viasix.core.speedtest

/**
 * One CFST result row. Field names and order match macOS [SpeedTestResult]
 * (CFST CSV: IP, Sent, Received, Loss, Latency, Speed, Region).
 */
data class SpeedTestResult(
    val ip: String,
    val sent: String = "",
    val received: String = "",
    val loss: String = "",
    val latency: String = "",
    val speed: String = "",
    val region: String = "",
) {
    val latencyValue: Double?
        get() = latency.trim().toDoubleOrNull()

    val speedValue: Double?
        get() = speed.trim().toDoubleOrNull()

    val lossValue: Double?
        get() = loss.trim().toDoubleOrNull()
}
