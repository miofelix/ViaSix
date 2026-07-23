package dev.viasix.app.session

import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Exercises real [ProfileImportText] used by Profiles “粘贴剪贴板”. */
class ProfileImportTextTest {
    @Test
    fun extractsYamlWithProxiesMarker() {
        val raw =
            """
            proxies:
              - name: a
                type: vless
                server: example.com
                port: 443
            x-viasix:
              version: 1
              primary-server: selected-ip
            """.trimIndent()
        val yaml = ProfileImportText.extractYaml(raw)
        assertNotNull(yaml)
        assertTrue(yaml!!.contains("proxies:"))
    }

    @Test
    fun rejectsBareHttpsUrl() {
        assertNull(ProfileImportText.extractYaml("https://example.com/sub?token=1"))
        assertTrue(ProfileImportText.looksLikeBareUrl("https://example.com/sub"))
    }

    @Test
    fun rejectsEmptyAndNoise() {
        assertNull(ProfileImportText.extractYaml(null))
        assertNull(ProfileImportText.extractYaml("   "))
        assertNull(ProfileImportText.extractYaml("hello world"))
        assertFalse(ProfileImportText.looksLikeProfileYaml("a: 1\nb: 2"))
    }

    @Test
    fun acceptsMinimalKeyValueYamlDepth() {
        val raw =
            """
            port: 7890
            socks-port: 7891
            allow-lan: false
            mode: rule
            log-level: info
            """.trimIndent()
        assertNotNull(ProfileImportText.extractYaml(raw))
    }
}
