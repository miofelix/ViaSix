package dev.viasix.app.session

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class VpnMeteredSurfaceTest {
    @Test
    fun meteredChoiceFlowsThroughPrefsCommandsRestoreBuilderAndSettings() {
        val prefs =
            resolve(
                "src/main/java/dev/viasix/app/prefs/SessionPrefs.kt",
                "app/src/main/java/dev/viasix/app/prefs/SessionPrefs.kt",
            ).readText()
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

        assertTrue(prefs.contains(".put(\"vpnMetered\", vpnMetered)"))
        assertTrue(prefs.contains("o.optBoolean(\"vpnMetered\", true)"))
        assertTrue(commands.contains("EXTRA_VPN_METERED"))
        assertTrue(commands.contains("prefs.vpnMetered"))
        assertTrue(service.contains("restoredPrefs?.vpnMetered"))
        assertTrue(service.contains("Build.VERSION_CODES.Q"))
        assertTrue(service.contains("builder.setMetered(vpnMetered)"))
        assertTrue(settings.contains("按流量计费 VPN"))
        assertTrue(settings.contains("onVpnMeteredChange"))
        assertTrue(settings.contains("不会改变蜂窝网络套餐或实际资费"))
    }

    private fun resolve(vararg paths: String): File =
        paths.map { File(it) }.firstOrNull { it.isFile }
            ?: error("file not found from cwd=${File(".").absolutePath}: ${paths.toList()}")
}
