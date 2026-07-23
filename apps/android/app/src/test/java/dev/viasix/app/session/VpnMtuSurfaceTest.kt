package dev.viasix.app.session

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class VpnMtuSurfaceTest {
    @Test
    fun mtuFlowsThroughSettingsCommandsRestoreAndBuilder() {
        val commands =
            resolve(
                "src/main/java/dev/viasix/app/session/VpnSessionCommands.kt",
                "app/src/main/java/dev/viasix/app/session/VpnSessionCommands.kt",
            ).readText()
        val service =
            resolve(
                "src/main/java/dev/viasix/app/vpn/ViaSixVpnService.kt",
                "app/src/main/java/dev/viasix/app/vpn/ViaSixVpnService.kt",
            ).readText()
        val settings =
            resolve(
                "src/main/java/dev/viasix/app/ui/screens/SettingsScreen.kt",
                "app/src/main/java/dev/viasix/app/ui/screens/SettingsScreen.kt",
            ).readText()
        val prefs =
            resolve(
                "src/main/java/dev/viasix/app/prefs/SessionPrefs.kt",
                "app/src/main/java/dev/viasix/app/prefs/SessionPrefs.kt",
            ).readText()
        val overview =
            resolve(
                "src/main/java/dev/viasix/app/ui/screens/OverviewScreen.kt",
                "app/src/main/java/dev/viasix/app/ui/screens/OverviewScreen.kt",
            ).readText()

        assertTrue(commands.contains("EXTRA_VPN_MTU"))
        assertTrue(commands.contains("prefs.vpnMtu"))
        assertTrue(prefs.contains(".put(\"vpnMtu\", vpnMtu)"))
        assertTrue(prefs.contains("o.optString(\"vpnMtu\", \"1500\")"))
        assertTrue(service.contains("restoredPrefs?.vpnMtu"))
        assertTrue(service.contains(".setMtu(vpnMtu)"))
        assertFalse(service.contains(".setMtu(1500)"))
        assertTrue(settings.contains("VPN MTU"))
        assertTrue(settings.contains("VpnMtuPolicy.isValid"))
        assertTrue(overview.contains("MTU ${'$'}{state.vpnMtu}"))
    }

    private fun resolve(vararg paths: String): File =
        paths.map { File(it) }.firstOrNull { it.isFile }
            ?: error("file not found from cwd=${File(".").absolutePath}: ${paths.toList()}")
}
