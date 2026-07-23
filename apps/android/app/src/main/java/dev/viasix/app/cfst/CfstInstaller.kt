package dev.viasix.app.cfst

import android.content.Context
import android.os.Build
import android.util.Log
import dev.viasix.app.runtime.RuntimeBinaryInstall
import dev.viasix.app.runtime.RuntimeComponentCondition
import dev.viasix.app.runtime.RuntimeComponentInfo
import java.io.File
import java.io.IOException

/**
 * Resolves the bundled CFST executable from Android's native library directory
 * and installs the default IPv6 list into the app private files directory.
 *
 * Android 10+ denies exec from writable app directories such as filesDir, even
 * when chmod reports an execute bit. Packaging CFST as `libcfst.so` makes the
 * package manager extract it into the read-only, executable nativeLibraryDir.
 * Ships arm64 only (linux_arm64 upstream, statically linked).
 */
object CfstInstaller {
    private const val TAG = "CfstInstaller"
    const val ASSET_IPV6_LIST = "cfst/ipv6.txt"
    const val NATIVE_BINARY_NAME = "libcfst.so"
    const val IPV6_LIST_NAME = "ipv6.txt"

    data class InstallResult(
        val binary: File,
        val ipv6List: File,
    )

    @Synchronized
    fun installIfNeeded(
        context: Context,
        force: Boolean = false,
    ): InstallResult {
        if (!isArm64()) {
            throw IOException("设备 ABI 非 arm64，当前 APK 仅包含 arm64 CFST")
        }
        val binary = packagedBinary(context)
        val inspection = RuntimeBinaryInstall.inspectElfBinary(binary)
        if (!inspection.ready) {
            throw IOException(binaryDetail(inspection))
        }

        val destDir = File(context.filesDir, "cfst")
        if (!destDir.exists() && !destDir.mkdirs()) {
            throw IOException("Cannot create cfst dir: ${destDir.absolutePath}")
        }

        val ipv6List = File(destDir, IPV6_LIST_NAME)
        RuntimeBinaryInstall.installAssetFile(
            context = context,
            assetPath = ASSET_IPV6_LIST,
            dest = ipv6List,
            missingHint = "CFST ipv6 list asset missing ($ASSET_IPV6_LIST)",
            force = force,
        )

        return InstallResult(
            binary = binary,
            ipv6List = ipv6List,
        )
    }

    fun inspectInstalled(context: Context): RuntimeComponentInfo {
        val binary = packagedBinary(context)
        val destDir = File(context.filesDir, "cfst")
        val ipv6List = File(destDir, IPV6_LIST_NAME)
        if (!isArm64()) {
            return RuntimeComponentInfo(
                condition = RuntimeComponentCondition.UNSUPPORTED,
                detail = "设备 ABI 非 arm64；此 APK 未打包对应架构的 CFST",
                path = binary.absolutePath,
            )
        }
        val inspection = RuntimeBinaryInstall.inspectElfBinary(binary)
        val listReady = RuntimeBinaryInstall.isPresent(ipv6List)
        val condition =
            when {
                inspection.condition == RuntimeBinaryInstall.BinaryCondition.MISSING ||
                    inspection.condition == RuntimeBinaryInstall.BinaryCondition.EMPTY ||
                    !ipv6List.exists() -> RuntimeComponentCondition.MISSING
                !inspection.ready || !listReady -> RuntimeComponentCondition.INVALID
                else -> RuntimeComponentCondition.READY
            }
        val detail =
            if (inspection.ready && listReady) {
                "APK 原生目录 · AArch64 ELF · ${inspection.sizeBytes / 1024} KB · 列表 ${ipv6List.length()} B"
            } else {
                buildList {
                    if (!inspection.ready) add(binaryDetail(inspection))
                    if (!listReady && ipv6List.exists()) {
                        add("IPv6 列表为空；需要重新安装")
                    } else if (!listReady) {
                        add("缺少 IPv6 列表；需要安装")
                    }
                }.joinToString("；")
            }
        return RuntimeComponentInfo(
            condition = condition,
            detail = detail,
            path = binary.absolutePath,
            sizeBytes = inspection.sizeBytes.takeIf { it > 0L },
        )
    }

    fun repair(context: Context): RuntimeComponentInfo =
        if (!isArm64()) {
            inspectInstalled(context)
        } else {
            try {
                installIfNeeded(context, force = true)
                inspectInstalled(context)
            } catch (error: Exception) {
                Log.w(TAG, "repair: ${error.message}")
                RuntimeComponentInfo(
                    condition = RuntimeComponentCondition.ERROR,
                    detail = error.message ?: "CFST 修复失败",
                )
            }
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

    private fun packagedBinary(context: Context): File =
        File(context.applicationInfo.nativeLibraryDir, NATIVE_BINARY_NAME)

    private fun binaryDetail(inspection: RuntimeBinaryInstall.BinaryInspection): String =
        when (inspection.condition) {
            RuntimeBinaryInstall.BinaryCondition.MISSING ->
                "APK 未包含 CFST（$NATIVE_BINARY_NAME）；请运行 fetch-cfst.mjs 后重新构建并安装应用"
            RuntimeBinaryInstall.BinaryCondition.EMPTY -> "APK 内 CFST 文件为空；需要重新构建并安装应用"
            RuntimeBinaryInstall.BinaryCondition.INVALID_FORMAT ->
                "APK 内 CFST 不是完整的 64-bit little-endian ELF"
            RuntimeBinaryInstall.BinaryCondition.INCOMPATIBLE_ARCHITECTURE ->
                "APK 内 CFST 架构不兼容（machine=${inspection.machine ?: "?"}，需要 AArch64）"
            RuntimeBinaryInstall.BinaryCondition.NOT_EXECUTABLE ->
                "系统未以可执行方式解包 CFST；请重新安装应用"
            RuntimeBinaryInstall.BinaryCondition.READY ->
                "APK 原生目录 · AArch64 ELF · ${inspection.sizeBytes / 1024} KB"
        }
}
