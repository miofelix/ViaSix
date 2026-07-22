//! Mihomo external-controller health probe.

use serde::Serialize;
use std::time::Duration;

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ControllerHealth {
    pub ok: bool,
    pub endpoint: String,
    pub message: String,
    pub version: Option<String>,
}

pub async fn probe(host: &str, port: u16, secret: &str) -> ControllerHealth {
    let endpoint = format!("http://{host}:{port}/version");
    let client = match reqwest::Client::builder()
        .timeout(Duration::from_secs(3))
        .build()
    {
        Ok(c) => c,
        Err(err) => {
            return ControllerHealth {
                ok: false,
                endpoint,
                message: format!("client error: {err}"),
                version: None,
            };
        }
    };

    let mut req = client.get(&endpoint);
    if !secret.is_empty() {
        req = req.header("Authorization", format!("Bearer {secret}"));
    }

    match req.send().await {
        Ok(response) if response.status().is_success() => {
            let body = response.text().await.unwrap_or_default();
            let version = parse_version_field(&body);
            ControllerHealth {
                ok: true,
                endpoint,
                message: version
                    .as_ref()
                    .map(|v| format!("controller ok (version {v})"))
                    .unwrap_or_else(|| "controller ok".into()),
                version,
            }
        }
        Ok(response) => ControllerHealth {
            ok: false,
            endpoint,
            message: format!("HTTP {}", response.status()),
            version: None,
        },
        Err(err) => ControllerHealth {
            ok: false,
            endpoint,
            message: format!("unreachable: {err}"),
            version: None,
        },
    }
}

fn parse_version_field(body: &str) -> Option<String> {
    let value: serde_json::Value = serde_json::from_str(body).ok()?;
    value
        .get("version")
        .and_then(|v| v.as_str())
        .map(str::to_string)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_version_json() {
        let v = parse_version_field(r#"{"version":"v1.19.29"}"#).unwrap();
        assert_eq!(v, "v1.19.29");
    }
}
