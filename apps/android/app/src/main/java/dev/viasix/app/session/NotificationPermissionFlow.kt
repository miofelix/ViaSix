package dev.viasix.app.session

const val POST_NOTIFICATIONS_PERMISSION = "android.permission.POST_NOTIFICATIONS"

/** UI/runtime snapshot for Android 13+ notification permission. */
data class NotificationPermissionState(
    val required: Boolean = false,
    val granted: Boolean = true,
    val wasRequested: Boolean = false,
    val shouldShowRationale: Boolean = false,
) {
    val canRequestInApp: Boolean
        get() = required && !granted && (!wasRequested || shouldShowRationale)

    val statusLabel: String
        get() =
            when {
                !required -> "系统自动允许"
                granted -> "已允许"
                wasRequested -> "已关闭"
                else -> "尚未询问"
            }
}

/**
 * Prevents repeated permission prompts: connect asks once, later denial is a
 * non-blocking degraded mode that can be repaired from Settings.
 */
object NotificationPermissionFlow {
    enum class BeforeStart {
        REQUEST_PERMISSION,
        CONTINUE,
    }

    fun beforeStart(state: NotificationPermissionState): BeforeStart =
        if (state.required && !state.granted && !state.wasRequested) {
            BeforeStart.REQUEST_PERMISSION
        } else {
            BeforeStart.CONTINUE
        }
}
