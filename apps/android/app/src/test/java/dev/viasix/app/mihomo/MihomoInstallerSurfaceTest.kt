package dev.viasix.app.mihomo

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Structural checks that installer constants stay aligned with fetch-mihomo output.
 * Full install needs Android Context; binary is gitignored until fetch-mihomo runs.
 */
class MihomoInstallerSurfaceTest {
    @Test
    fun nativeBinaryNameMatchesFetchScriptLayout() {
        assertEquals("libmihomo.so", MihomoInstaller.NATIVE_BINARY_NAME)
    }

    @Test
    fun executableUsesExtractedNativeLibraryInsteadOfFilesDir() {
        val installer =
            resolve(
                "src/main/java/dev/viasix/app/mihomo/MihomoInstaller.kt",
                "app/src/main/java/dev/viasix/app/mihomo/MihomoInstaller.kt",
                "apps/android/app/src/main/java/dev/viasix/app/mihomo/MihomoInstaller.kt",
            ).readText()
        val gradle =
            resolve(
                "build.gradle.kts",
                "app/build.gradle.kts",
                "apps/android/app/build.gradle.kts",
            ).readText()
        val fetch =
            resolve(
                "scripts/fetch-mihomo.mjs",
                "../scripts/fetch-mihomo.mjs",
                "apps/android/scripts/fetch-mihomo.mjs",
            ).readText()

        assertTrue(installer.contains("context.applicationInfo.nativeLibraryDir"))
        assertTrue(installer.contains("libmihomo.so"))
        assertTrue(!installer.contains("installAssetBinary"))
        assertTrue(gradle.contains("useLegacyPackaging = true"))
        assertTrue(gradle.contains("keepDebugSymbols += \"**/libmihomo.so\""))
        assertTrue(fetch.contains("libmihomo.so"))
        assertTrue(fetch.contains("jniLibs/arm64-v8a"))
    }

    @Test
    fun mihomoBinaryPresentForDeviceApkOrDocumentedMissing() {
        val bin =
            listOf(
                File("src/main/jniLibs/arm64-v8a/libmihomo.so"),
                File("app/src/main/jniLibs/arm64-v8a/libmihomo.so"),
                File("apps/android/app/src/main/jniLibs/arm64-v8a/libmihomo.so"),
            ).firstOrNull { it.isFile }
        if (bin != null) {
            assertTrue("libmihomo.so must not be empty", bin.length() > 1_000_000)
        }
    }

    private fun resolve(vararg paths: String): File =
        paths.map(::File).firstOrNull { it.isFile }
            ?: error("file not found from cwd=${File(".").absolutePath}: ${paths.toList()}")
}
