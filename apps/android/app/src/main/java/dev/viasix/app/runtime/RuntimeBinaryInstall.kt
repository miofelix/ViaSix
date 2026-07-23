package dev.viasix.app.runtime

import android.content.Context
import android.system.Os
import android.util.Log
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.nio.file.Files
import java.nio.file.StandardCopyOption

/**
 * Shared helpers for shipping arm64 sidecar binaries from assets → filesDir.
 * Fixes common Android install failures: missing execute bit, zero-length dest,
 * and stale empty copies that never re-extract.
 */
internal object RuntimeBinaryInstall {
    private const val TAG = "RuntimeBinaryInstall"
    private const val ELF_HEADER_BYTES = 20
    private const val ELF_CLASS_64 = 2
    private const val ELF_DATA_LITTLE_ENDIAN = 1
    private const val ELF_MACHINE_AARCH64 = 183

    enum class BinaryCondition {
        MISSING,
        EMPTY,
        INVALID_FORMAT,
        INCOMPATIBLE_ARCHITECTURE,
        NOT_EXECUTABLE,
        READY,
    }

    data class BinaryInspection(
        val condition: BinaryCondition,
        val sizeBytes: Long = 0L,
        val machine: Int? = null,
    ) {
        val ready: Boolean
            get() = condition == BinaryCondition.READY

        val needsReplacement: Boolean
            get() =
                condition == BinaryCondition.MISSING ||
                    condition == BinaryCondition.EMPTY ||
                    condition == BinaryCondition.INVALID_FORMAT ||
                    condition == BinaryCondition.INCOMPATIBLE_ARCHITECTURE
    }

    /**
     * Replace [dest] when missing, empty, malformed, wrong-architecture, or explicitly forced.
     * An otherwise valid file only needs its private execute permissions re-applied.
     */
    fun installAssetBinary(
        context: Context,
        assetPath: String,
        dest: File,
        missingHint: String,
        force: Boolean = false,
    ): File {
        val parent = dest.parentFile
        if (parent != null && !parent.exists() && !parent.mkdirs()) {
            throw IOException("Cannot create dir: ${parent.absolutePath}")
        }

        val needsCopy = force || inspectElfBinary(dest).needsReplacement
        if (needsCopy) {
            Log.i(TAG, "Installing assets/$assetPath -> ${dest.absolutePath}")
            val tmp = File(dest.absolutePath + ".tmp")
            try {
                // Commit only after the complete asset reaches a sibling temp file.
                if (tmp.exists()) tmp.delete()
                context.assets.open(assetPath).use { input ->
                    FileOutputStream(tmp).use { output -> input.copyTo(output) }
                }
                if (tmp.length() == 0L) {
                    tmp.delete()
                    throw IOException("asset $assetPath is empty")
                }
                commitTempFile(tmp, dest)
            } catch (error: Exception) {
                tmp.delete()
                throw IOException(missingHint, error)
            }
        }

        ensureExecutable(dest)
        val installed = inspectElfBinary(dest)
        if (!installed.ready) {
            throw IOException(
                "install failed (${installed.condition.name.lowercase()}): ${dest.absolutePath}",
            )
        }
        return dest
    }

    fun installAssetFile(
        context: Context,
        assetPath: String,
        dest: File,
        missingHint: String,
        force: Boolean = false,
    ): File {
        val parent = dest.parentFile
        if (parent != null && !parent.exists() && !parent.mkdirs()) {
            throw IOException("Cannot create dir: ${parent.absolutePath}")
        }
        if (force || !dest.isFile || dest.length() == 0L) {
            Log.i(TAG, "Installing assets/$assetPath -> ${dest.absolutePath}")
            val tmp = File(dest.absolutePath + ".tmp")
            try {
                if (tmp.exists()) tmp.delete()
                context.assets.open(assetPath).use { input ->
                    FileOutputStream(tmp).use { output -> input.copyTo(output) }
                }
                if (tmp.length() == 0L) {
                    tmp.delete()
                    throw IOException("asset $assetPath is empty")
                }
                commitTempFile(tmp, dest)
            } catch (error: Exception) {
                tmp.delete()
                throw IOException(missingHint, error)
            }
        }
        if (!isPresent(dest)) throw IOException("install failed: ${dest.absolutePath}")
        return dest
    }

    fun ensureExecutable(file: File) {
        try {
            file.setReadable(true, true)
            file.setWritable(true, true)
            file.setExecutable(true, true)
        } catch (_: Exception) {
        }
        try {
            // App-private runtime: owner read/write/execute is sufficient for ProcessBuilder.
            Os.chmod(file.absolutePath, 0b111_000_000)
        } catch (error: Exception) {
            Log.w(TAG, "chmod ${file.name}: ${error.message}")
        }
        if (!file.canExecute()) {
            Log.w(TAG, "${file.name} may not be marked executable after install")
        }
    }

    fun isPresent(file: File): Boolean = file.isFile && file.length() > 0L

    private fun commitTempFile(
        tmp: File,
        dest: File,
    ) {
        try {
            Files.move(
                tmp.toPath(),
                dest.toPath(),
                StandardCopyOption.ATOMIC_MOVE,
                StandardCopyOption.REPLACE_EXISTING,
            )
        } catch (atomicError: IOException) {
            try {
                Files.move(
                    tmp.toPath(),
                    dest.toPath(),
                    StandardCopyOption.REPLACE_EXISTING,
                )
            } catch (replaceError: IOException) {
                replaceError.addSuppressed(atomicError)
                throw replaceError
            }
        }
    }

    /** Lightweight local integrity check matching Android's shipped arm64 ELF policy. */
    fun inspectElfBinary(file: File): BinaryInspection {
        if (!file.isFile) return BinaryInspection(BinaryCondition.MISSING)
        val size = file.length()
        if (size == 0L) return BinaryInspection(BinaryCondition.EMPTY)

        val header = ByteArray(ELF_HEADER_BYTES)
        val read =
            try {
                FileInputStream(file).use { input ->
                    var offset = 0
                    while (offset < header.size) {
                        val count = input.read(header, offset, header.size - offset)
                        if (count < 0) break
                        offset += count
                    }
                    offset
                }
            } catch (_: Exception) {
                return BinaryInspection(BinaryCondition.INVALID_FORMAT, sizeBytes = size)
            }
        if (read < ELF_HEADER_BYTES ||
            header[0] != 0x7f.toByte() ||
            header[1] != 'E'.code.toByte() ||
            header[2] != 'L'.code.toByte() ||
            header[3] != 'F'.code.toByte() ||
            header[4].toInt() != ELF_CLASS_64 ||
            header[5].toInt() != ELF_DATA_LITTLE_ENDIAN
        ) {
            return BinaryInspection(BinaryCondition.INVALID_FORMAT, sizeBytes = size)
        }

        val machine =
            (header[18].toInt() and 0xff) or ((header[19].toInt() and 0xff) shl 8)
        if (machine != ELF_MACHINE_AARCH64) {
            return BinaryInspection(
                BinaryCondition.INCOMPATIBLE_ARCHITECTURE,
                sizeBytes = size,
                machine = machine,
            )
        }
        if (!file.canExecute()) {
            return BinaryInspection(
                BinaryCondition.NOT_EXECUTABLE,
                sizeBytes = size,
                machine = machine,
            )
        }
        return BinaryInspection(
            BinaryCondition.READY,
            sizeBytes = size,
            machine = machine,
        )
    }
}
