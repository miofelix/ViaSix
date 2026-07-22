package dev.viasix.core.formatting

/**
 * Formats byte counts and rates for traffic UI, aligned with Clash Verge /
 * macOS [ByteRateFormatter] conventions.
 */
object ByteRateFormatter {
    private val units = arrayOf("B", "KB", "MB", "GB", "TB", "PB")
    private val shortUnits = arrayOf("B", "K", "M", "G", "T", "P")
    private const val displayThreshold = 1_000.0

    fun formatBytes(bytes: Long): String {
        val (value, unit) = parse(bytes.toDouble().coerceAtLeast(0.0), units, suffix = "")
        return "$value $unit"
    }

    fun formatRate(bytesPerSecond: Long): String {
        val (value, unit) =
            parse(bytesPerSecond.toDouble().coerceAtLeast(0.0), units, suffix = "/s")
        return "$value $unit"
    }

    fun formatCompactRate(bytesPerSecond: Long): String {
        val (value, unit) =
            parse(
                bytesPerSecond.toDouble().coerceAtLeast(0.0),
                shortUnits,
                suffix = "/s",
                compact = true,
            )
        return "$value$unit"
    }

    private fun parse(
        amount: Double,
        unitLabels: Array<String>,
        suffix: String,
        compact: Boolean = false,
    ): Pair<String, String> {
        if (!amount.isFinite() || amount < 0) {
            return "0" to (unitLabels[0] + suffix)
        }
        if (amount < displayThreshold) {
            return amount.toLong().toString() to (unitLabels[0] + suffix)
        }

        var unitIndex =
            minOf(
                (kotlin.math.ln(amount.coerceAtLeast(1.0)) / kotlin.math.ln(1024.0)).toInt(),
                unitLabels.lastIndex,
            )
        var scaled = amount / Math.pow(1024.0, unitIndex.toDouble())
        if (roundToDisplay(scaled) >= displayThreshold && unitIndex < unitLabels.lastIndex) {
            unitIndex += 1
            scaled = amount / Math.pow(1024.0, unitIndex.toDouble())
        }

        val value =
            when {
                compact && scaled < 9.95 -> String.format("%.1f", scaled)
                compact -> String.format("%.0f", scaled)
                scaled >= 100 -> String.format("%.0f", scaled)
                scaled >= 10 -> String.format("%.1f", scaled)
                else -> String.format("%.2f", scaled)
            }
        return value to (unitLabels[unitIndex] + suffix)
    }

    private fun roundToDisplay(value: Double): Double = kotlin.math.round(value * 10.0) / 10.0
}
