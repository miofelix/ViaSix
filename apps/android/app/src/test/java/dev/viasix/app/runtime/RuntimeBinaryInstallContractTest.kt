package dev.viasix.app.runtime

import org.junit.Assert.assertFalse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Pure contract checks for install destination readiness used by mihomo/CFST installers.
 */
class RuntimeBinaryInstallContractTest {
    @Test
    fun inspectElfBinary_distinguishesMissingEmptyAndTruncatedFiles() {
        val missing = File("/tmp/viasix-definitely-missing-elf-xyz")
        assertEquals(
            RuntimeBinaryInstall.BinaryCondition.MISSING,
            RuntimeBinaryInstall.inspectElfBinary(missing).condition,
        )

        val empty = File.createTempFile("viasix-empty-elf", ".bin")
        assertEquals(
            RuntimeBinaryInstall.BinaryCondition.EMPTY,
            RuntimeBinaryInstall.inspectElfBinary(empty).condition,
        )
        empty.writeBytes(byteArrayOf(0x7f, 'E'.code.toByte(), 'L'.code.toByte()))
        assertEquals(
            RuntimeBinaryInstall.BinaryCondition.INVALID_FORMAT,
            RuntimeBinaryInstall.inspectElfBinary(empty).condition,
        )
        empty.delete()
    }

    @Test
    fun inspectElfBinary_requiresAarch64AndExecutePermission() {
        val valid = elfFile(machine = 183, executable = true)
        assertEquals(
            RuntimeBinaryInstall.BinaryCondition.READY,
            RuntimeBinaryInstall.inspectElfBinary(valid).condition,
        )
        valid.delete()

        val wrongArchitecture = elfFile(machine = 62, executable = true)
        val wrongInspection = RuntimeBinaryInstall.inspectElfBinary(wrongArchitecture)
        assertEquals(
            RuntimeBinaryInstall.BinaryCondition.INCOMPATIBLE_ARCHITECTURE,
            wrongInspection.condition,
        )
        assertEquals(62, wrongInspection.machine)
        wrongArchitecture.delete()

        val notExecutable = elfFile(machine = 183, executable = false)
        assertEquals(
            RuntimeBinaryInstall.BinaryCondition.NOT_EXECUTABLE,
            RuntimeBinaryInstall.inspectElfBinary(notExecutable).condition,
        )
        notExecutable.delete()
    }

    @Test
    fun bundledSidecarsAreValidAarch64ElfWhenPresent() {
        val candidates =
            listOf(
                "src/main/assets/mihomo/mihomo-arm64",
                "src/main/assets/cfst/cfst-arm64",
                "app/src/main/assets/mihomo/mihomo-arm64",
                "app/src/main/assets/cfst/cfst-arm64",
                "apps/android/app/src/main/assets/mihomo/mihomo-arm64",
                "apps/android/app/src/main/assets/cfst/cfst-arm64",
            ).map(::File).filter { it.isFile }

        candidates.forEach { file ->
            assertEquals(
                "${file.name} must be an executable AArch64 ELF",
                RuntimeBinaryInstall.BinaryCondition.READY,
                RuntimeBinaryInstall.inspectElfBinary(file).condition,
            )
        }
    }

    @Test
    fun isPresent_rejectsMissingAndEmpty() {
        val missing = File("/tmp/viasix-definitely-missing-binary-xyz")
        assertFalse(RuntimeBinaryInstall.isPresent(missing))

        val empty = File.createTempFile("viasix-empty", ".bin")
        empty.writeBytes(ByteArray(0))
        assertFalse(RuntimeBinaryInstall.isPresent(empty))
        empty.delete()
    }

    @Test
    fun isPresent_acceptsNonEmptyFile() {
        val f = File.createTempFile("viasix-bin", ".bin")
        f.writeBytes(byteArrayOf(0x7f, 'E'.code.toByte(), 'L'.code.toByte(), 'F'.code.toByte()))
        assertTrue(RuntimeBinaryInstall.isPresent(f))
        f.delete()
    }

    private fun elfFile(
        machine: Int,
        executable: Boolean,
    ): File {
        val bytes = ByteArray(64)
        bytes[0] = 0x7f.toByte()
        bytes[1] = 'E'.code.toByte()
        bytes[2] = 'L'.code.toByte()
        bytes[3] = 'F'.code.toByte()
        bytes[4] = 2.toByte()
        bytes[5] = 1.toByte()
        bytes[18] = (machine and 0xff).toByte()
        bytes[19] = ((machine shr 8) and 0xff).toByte()
        val file = File.createTempFile("viasix-elf", ".bin")
        file.writeBytes(bytes)
        file.setExecutable(executable, true)
        return file
    }
}
