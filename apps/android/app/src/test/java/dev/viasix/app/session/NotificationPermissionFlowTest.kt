package dev.viasix.app.session

import dev.viasix.app.state.LogLevel
import dev.viasix.app.state.SessionUiState
import dev.viasix.app.state.appendLog
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NotificationPermissionFlowTest {
    @Test
    fun preAndroid13ContinuesWithoutPrompt() {
        val state = NotificationPermissionState(required = false, granted = true)
        assertEquals(
            NotificationPermissionFlow.BeforeStart.CONTINUE,
            NotificationPermissionFlow.beforeStart(state),
        )
        assertEquals("系统自动允许", state.statusLabel)
    }

    @Test
    fun firstDeniedStateRequestsOnce() {
        val state =
            NotificationPermissionState(
                required = true,
                granted = false,
                wasRequested = false,
            )
        assertEquals(
            NotificationPermissionFlow.BeforeStart.REQUEST_PERMISSION,
            NotificationPermissionFlow.beforeStart(state),
        )
        assertTrue(state.canRequestInApp)
        assertEquals("尚未询问", state.statusLabel)
    }

    @Test
    fun priorDenialDoesNotInterruptEveryConnection() {
        val state =
            NotificationPermissionState(
                required = true,
                granted = false,
                wasRequested = true,
                shouldShowRationale = false,
            )
        assertEquals(
            NotificationPermissionFlow.BeforeStart.CONTINUE,
            NotificationPermissionFlow.beforeStart(state),
        )
        assertFalse(state.canRequestInApp)
        assertEquals("已关闭", state.statusLabel)
    }

    @Test
    fun rationaleAllowsManualRetryButNotAutomaticReprompt() {
        val state =
            NotificationPermissionState(
                required = true,
                granted = false,
                wasRequested = true,
                shouldShowRationale = true,
            )
        assertEquals(
            NotificationPermissionFlow.BeforeStart.CONTINUE,
            NotificationPermissionFlow.beforeStart(state),
        )
        assertTrue(state.canRequestInApp)
    }

    @Test
    fun denialNoticeCanOfferSettingsAction() {
        val state =
            SessionUiState().appendLog(
                message = "通知已关闭",
                level = LogLevel.Warning,
                asNotice = true,
                noticeActionOpenSettings = true,
            )

        assertTrue(state.notice?.actionOpenSettings == true)
    }
}
