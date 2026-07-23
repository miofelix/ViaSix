package dev.viasix.app.session

import android.content.Context
import dev.viasix.app.mihomo.TrafficSnapshot
import dev.viasix.app.state.RuntimeSnapshot
import dev.viasix.app.vpn.ViaSixVpnService

/** Last runtime state published by [ViaSixVpnService], available across UI process recreation. */
data class SessionRuntimeStatus(
    val running: Boolean = false,
    val health: String = "—",
    val controllerPort: Int = ViaSixVpnService.CONTROLLER_PORT,
    val mixedPort: Int = ViaSixVpnService.MIXED_PORT,
    val secret: String = "",
    val mihomoVersion: String? = null,
    val startedAtMillis: Long? = null,
    val eventsJson: String = "[]",
) {
    fun toUiSnapshot(traffic: TrafficSnapshot = TrafficSnapshot.Idle): RuntimeSnapshot =
        RuntimeSnapshot(
            running = running,
            health = health,
            traffic = traffic,
            controllerPort = controllerPort,
            mixedPort = mixedPort,
            mihomoVersion = mihomoVersion,
            secretPresent = secret.isNotBlank(),
            startedAtMillis = startedAtMillis,
        )
}

class SessionRuntimeStore(context: Context) {
    private val prefs =
        context.getSharedPreferences(ViaSixVpnService.RUNTIME_PREFS, Context.MODE_PRIVATE)

    fun load(): SessionRuntimeStatus =
        SessionRuntimeStatus(
            running = prefs.getBoolean(ViaSixVpnService.KEY_RUNNING, false),
            health = prefs.getString(ViaSixVpnService.KEY_HEALTH, "—") ?: "—",
            controllerPort =
                prefs.getInt(
                    ViaSixVpnService.KEY_CONTROLLER_PORT,
                    ViaSixVpnService.CONTROLLER_PORT,
                ),
            mixedPort =
                prefs.getInt(
                    ViaSixVpnService.KEY_MIXED_PORT,
                    ViaSixVpnService.MIXED_PORT,
                ),
            secret = prefs.getString(ViaSixVpnService.KEY_SECRET, "") ?: "",
            mihomoVersion =
                prefs.getString(ViaSixVpnService.KEY_VERSION, "")
                    ?.ifBlank { null },
            startedAtMillis =
                prefs.getLong(ViaSixVpnService.KEY_STARTED_AT, 0L)
                    .takeIf { it > 0L },
            eventsJson = prefs.getString(ViaSixVpnService.KEY_EVENTS, "[]") ?: "[]",
        )
}
