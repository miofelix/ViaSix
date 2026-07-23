package dev.viasix.core.speedtest

/**
 * Parses CFST `result.csv` output.
 *
 * Expected header (v2.x):
 * `IP,Sent,Received,Loss,Latency,Speed,Region`
 *
 * Tolerates UTF-8 BOM, blank lines, and trailing columns. Rows with fewer than
 * 6 columns or an empty IP are skipped (same contract as macOS SpeedTestResultParser).
 */
object SpeedTestResultParser {
    fun parse(csv: String): List<SpeedTestResult> {
        val lines =
            csv
                .removePrefix("\uFEFF")
                .lineSequence()
                .map { it.trimEnd('\r') }
                .filter { it.isNotBlank() }
                .toList()
        if (lines.size <= 1) return emptyList()

        return lines
            .drop(1)
            .mapNotNull { line -> parseRow(line) }
    }

    private fun parseRow(line: String): SpeedTestResult? {
        val cols = splitCsvLine(line)
        if (cols.size < 6) return null
        val ip = cols[0].trim()
        if (ip.isEmpty()) return null
        return SpeedTestResult(
            ip = ip,
            sent = cols[1].trim(),
            received = cols[2].trim(),
            loss = cols[3].trim(),
            latency = cols[4].trim(),
            speed = cols[5].trim(),
            region = cols.getOrElse(6) { "" }.trim(),
        )
    }

    /**
     * Minimal CSV split: handles quoted fields with commas; CFST rows are
     * typically unquoted but real samples occasionally quote the IP.
     */
    internal fun splitCsvLine(line: String): List<String> {
        val out = mutableListOf<String>()
        val current = StringBuilder()
        var inQuotes = false
        var i = 0
        while (i < line.length) {
            val c = line[i]
            when {
                c == '"' -> {
                    if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
                        current.append('"')
                        i++
                    } else {
                        inQuotes = !inQuotes
                    }
                }
                c == ',' && !inQuotes -> {
                    out += current.toString()
                    current.clear()
                }
                else -> current.append(c)
            }
            i++
        }
        out += current.toString()
        return out
    }
}
