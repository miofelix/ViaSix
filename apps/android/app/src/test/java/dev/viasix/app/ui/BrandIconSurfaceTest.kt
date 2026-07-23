package dev.viasix.app.ui

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class BrandIconSurfaceTest {
    @Test
    fun launcherTileAndNotificationUseViaSixAssets() {
        val manifest = resolve("src/main/AndroidManifest.xml", "app/src/main/AndroidManifest.xml")
        val vpn =
            resolve(
                "src/main/java/dev/viasix/app/vpn/ViaSixVpnService.kt",
                "app/src/main/java/dev/viasix/app/vpn/ViaSixVpnService.kt",
            )
        val launcher =
            resolve(
                "src/main/res/mipmap-anydpi-v26/ic_launcher.xml",
                "app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml",
            )
        val foreground =
            resolve(
                "src/main/res/drawable/ic_viasix_foreground.xml",
                "app/src/main/res/drawable/ic_viasix_foreground.xml",
            )

        val manifestText = manifest.readText()
        assertTrue(manifestText.contains("@mipmap/ic_launcher"))
        assertTrue(manifestText.contains("@mipmap/ic_launcher_round"))
        assertTrue(manifestText.contains("@drawable/ic_viasix_tile"))
        assertFalse(manifestText.contains("sym_def_app_icon"))
        assertFalse(manifestText.contains("ic_lock_lock"))
        assertTrue(vpn.readText().contains("R.drawable.ic_viasix_notification"))
        assertTrue(launcher.readText().contains("<monochrome"))
        assertTrue(foreground.readText().contains("apps/macos/Packaging/AppIcon.svg"))
    }

    private fun resolve(vararg paths: String): File =
        paths.map { File(it) }.firstOrNull { it.isFile }
            ?: error("file not found from cwd=${File(".").absolutePath}: ${paths.toList()}")
}
