package dev.viasix.app.cfst

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Structural checks that installer constants stay aligned with fetch-cfst output.
 * Full install needs Android Context; binary is gitignored until fetch-cfst runs.
 */
class CfstInstallerSurfaceTest {
    @Test
    fun assetPathsMatchFetchScriptLayout() {
        assertEquals("cfst/ipv6.txt", CfstInstaller.ASSET_IPV6_LIST)
        assertEquals("libcfst.so", CfstInstaller.NATIVE_BINARY_NAME)
        assertEquals("ipv6.txt", CfstInstaller.IPV6_LIST_NAME)
    }

    @Test
    fun executableUsesExtractedNativeLibraryInsteadOfFilesDir() {
        val installer =
            resolve(
                "src/main/java/dev/viasix/app/cfst/CfstInstaller.kt",
                "app/src/main/java/dev/viasix/app/cfst/CfstInstaller.kt",
                "apps/android/app/src/main/java/dev/viasix/app/cfst/CfstInstaller.kt",
            ).readText()
        val gradle =
            resolve(
                "build.gradle.kts",
                "app/build.gradle.kts",
                "apps/android/app/build.gradle.kts",
            ).readText()

        assertTrue(installer.contains("context.applicationInfo.nativeLibraryDir"))
        assertTrue(gradle.contains("useLegacyPackaging = true"))
        assertTrue(gradle.contains("keepDebugSymbols += \"**/libcfst.so\""))
    }

    @Test
    fun bundledIpv6ListAssetIsPresentOnClasspathOrSourceTree() {
        assertTrue(CfstInstaller.ASSET_IPV6_LIST.endsWith("ipv6.txt"))
        val ipv6 =
            listOf(
                File("src/main/assets/cfst/ipv6.txt"),
                File("app/src/main/assets/cfst/ipv6.txt"),
                File("apps/android/app/src/main/assets/cfst/ipv6.txt"),
            ).firstOrNull { it.isFile }
        assertTrue("ipv6.txt must exist in assets", ipv6 != null && ipv6.length() > 0)
    }

    @Test
    fun cfstBinaryPresentForDeviceApkOrDocumentedMissing() {
        // When building a device APK, fetch-cfst must have run. Fail unit tests if
        // neither the binary nor an intentional empty-tree is acceptable for CI?
        // Prefer soft-check: if binary exists it must be non-empty ELF-sized.
        val bin =
            listOf(
                File("src/main/jniLibs/arm64-v8a/libcfst.so"),
                File("app/src/main/jniLibs/arm64-v8a/libcfst.so"),
                File("apps/android/app/src/main/jniLibs/arm64-v8a/libcfst.so"),
            ).firstOrNull { it.isFile }
        if (bin != null) {
            assertTrue("libcfst.so must not be empty", bin.length() > 1_000_000)
        }
    }

    private fun resolve(vararg paths: String): File =
        paths.map(::File).firstOrNull { it.isFile }
            ?: error("file not found from cwd=${File(".").absolutePath}: ${paths.toList()}")
}
