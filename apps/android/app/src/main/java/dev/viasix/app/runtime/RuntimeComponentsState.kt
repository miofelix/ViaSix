package dev.viasix.app.runtime

enum class RuntimeComponentId(val label: String) {
    MIHOMO("mihomo 内核"),
    CFST("CFST 测速"),
}

enum class RuntimeComponentCondition(val label: String) {
    UNKNOWN("尚未检查"),
    CHECKING("检查中"),
    READY("已就绪"),
    MISSING("未安装"),
    INVALID("需要修复"),
    UNSUPPORTED("设备不支持"),
    ERROR("检查失败"),
}

data class RuntimeComponentInfo(
    val condition: RuntimeComponentCondition = RuntimeComponentCondition.UNKNOWN,
    val detail: String = "尚未检查本地组件",
    val path: String? = null,
    val sizeBytes: Long? = null,
) {
    val ready: Boolean
        get() = condition == RuntimeComponentCondition.READY

    val needsRepair: Boolean
        get() =
            condition == RuntimeComponentCondition.MISSING ||
                condition == RuntimeComponentCondition.INVALID ||
                condition == RuntimeComponentCondition.ERROR
}

data class RuntimeComponentsState(
    val mihomo: RuntimeComponentInfo = RuntimeComponentInfo(),
    val cfst: RuntimeComponentInfo = RuntimeComponentInfo(),
    val isInspecting: Boolean = false,
    val repairing: RuntimeComponentId? = null,
) {
    val busy: Boolean
        get() = isInspecting || repairing != null

    fun info(component: RuntimeComponentId): RuntimeComponentInfo =
        when (component) {
            RuntimeComponentId.MIHOMO -> mihomo
            RuntimeComponentId.CFST -> cfst
        }

    fun withInfo(
        component: RuntimeComponentId,
        info: RuntimeComponentInfo,
    ): RuntimeComponentsState =
        when (component) {
            RuntimeComponentId.MIHOMO -> copy(mihomo = info)
            RuntimeComponentId.CFST -> copy(cfst = info)
        }
}
