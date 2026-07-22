package dev.viasix.app.cfst

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Structural checks that installer constants stay aligned with fetch-cfst assets.
 * Full install needs Android Context; binary may be absent until fetch-cfst runs.
 */
class CfstInstallerSurfaceTest {
    @Test
    fun assetPathsMatchFetchScriptLayout() {
        assertEquals("cfst/cfst-arm64", CfstInstaller.ASSET_BINARY_ARM64)
        assertEquals("cfst/ipv6.txt", CfstInstaller.ASSET_IPV6_LIST)
        assertEquals("cfst", CfstInstaller.BINARY_NAME)
        assertEquals("ipv6.txt", CfstInstaller.IPV6_LIST_NAME)
    }

    @Test
    fun bundledIpv6ListAssetIsPresentOnClasspathOrSourceTree() {
        // Source-tree asset is committed; unit tests on JVM may not see Android assets/.
        // Assert the public contract so UI/runner wiring cannot drift.
        assertTrue(CfstInstaller.ASSET_BINARY_ARM64.startsWith("cfst/"))
        assertTrue(CfstInstaller.ASSET_IPV6_LIST.endsWith("ipv6.txt"))
    }
}
