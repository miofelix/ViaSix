package dev.viasix.app.session

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class NotificationPermissionSurfaceTest {
    @Test
    fun activityManifestAndSettingsExposePermissionFlow() {
        val activity =
            resolve(
                "src/main/java/dev/viasix/app/MainActivity.kt",
                "app/src/main/java/dev/viasix/app/MainActivity.kt",
            ).readText()
        val settings =
            resolve(
                "src/main/java/dev/viasix/app/ui/screens/SettingsScreen.kt",
                "app/src/main/java/dev/viasix/app/ui/screens/SettingsScreen.kt",
            ).readText()
        val flow =
            resolve(
                "src/main/java/dev/viasix/app/session/NotificationPermissionFlow.kt",
                "app/src/main/java/dev/viasix/app/session/NotificationPermissionFlow.kt",
            ).readText()
        val manifest =
            resolve(
                "src/main/AndroidManifest.xml",
                "app/src/main/AndroidManifest.xml",
            ).readText()

        assertTrue(manifest.contains("android.permission.POST_NOTIFICATIONS"))
        assertTrue(flow.contains("POST_NOTIFICATIONS_PERMISSION"))
        assertTrue(activity.contains("ActivityResultContracts.RequestPermission"))
        assertTrue(activity.contains("NotificationPermissionFlow.beforeStart"))
        assertTrue(activity.contains("Settings.ACTION_APP_NOTIFICATION_SETTINGS"))
        assertTrue(settings.contains("会话通知"))
        assertTrue(settings.contains("onManageNotificationPermission"))
    }

    private fun resolve(vararg paths: String): File =
        paths.map { File(it) }.firstOrNull { it.isFile }
            ?: error("file not found from cwd=${File(".").absolutePath}: ${paths.toList()}")
}
