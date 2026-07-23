package dev.viasix.app.ui

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class AppThemeSurfaceTest {
    @Test
    fun api26SafeLightAndDarkThemesArePresent() {
        val manifest = resolve("src/main/AndroidManifest.xml", "app/src/main/AndroidManifest.xml")
        val light = resolve("src/main/res/values/themes.xml", "app/src/main/res/values/themes.xml")
        val dark =
            resolve(
                "src/main/res/values-night/themes.xml",
                "app/src/main/res/values-night/themes.xml",
            )
        val lightV27 =
            resolve(
                "src/main/res/values-v27/themes.xml",
                "app/src/main/res/values-v27/themes.xml",
            )
        val darkV27 =
            resolve(
                "src/main/res/values-night-v27/themes.xml",
                "app/src/main/res/values-night-v27/themes.xml",
            )

        assertTrue(manifest.readText().contains("@style/Theme.ViaSix"))
        assertFalse(manifest.readText().contains("Theme.DeviceDefault.DayNight"))
        assertTrue(light.readText().contains("Theme.Material.Light.NoActionBar"))
        assertTrue(dark.readText().contains("Theme.Material.NoActionBar"))
        assertFalse(light.readText().contains("windowLightNavigationBar"))
        assertFalse(dark.readText().contains("windowLightNavigationBar"))
        assertTrue(lightV27.readText().contains("windowLightNavigationBar\">true"))
        assertTrue(darkV27.readText().contains("windowLightNavigationBar\">false"))
    }

    private fun resolve(vararg paths: String): File =
        paths.map { File(it) }.firstOrNull { it.isFile }
            ?: error("file not found from cwd=${File(".").absolutePath}: ${paths.toList()}")
}
