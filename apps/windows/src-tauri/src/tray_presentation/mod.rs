//! Pure tray menu presentation (macOS MenuBarExtra-style state labels).

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TrayMenuPresentation {
    pub status_label: String,
    pub start_label: String,
    pub start_enabled: bool,
    pub stop_label: String,
    pub stop_enabled: bool,
    pub tooltip: String,
}

/// Build tray labels from proxy running state and optional live rates (B/s).
pub fn tray_menu_presentation(
    running: bool,
    up_bps: Option<u64>,
    down_bps: Option<u64>,
) -> TrayMenuPresentation {
    if running {
        let rate = match (up_bps, down_bps) {
            (Some(up), Some(down)) => {
                format!(" · ↑ {}/s ↓ {}/s", compact_rate(up), compact_rate(down))
            }
            _ => String::new(),
        };
        TrayMenuPresentation {
            status_label: format!("状态：运行中{rate}"),
            start_label: "启动代理（已运行）".into(),
            start_enabled: false,
            stop_label: "停止代理".into(),
            stop_enabled: true,
            tooltip: match (up_bps, down_bps) {
                (Some(up), Some(down)) => {
                    format!("ViaSix · ↑ {}/s  ↓ {}/s", compact_rate(up), compact_rate(down))
                }
                _ => "ViaSix · 本地代理运行中".into(),
            },
        }
    } else {
        TrayMenuPresentation {
            status_label: "状态：已停止".into(),
            start_label: "启动代理".into(),
            start_enabled: true,
            stop_label: "停止代理（未运行）".into(),
            stop_enabled: false,
            tooltip: "ViaSix · 本地代理未启动".into(),
        }
    }
}

fn compact_rate(bps: u64) -> String {
    const UNITS: [&str; 5] = ["B", "KB", "MB", "GB", "TB"];
    let mut value = bps as f64;
    let mut unit = 0;
    while value >= 1024.0 && unit < UNITS.len() - 1 {
        value /= 1024.0;
        unit += 1;
    }
    if unit == 0 {
        format!("{bps} {}", UNITS[unit])
    } else {
        format!("{value:.1} {}", UNITS[unit])
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn stopped_disables_stop_and_enables_start() {
        let p = tray_menu_presentation(false, None, None);
        assert!(p.start_enabled);
        assert!(!p.stop_enabled);
        assert_eq!(p.status_label, "状态：已停止");
        assert!(p.tooltip.contains("未启动"));
    }

    #[test]
    fn running_disables_start_and_shows_rates() {
        let p = tray_menu_presentation(true, Some(2048), Some(4096));
        assert!(!p.start_enabled);
        assert!(p.stop_enabled);
        assert!(p.status_label.contains("运行中"));
        assert!(p.tooltip.contains("↑"));
        assert!(p.tooltip.contains("↓"));
        assert!(p.start_label.contains("已运行"));
    }
}
