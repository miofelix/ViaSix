//! Exit IP probe via public HTTPS endpoints (no telemetry beyond the probe itself).

use serde::{Deserialize, Serialize};
use std::time::Duration;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ExitIpResult {
    pub ip: String,
    pub family: String,
    pub source: String,
    pub message: String,
}

const DEFAULT_ENDPOINTS: &[&str] = &[
    "https://api64.ipify.org?format=json",
    "https://api.ipify.org?format=json",
];

#[derive(Debug, Deserialize)]
struct IpifyResponse {
    ip: String,
}

pub async fn detect_exit_ip(endpoints: Option<Vec<String>>) -> Result<ExitIpResult, String> {
    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(8))
        .user_agent("ViaSix-Windows/0.1")
        .build()
        .map_err(|e| e.to_string())?;

    let list: Vec<String> = endpoints
        .filter(|v| !v.is_empty())
        .unwrap_or_else(|| DEFAULT_ENDPOINTS.iter().map(|s| (*s).to_string()).collect());

    let mut last_error = String::from("no endpoints configured");
    for url in list {
        match probe(&client, &url).await {
            Ok(result) => return Ok(result),
            Err(err) => last_error = err,
        }
    }
    Err(last_error)
}

async fn probe(client: &reqwest::Client, url: &str) -> Result<ExitIpResult, String> {
    let response = client
        .get(url)
        .send()
        .await
        .map_err(|e| format!("request {url}: {e}"))?;
    if !response.status().is_success() {
        return Err(format!("request {url}: HTTP {}", response.status()));
    }

    let body = response.text().await.map_err(|e| e.to_string())?;
    let ip = parse_ip_payload(&body).ok_or_else(|| format!("unable to parse IP from {url}"))?;
    let family = if ip.contains(':') { "ipv6" } else { "ipv4" };

    Ok(ExitIpResult {
        ip: ip.clone(),
        family: family.into(),
        source: url.to_string(),
        message: format!("Exit {family}: {ip}"),
    })
}

fn parse_ip_payload(body: &str) -> Option<String> {
    let trimmed = body.trim();
    if let Ok(parsed) = serde_json::from_str::<IpifyResponse>(trimmed) {
        let ip = parsed.ip.trim();
        if !ip.is_empty() {
            return Some(ip.to_string());
        }
    }
    // Plain text fallback
    if !trimmed.is_empty() && !trimmed.contains('<') && trimmed.len() < 128 {
        return Some(trimmed.to_string());
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_ipify_json() {
        let ip = parse_ip_payload(r#"{"ip":"203.0.113.10"}"#).unwrap();
        assert_eq!(ip, "203.0.113.10");
    }

    #[test]
    fn parses_plain_text() {
        let ip = parse_ip_payload("2001:db8::1\n").unwrap();
        assert_eq!(ip, "2001:db8::1");
    }
}
