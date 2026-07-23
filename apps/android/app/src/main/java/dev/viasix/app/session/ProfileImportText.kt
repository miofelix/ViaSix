package dev.viasix.app.session

/**
 * Extracts mihomo-compatible profile YAML from free-form clipboard / paste text.
 * Inspired by Clash / NekoBox “paste config” affordances — no network fetch here.
 */
object ProfileImportText {
    /**
     * Returns trimmed YAML if [raw] looks like a proxy profile; otherwise null.
     * Rejects bare http(s) subscription URLs (not fetched in this path).
     */
    fun extractYaml(raw: String?): String? {
        if (raw.isNullOrBlank()) return null
        val text = raw.trim().removePrefix("\uFEFF")
        if (text.isEmpty()) return null

        // Bare URL → not YAML (subscription download is a separate feature).
        if (looksLikeBareUrl(text)) return null

        if (looksLikeProfileYaml(text)) return text
        return null
    }

    fun looksLikeBareUrl(text: String): Boolean {
        val oneLine = !text.contains('\n') && !text.contains('\r')
        if (!oneLine) return false
        val t = text.trim()
        return t.startsWith("http://", ignoreCase = true) ||
            t.startsWith("https://", ignoreCase = true) ||
            t.startsWith("clash://", ignoreCase = true)
    }

    fun looksLikeProfileYaml(text: String): Boolean {
        val lower = text.lowercase()
        // Strong signals used by mihomo / Clash profiles and ViaSix contracts.
        val markers =
            listOf(
                "proxies:",
                "proxy-groups:",
                "proxy-providers:",
                "x-viasix:",
                "mixed-port:",
                "rules:",
            )
        if (markers.any { lower.contains(it) }) return true
        // Minimal YAML: at least one key: value line and some depth.
        val keyLines =
            text.lineSequence().count { line ->
                val t = line.trim()
                t.isNotEmpty() && !t.startsWith("#") && t.contains(':')
            }
        return keyLines >= 3 && text.length >= 40
    }
}
