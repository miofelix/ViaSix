package dev.viasix.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ContentCopy
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Hub
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.automirrored.outlined.PlaylistAddCheck
import androidx.compose.material3.Button
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import dev.viasix.app.state.SessionUiState
import dev.viasix.app.ui.AppSection
import dev.viasix.app.ui.theme.AppPageHeader
import dev.viasix.app.ui.theme.AppTone
import dev.viasix.app.ui.theme.CardHeader
import dev.viasix.app.ui.theme.LocalViaSixColors
import dev.viasix.app.ui.theme.StatusBadge
import dev.viasix.app.ui.theme.SurfaceCard
import dev.viasix.app.ui.theme.VisualStyle
import dev.viasix.core.net.Ipv6Address

@Composable
fun NodesScreen(
    state: SessionUiState,
    onSelectedAddressChange: (String) -> Unit,
    onApplyNode: (address: String, reconnect: Boolean) -> Unit,
    onRemoveCandidate: (String) -> Unit,
    onCopy: (label: String, value: String) -> Unit,
) {
    val colors = LocalViaSixColors.current
    val looksValid = Ipv6Address.isValid(state.selectedAddress)

    Column(Modifier.fillMaxSize()) {
        AppPageHeader(
            title = AppSection.NODES.title,
            subtitle = AppSection.NODES.subtitle,
        ) {
            StatusBadge(
                title = if (looksValid) "已选择" else "未选择",
                tone = if (looksValid) AppTone.Accent else AppTone.Warning,
            )
        }

        Column(
            modifier =
                Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(
                        horizontal = VisualStyle.pageHorizontalPadding,
                        vertical = VisualStyle.pageVerticalPadding,
                    ),
            verticalArrangement = Arrangement.spacedBy(VisualStyle.spacing12),
        ) {
            SurfaceCard {
                CardHeader(
                    title = "当前 IPv6 节点",
                    icon = Icons.Outlined.Hub,
                    tone = if (looksValid) AppTone.Accent else AppTone.Warning,
                )
                HorizontalDivider(color = colors.surfaceBorder)
                Column(
                    modifier = Modifier.padding(VisualStyle.spacing16),
                    verticalArrangement = Arrangement.spacedBy(VisualStyle.spacing12),
                ) {
                    OutlinedTextField(
                        value = state.selectedAddress,
                        onValueChange = onSelectedAddressChange,
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text("选中 IPv6") },
                        singleLine = true,
                        textStyle =
                            MaterialTheme.typography.bodyLarge.copy(
                                fontFamily = FontFamily.Monospace,
                            ),
                        supportingText = {
                            Text(
                                if (looksValid) {
                                    "合法 IPv6 · 将作为 primary-server 注入运行配置"
                                } else {
                                    "需要合法 IPv6（支持 [brackets] 与 zone id 规范化）"
                                },
                            )
                        },
                        isError = state.selectedAddress.isNotBlank() && !looksValid,
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(VisualStyle.spacing8),
                    ) {
                        Button(
                            onClick = { onApplyNode(state.selectedAddress, false) },
                            enabled = looksValid,
                            modifier = Modifier.weight(1f),
                        ) {
                            Text("应用节点")
                        }
                        FilledTonalButton(
                            onClick = { onApplyNode(state.selectedAddress, true) },
                            enabled = looksValid && state.runtime.running,
                            modifier = Modifier.weight(1f),
                        ) {
                            Text("应用并重连")
                        }
                    }
                    if (state.runtime.running) {
                        Text(
                            "「应用并重连」会短暂中断本地代理，并以所选节点重新建立 VpnService 会话。",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }

            SurfaceCard {
                CardHeader(
                    title = "候选节点",
                    icon = Icons.AutoMirrored.Outlined.PlaylistAddCheck,
                    tone = AppTone.Accent,
                ) {
                    StatusBadge(
                        "${state.candidateAddresses.size}",
                        tone = AppTone.Neutral,
                    )
                }
                HorizontalDivider(color = colors.surfaceBorder)
                if (state.candidateAddresses.isEmpty()) {
                    Text(
                        "应用合法 IPv6 后会出现在候选列表，便于快速切换。",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(VisualStyle.spacing16),
                    )
                } else {
                    Column {
                        state.candidateAddresses.forEachIndexed { index, address ->
                            val selected = address == Ipv6Address.normalize(state.selectedAddress)
                            Row(
                                modifier =
                                    Modifier
                                        .fillMaxWidth()
                                        .padding(
                                            horizontal = VisualStyle.spacing12,
                                            vertical = VisualStyle.spacing8,
                                        ),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(4.dp),
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        address,
                                        style =
                                            MaterialTheme.typography.bodyMedium.copy(
                                                fontFamily = FontFamily.Monospace,
                                            ),
                                        maxLines = 2,
                                    )
                                    if (selected) {
                                        Text(
                                            "当前使用",
                                            style = MaterialTheme.typography.labelSmall,
                                            color = colors.accent,
                                        )
                                    }
                                }
                                IconButton(onClick = { onCopy("IPv6", address) }) {
                                    Icon(Icons.Outlined.ContentCopy, contentDescription = "复制")
                                }
                                OutlinedButton(
                                    onClick = { onApplyNode(address, false) },
                                    modifier = Modifier.height(34.dp),
                                ) { Text("选用") }
                                if (state.runtime.running) {
                                    FilledTonalButton(
                                        onClick = { onApplyNode(address, true) },
                                        modifier = Modifier.height(34.dp),
                                    ) { Text("重连") }
                                }
                                IconButton(onClick = { onRemoveCandidate(address) }) {
                                    Icon(Icons.Outlined.Delete, contentDescription = "移除")
                                }
                            }
                            if (index != state.candidateAddresses.lastIndex) {
                                HorizontalDivider(
                                    color = colors.surfaceBorder,
                                    modifier = Modifier.padding(start = 16.dp),
                                )
                            }
                        }
                    }
                }
            }

            SurfaceCard {
                CardHeader(title = "说明", icon = Icons.Outlined.Info, tone = AppTone.Neutral)
                HorizontalDivider(color = colors.surfaceBorder)
                Column(
                    modifier = Modifier.padding(VisualStyle.spacing16),
                    verticalArrangement = Arrangement.spacedBy(VisualStyle.spacing8),
                ) {
                    Text(
                        "macOS 端提供 CloudflareSpeedTest 测速、参数组与结果排序；" +
                            "Android 已对齐节点应用、候选库、校验与重连语义。" +
                            "测速引擎接入后可直接写入同一候选列表。",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(
                        "直连模式下不需要 IPv6 节点；规则 / 全局模式投影要求 selectedNodeMustBeIPv6。",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}
