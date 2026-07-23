package dev.viasix.app.mihomo

import android.content.Context
import android.os.Build
import android.util.Log
import dev.viasix.app.runtime.RuntimeBinaryInstall
import dev.viasix.app.runtime.RuntimeComponentCondition
import dev.viasix.app.runtime.RuntimeComponentInfo
import java.io.File
import java.io.IOException

/**
 * Resolves the bundled mihomo executable from Android's native library directory.
 *
 * Android 10+ denies exec from writable app directories such as filesDir, even when
 * chmod reports an execute bit (ProcessBuilder → EACCES / error=13). Packaging
 * mihomo as `libmihomo.so` makes PackageManager extract it into the read-only,
 * executable nativeLibraryDir — the same approach used for CFST (`libcfst.so`).
 * Ships arm64 only (android-arm64-v8 upstream).
 */
object MihomoInstaller {
    private const val TAG = "MihomoInstaller"
    const val NATIVE_BINARY_NAME = "libmihomo.so"

    @Synchronized
    fun installIfNeeded(
        context: Context,
        force: Boolean = false,
    ): File {
        // force is retained for API parity with CFST / settings repair; the binary
        // is read-only under nativeLibraryDir and can only be replaced by reinstalling
        // the APK (fetch-mihomo.mjs → rebuild).
        @Suppress("UNUSED_PARAMETER")
        val ignored = force
        if (!isArm64()) {
            throw IOException("设备 ABI 非 arm64，当前 APK 仅包含 arm64-v8a mihomo")
        }
        val binary = packagedBinary(context)
        val inspection = RuntimeBinaryInstall.inspectElfBinary(binary)
        if (!inspection.ready) {
            throw IOException(binaryDetail(inspection))
        }
        return binary
    }

    fun inspectInstalled(context: Context): RuntimeComponentInfo {
        val file = packagedBinary(context)
        if (!isArm64()) {
            return RuntimeComponentInfo(
                condition = RuntimeComponentCondition.UNSUPPORTED,
                detail = "设备 ABI 非 arm64；此 APK 未打包对应架构的 mihomo",
                path = file.absolutePath,
            )
        }
        val inspection = RuntimeBinaryInstall.inspectElfBinary(file)
        val condition =
            when (inspection.condition) {
                RuntimeBinaryInstall.BinaryCondition.READY -> RuntimeComponentCondition.READY
                RuntimeBinaryInstall.BinaryCondition.MISSING,
                RuntimeBinaryInstall.BinaryCondition.EMPTY -> RuntimeComponentCondition.MISSING
                RuntimeBinaryInstall.BinaryCondition.INVALID_FORMAT,
                RuntimeBinaryInstall.BinaryCondition.INCOMPATIBLE_ARCHITECTURE,
                RuntimeBinaryInstall.BinaryCondition.NOT_EXECUTABLE -> RuntimeComponentCondition.INVALID
            }
        return RuntimeComponentInfo(
            condition = condition,
            detail = binaryDetail(inspection),
            path = file.absolutePath,
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
                    detail = error.message ?: "mihomo 修复失败",
                )
            }
        }

    fun isArm64(): Boolean {
        val abis = Build.SUPPORTED_ABIS
        return abis.any { it.contains("arm64") || it == "aarch64" }
    }

    private fun packagedBinary(context: Context): File =
        File(context.applicationInfo.nativeLibraryDir, NATIVE_BINARY_NAME)

    private fun binaryDetail(inspection: RuntimeBinaryInstall.BinaryInspection): String =
        when (inspection.condition) {
            RuntimeBinaryInstall.BinaryCondition.MISSING ->
                "APK 未包含 mihomo（$NATIVE_BINARY_NAME）；请运行 fetch-mihomo.mjs 后重新构建并安装应用"
            RuntimeBinaryInstall.BinaryCondition.EMPTY ->
                "APK 内 mihomo 文件为空；需要重新构建并安装应用"
            RuntimeBinaryInstall.BinaryCondition.INVALID_FORMAT ->
                "APK 内 mihomo 不是完整的 64-bit little-endian ELF"
            RuntimeBinaryInstall.BinaryCondition.INCOMPATIBLE_ARCHITECTURE ->
                "APK 内 mihomo 架构不兼容（machine=${inspection.machine ?: "?"}，需要 AArch64）"
            RuntimeBinaryInstall.BinaryCondition.NOT_EXECUTABLE ->
                "系统未以可执行方式解包 mihomo；请重新安装应用"
            RuntimeBinaryInstall.BinaryCondition.READY ->
                "APK 原生目录 · AArch64 ELF · ${inspection.sizeBytes / 1024} KB"
        }
}
