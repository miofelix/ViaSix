package dev.viasix.core.speedtest

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class SpeedTestResultParserTest {
    @Test
    fun parsesFixtureCsvThroughShippedParser() {
        val csv =
            requireNotNull(
                javaClass.classLoader.getResourceAsStream("fixtures/cfst-result-sample.csv"),
            ) { "missing fixtures/cfst-result-sample.csv" }
                .bufferedReader()
                .use { it.readText() }

        val rows = SpeedTestResultParser.parse(csv)
        assertEquals(3, rows.size)

        assertEquals("2001:db8::1", rows[0].ip)
        assertEquals("4", rows[0].sent)
        assertEquals("4", rows[0].received)
        assertEquals("0.00", rows[0].loss)
        assertEquals("12.3", rows[0].latency)
        assertEquals("15.50", rows[0].speed)
        assertEquals("SJC", rows[0].region)
        assertEquals(12.3, rows[0].latencyValue)
        assertEquals(15.50, rows[0].speedValue)
        assertEquals(0.0, rows[0].lossValue)

        assertEquals("2001:db8::2", rows[1].ip)
        assertEquals("25.00", rows[1].loss)
        assertEquals(45.8, rows[1].latencyValue)

        assertEquals("2606:4700:4700::1111", rows[2].ip)
        assertEquals("NRT", rows[2].region)
    }

    @Test
    fun skipsHeaderOnlyAndBlankRows() {
        assertTrue(SpeedTestResultParser.parse("").isEmpty())
        assertTrue(
            SpeedTestResultParser.parse("IP,Sent,Received,Loss,Latency,Speed,Region\n").isEmpty(),
        )
        val withBlank =
            """
            IP,Sent,Received,Loss,Latency,Speed,Region

            2001:db8::9,1,1,0,1,0,
            """.trimIndent()
        assertEquals(1, SpeedTestResultParser.parse(withBlank).size)
    }

    @Test
    fun skipsShortRowsAndEmptyIp() {
        val csv =
            """
            IP,Sent,Received,Loss,Latency,Speed,Region
            only,two
            ,4,4,0,1,0,x
            2001:db8::a,4,4,0.00,9.0,1.0,HKG
            """.trimIndent()
        val rows = SpeedTestResultParser.parse(csv)
        assertEquals(1, rows.size)
        assertEquals("2001:db8::a", rows[0].ip)
    }

    @Test
    fun stripsBomAndHandlesQuotedIp() {
        val csv =
            "\uFEFFIP,Sent,Received,Loss,Latency,Speed,Region\n" +
                "\"2001:db8::b\",4,4,0.00,3.5,2.0,TEST\n"
        val rows = SpeedTestResultParser.parse(csv)
        assertEquals(1, rows.size)
        assertEquals("2001:db8::b", rows[0].ip)
        assertEquals("3.5", rows[0].latency)
    }

    @Test
    fun missingRegionDefaultsEmpty() {
        val csv =
            """
            IP,Sent,Received,Loss,Latency,Speed
            2001:db8::c,4,4,0,1,0
            """.trimIndent()
        val rows = SpeedTestResultParser.parse(csv)
        assertEquals(1, rows.size)
        assertEquals("", rows[0].region)
        assertNull(rows[0].region.ifEmpty { null })
    }
}
