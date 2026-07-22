//! Profile YAML summary (aligned with macOS MihomoProfileSummary spirit).

use serde::Serialize;
use serde_yaml::Value;

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ProfileSummary {
    pub primary_name: Option<String>,
    pub primary_type: Option<String>,
    pub proxy_count: usize,
    pub has_xviasix: bool,
    pub looks_like_example: bool,
    pub has_inline_proxy: bool,
    pub notes: Vec<String>,
    pub ok: bool,
    pub error: Option<String>,
}

pub fn summarize_profile_yaml(yaml: &str) -> ProfileSummary {
    let trimmed = yaml.trim();
    if trimmed.is_empty() {
        return ProfileSummary {
            primary_name: None,
            primary_type: None,
            proxy_count: 0,
            has_xviasix: false,
            looks_like_example: false,
            has_inline_proxy: false,
            notes: vec!["配置为空".into()],
            ok: false,
            error: Some("empty profile".into()),
        };
    }

    let root: Value = match serde_yaml::from_str(trimmed) {
        Ok(v) => v,
        Err(err) => {
            return ProfileSummary {
                primary_name: None,
                primary_type: None,
                proxy_count: 0,
                has_xviasix: false,
                looks_like_example: looks_like_example(trimmed),
                has_inline_proxy: false,
                notes: vec![format!("YAML 解析失败: {err}")],
                ok: false,
                error: Some(err.to_string()),
            };
        }
    };

    let mapping = root.as_mapping();
    let proxies = mapping
        .and_then(|m| m.get(Value::from("proxies")))
        .and_then(Value::as_sequence)
        .cloned()
        .unwrap_or_default();

    let mut primary_name = None;
    let mut primary_type = None;
    for item in &proxies {
        if let Some(map) = item.as_mapping() {
            if primary_name.is_none() {
                primary_name = map
                    .get(Value::from("name"))
                    .and_then(Value::as_str)
                    .map(str::to_string);
            }
            if primary_type.is_none() {
                primary_type = map
                    .get(Value::from("type"))
                    .and_then(Value::as_str)
                    .map(str::to_string);
            }
            if primary_name.is_some() && primary_type.is_some() {
                break;
            }
        }
    }

    let has_xviasix = mapping
        .map(|m| m.contains_key(Value::from("x-viasix")))
        .unwrap_or(false);
    let has_inline_proxy = !proxies.is_empty();
    let looks = looks_like_example(trimmed);

    let mut notes = Vec::new();
    if !has_inline_proxy {
        notes.push("未检测到内联代理（Provider-only 会被拒绝）".into());
    }
    if looks {
        notes.push("仍为示例配置，请替换为真实入口".into());
    }
    if !has_xviasix {
        notes.push("建议保留 x-viasix.primary-server: selected-ip".into());
    }
    if proxies.len() > 1 {
        notes.push(format!(
            "检测到 {} 个代理，运行时只保留第一个可注入项",
            proxies.len()
        ));
    }

    ProfileSummary {
        primary_name,
        primary_type,
        proxy_count: proxies.len(),
        has_xviasix,
        looks_like_example: looks,
        has_inline_proxy,
        notes,
        ok: has_inline_proxy && !looks,
        error: None,
    }
}

fn looks_like_example(text: &str) -> bool {
    text.contains("example.com")
        || text.contains("11111111-1111-4111-1111-111111111111")
        || text.contains("origin.example")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn summarizes_inline_proxy() {
        let yaml = r#"
proxies:
  - name: Edge
    type: vless
    server: a.example.net
    port: 443
x-viasix:
  version: 1
  primary-server: selected-ip
"#;
        let s = summarize_profile_yaml(yaml);
        assert_eq!(s.primary_name.as_deref(), Some("Edge"));
        assert_eq!(s.primary_type.as_deref(), Some("vless"));
        assert_eq!(s.proxy_count, 1);
        assert!(s.has_xviasix);
        assert!(s.has_inline_proxy);
        assert!(!s.looks_like_example); // example.net is not our heuristic list
    }

    #[test]
    fn flags_example_profile() {
        let yaml = r#"
proxies:
  - name: My VLESS
    type: vless
    server: origin.example.com
    port: 443
"#;
        let s = summarize_profile_yaml(yaml);
        assert!(s.looks_like_example);
        assert!(!s.ok);
    }
}
