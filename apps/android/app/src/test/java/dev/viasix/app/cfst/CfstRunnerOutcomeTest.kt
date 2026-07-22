package dev.viasix.app.cfst

import dev.viasix.core.speedtest.SpeedTestParameters
import dev.viasix.core.speedtest.SpeedTestResultParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import kotlin.io.path.createTempDirectory

/**
 * Exercises [CfstRunner] failure paths and success parsing without a real CFST binary.
 * Uses missing binary / empty result file so the shipped entry points run on JVM.
 */
class CfstRunnerOutcomeTest {
    @Test
    fun failsWhenBinaryMissing() {
        val work = createTempDirectory("cfst-work").toFile()
        try {
            val runner = CfstRunner()
            val outcome =
                runner.run(
                    binary = File(work, "no-such-cfst"),
                    workDir = work,
                    parameters = SpeedTestParameters.defaultsForRange("2001:db8::/32"),
                )
            assertTrue(outcome is CfstRunOutcome.Failed)
            assertTrue((outcome as CfstRunOutcome.Failed).message.contains("未找到 CFST"))
            assertFalse(runner.isRunning)
        } finally {
            work.deleteRecursively()
        }
    }

    @Test
    fun failsWhenIpSourceMissing() {
        val work = createTempDirectory("cfst-work").toFile()
        val bin = File(work, "cfst").apply { writeText("x"); setExecutable(true) }
        try {
            val outcome =
                CfstRunner().run(
                    binary = bin,
                    workDir = work,
                    parameters = SpeedTestParameters(),
                )
            assertTrue(outcome is CfstRunOutcome.Failed)
            assertTrue((outcome as CfstRunOutcome.Failed).message.contains("IP"))
        } finally {
            work.deleteRecursively()
        }
    }

    @Test
    fun failsWhenIpFileMissing() {
        val work = createTempDirectory("cfst-work").toFile()
        val bin = File(work, "cfst").apply { writeText("x"); setExecutable(true) }
        try {
            val outcome =
                CfstRunner().run(
                    binary = bin,
                    workDir = work,
                    parameters = SpeedTestParameters.defaultsForFile(File(work, "missing.txt").absolutePath),
                )
            assertTrue(outcome is CfstRunOutcome.Failed)
            assertTrue((outcome as CfstRunOutcome.Failed).message.contains("找不到"))
        } finally {
            work.deleteRecursively()
        }
    }

    @Test
    fun parserIntegrationMatchesRunnerSuccessShape() {
        // Shipped parser path used after CFST exits; fixture mirrors runner's read→parse.
        val csv =
            """
            IP,Sent,Received,Loss,Latency,Speed,Region
            2001:db8::1,4,4,0.00,12.3,15.50,SJC
            """.trimIndent()
        val results = SpeedTestResultParser.parse(csv)
        val success =
            CfstRunOutcome.Success(
                results = results,
                resultCsvPath = "/tmp/result.csv",
                message = "测速完成：${results.size} 个结果",
            )
        assertEquals(1, success.results.size)
        assertEquals("2001:db8::1", success.results[0].ip)
        assertEquals("12.3", success.results[0].latency)
        assertTrue(success.message.contains("1"))
    }
}
