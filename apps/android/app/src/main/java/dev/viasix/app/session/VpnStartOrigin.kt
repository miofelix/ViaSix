package dev.viasix.app.session

enum class VpnStartOrigin(
    val reason: String,
    val restoreSavedSession: Boolean,
) {
    APP("start", false),
    STICKY_RESTART("system-restart", true),
    SYSTEM("system-start", true),
    ;

    companion object {
        const val ACTION_START = "dev.viasix.app.vpn.START"

        fun detect(
            intentPresent: Boolean,
            action: String?,
        ): VpnStartOrigin =
            when {
                action == ACTION_START -> APP
                intentPresent -> SYSTEM
                else -> STICKY_RESTART
            }
    }
}
