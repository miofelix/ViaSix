package dev.viasix.app.cfst

import android.content.Context
import android.os.Build
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

/**
 * Installs the bundled CFST binary and default IPv6 list from assets into the
 * app private files directory (same pattern as [dev.viasix.app.mihomo.MihomoInstaller]).
 *
 * Ships arm64 only (`cfst/cfst-arm64` from `scripts/fetch-cfst.mjs`, linux_arm64
 * upstream). Callers should surface a clear error on unsupported ABIs.
 */
object CfstInstaller {
    private const val TAG = "CfstInstaller"
    const val ASSET_BINARY_ARM64 = "cfst/cfst-arm64"
    const val ASSET_IPV6_LIST = "cfst/ipv6.txt"
    const val BINARY_NAME = "cfst"
    const val IPV6_LIST_NAME = "ipv6.txt"

    data class InstallResult(
        val binary: File,
        val ipv6List: File,
        val abiSupported: Boolean,
    )

    fun installIfNeeded(context: Context): InstallResult {
        val destDir = File(context.filesDir, "cfst")
        if (!destDir.exists() && !destDir.mkdirs()) {
            throw IOException("Cannot create cfst dir: ${destDir.absolutePath}")
        }

        val binary = File(destDir, BINARY_NAME)
        val ipv6List = File(destDir, IPV6_LIST_NAME)
        val abiSupported = isArm64()

        val needsBinary =
            !binary.isFile || !binary.canExecute() || binary.length() == 0L
        if (needsBinary) {
            Log.i(TAG, "Installing CFST from assets/$ASSET_BINARY_ARM64 -> ${binary.absolutePath}")
            try {
                context.assets.open(ASSET_BINARY_ARM64).use { input ->
                    FileOutputStream(binary).use { output -> input.copyTo(output) }
                }
            } catch (error: Exception) {
                throw IOException(
                    "CFST asset missing ($ASSET_BINARY_ARM64). Run: node apps/android/scripts/fetch-cfst.mjs",
                    error,
                )
            }
            binary.setReadable(true, false)
            binary.setExecutable(true, false)
            if (!binary.canExecute()) {
                Log.w(TAG, "cfst may not be marked executable")
            }
        }

        val needsList = !ipv6List.isFile || ipv6List.length() == 0L
        if (needsList) {
            Log.i(TAG, "Installing ipv6 list from assets/$ASSET_IPV6_LIST")
            try {
                context.assets.open(ASSET_IPV6_LIST).use { input ->
                    FileOutputStream(ipv6List).use { output -> input.copyTo(output) }
                }
            } catch (error: Exception) {
                throw IOException(
                    "CFST ipv6 list asset missing ($ASSET_IPV6_LIST)",
                    error,
                )
            }
        }

        return InstallResult(
            binary = binary,
            ipv6List = ipv6List,
            abiSupported = abiSupported,
        )
    }

    fun isArm64(): Boolean {
        val abis = Build.SUPPORTED_ABIS
        return abis.any { it.contains("arm64") || it == "aarch64" }
    }

    fun workDir(context: Context): File {
        val dir = File(context.filesDir, "cfst/work")
        if (!dir.exists()) dir.mkdirs()
        return dir
    }
}
