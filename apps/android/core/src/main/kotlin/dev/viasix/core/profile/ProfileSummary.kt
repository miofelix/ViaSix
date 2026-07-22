package dev.viasix.core.profile

import org.yaml.snakeyaml.Yaml

data class ProxyEntrySummary(
    val name: String,
    val type: String,
    val server: String?,
    val port: Int?,
)

data class ProfileSummary(
    val proxyCount: Int,
    val primary: ProxyEntrySummary?,
    val hasXViasix: Boolean,
    val primaryServerMarker: String?,
    val warnings: List<String> = emptyList(),
) {
    val isManaged: Boolean
        get() = hasXViasix && primary != null

    val statusLabel: String
        get() =
            when {
                primary == null -> "无代理入口"
                !hasXViasix -> "未声明 x-viasix"
                primaryServerMarker == "selected-ip" -> "IPv6 托管入口"
                else -> "已配置"
            }
}

object ProfileSummaryParser {
    @Suppress("UNCHECKED_CAST")
    fun parse(yamlText: String?): ProfileSummary {
        val text = yamlText?.trim().orEmpty()
        if (text.isEmpty()) {
            return ProfileSummary(
                proxyCount = 0,
                primary = null,
                hasXViasix = false,
                primaryServerMarker = null,
                warnings = listOf("配置为空"),
            )
        }

        val root: Map<String, Any?> =
            try {
                when (val loaded = Yaml().load<Any?>(text)) {
                    null -> emptyMap()
                    is Map<*, *> -> loaded as Map<String, Any?>
                    else ->
                        return ProfileSummary(
                            proxyCount = 0,
                            primary = null,
                            hasXViasix = false,
                            primaryServerMarker = null,
                            warnings = listOf("顶层必须是 YAML mapping"),
                        )
                }
            } catch (error: Exception) {
                return ProfileSummary(
                    proxyCount = 0,
                    primary = null,
                    hasXViasix = false,
                    primaryServerMarker = null,
                    warnings = listOf("YAML 解析失败：${error.message}"),
                )
            }

        val proxies =
            (root["proxies"] as? List<*>)
                ?.mapNotNull { it as? Map<*, *> }
                .orEmpty()
        val entries =
            proxies.mapNotNull { proxy ->
                val name = proxy["name"]?.toString()?.trim().orEmpty()
                val type = proxy["type"]?.toString()?.trim().orEmpty()
                if (name.isEmpty() || type.isEmpty()) return@mapNotNull null
                val port =
                    when (val p = proxy["port"]) {
                        is Number -> p.toInt()
                        is String -> p.toIntOrNull()
                        else -> null
                    }
                ProxyEntrySummary(
                    name = name,
                    type = type,
                    server = proxy["server"]?.toString()?.trim()?.ifEmpty { null },
                    port = port,
                )
            }

        val xViasix = root["x-viasix"] as? Map<*, *>
        val marker = xViasix?.get("primary-server")?.toString()?.trim()
        val primary =
            entries.firstOrNull { it.type.lowercase() !in setOf("direct", "reject", "dns") }
                ?: entries.firstOrNull()

        val warnings = mutableListOf<String>()
        if (entries.isEmpty()) warnings += "未找到 proxies"
        if (xViasix == null) warnings += "缺少 x-viasix 段"
        if (marker != null && marker != "selected-ip") {
            warnings += "primary-server 不是 selected-ip（当前：$marker）"
        }

        return ProfileSummary(
            proxyCount = entries.size,
            primary = primary,
            hasXViasix = xViasix != null,
            primaryServerMarker = marker,
            warnings = warnings,
        )
    }
}
