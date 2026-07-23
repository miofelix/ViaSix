package dev.viasix.app.runtime

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class RuntimeComponentSurfaceTest {
    @Test
    fun installersAndSettingsExposeInspectionAndIndependentRepair() {
        val mihomo =
            resolve(
                "src/main/java/dev/viasix/app/mihomo/MihomoInstaller.kt",
                "app/src/main/java/dev/viasix/app/mihomo/MihomoInstaller.kt",
            ).readText()
        val cfst =
            resolve(
                "src/main/java/dev/viasix/app/cfst/CfstInstaller.kt",
                "app/src/main/java/dev/viasix/app/cfst/CfstInstaller.kt",
            ).readText()
        val settings =
            resolve(
                "src/main/java/dev/viasix/app/ui/screens/SettingsScreen.kt",
                "app/src/main/java/dev/viasix/app/ui/screens/SettingsScreen.kt",
            ).readText()
        val install =
            resolve(
                "src/main/java/dev/viasix/app/runtime/RuntimeBinaryInstall.kt",
                "app/src/main/java/dev/viasix/app/runtime/RuntimeBinaryInstall.kt",
            ).readText()

        assertTrue(mihomo.contains("inspectInstalled"))
        assertTrue(mihomo.contains("fun repair"))
        assertTrue(cfst.contains("inspectInstalled"))
        assertTrue(cfst.contains("fun repair"))
        assertTrue(settings.contains("RuntimeComponentId.MIHOMO"))
        assertTrue(settings.contains("RuntimeComponentId.CFST"))
        assertTrue(settings.contains("错误架构"))
        assertTrue(settings.contains("原子替换"))
        assertTrue(install.contains("StandardCopyOption.ATOMIC_MOVE"))
        assertTrue(install.contains("0b111_000_000"))
    }

    private fun resolve(vararg paths: String): File =
        paths.map { File(it) }.firstOrNull { it.isFile }
            ?: error("file not found from cwd=${File(".").absolutePath}: ${paths.toList()}")
}
