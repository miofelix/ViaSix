//! Local mixed-proxy invariants aligned with macOS (loopback-only listen).

/// Returns Ok(normalized) when address is loopback; Err with contract-style message otherwise.
pub fn validate_listen_address(raw: &str) -> Result<String, String> {
    let addr = raw.trim();
    if addr.is_empty() {
        return Err("listenAddress required".into());
    }
    // macOS ViaSix only allows loopback mixed-proxy listeners.
    let ok = matches!(
        addr,
        "127.0.0.1" | "::1" | "localhost" | "0:0:0:0:0:0:0:1"
    ) || addr.eq_ignore_ascii_case("localhost");
    if !ok {
        return Err(format!(
            "listenAddress must be loopback (127.0.0.1 or ::1), got {addr}"
        ));
    }
    if addr.eq_ignore_ascii_case("localhost") || addr == "0:0:0:0:0:0:0:1" {
        return Ok("127.0.0.1".into());
    }
    if addr == "::1" {
        return Ok("::1".into());
    }
    Ok("127.0.0.1".into())
}

pub fn validate_port(port: u16, name: &str) -> Result<u16, String> {
    if port == 0 {
        return Err(format!("{name} must be in 1..=65535"));
    }
    Ok(port)
}

/// Merge kernel log tail lines into display-friendly activity messages.
pub fn kernel_log_lines_for_activity(raw: &str, max_lines: usize) -> Vec<String> {
    let take = max_lines.max(1);
    raw.lines()
        .map(str::trim)
        .filter(|l| !l.is_empty())
        .rev()
        .take(take)
        .map(|l| format!("[mihomo] {l}"))
        .collect::<Vec<_>>()
        .into_iter()
        .rev()
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_loopback_v4() {
        assert_eq!(validate_listen_address("127.0.0.1").unwrap(), "127.0.0.1");
        assert_eq!(validate_listen_address(" localhost ").unwrap(), "127.0.0.1");
    }

    #[test]
    fn accepts_loopback_v6() {
        assert_eq!(validate_listen_address("::1").unwrap(), "::1");
    }

    #[test]
    fn rejects_lan_bind() {
        let err = validate_listen_address("0.0.0.0").unwrap_err();
        assert!(err.contains("loopback"), "{err}");
        let err = validate_listen_address("192.168.1.1").unwrap_err();
        assert!(err.contains("loopback"), "{err}");
    }

    #[test]
    fn kernel_log_lines_preserve_order_and_cap() {
        let raw = "a\nb\nc\nd\n";
        let lines = kernel_log_lines_for_activity(raw, 2);
        assert_eq!(lines, vec!["[mihomo] c".to_string(), "[mihomo] d".to_string()]);
    }

    #[test]
    fn validate_port_rejects_zero() {
        let err = validate_port(0, "mixedPort").unwrap_err();
        assert!(err.contains("mixedPort"), "{err}");
        assert_eq!(validate_port(11451, "mixedPort").unwrap(), 11451);
    }

    #[test]
    fn rejects_empty_listen() {
        assert!(validate_listen_address("").is_err());
        assert!(validate_listen_address("   ").is_err());
    }
}
