# Mihomo config projection fixtures

Golden input/output pairs for IPv6-first profile projection.

| Scenario | Input | Output | Notes |
| --- | --- | --- | --- |
| `rule-replace-server` | `.in.yaml` | `.out.yaml` | Keep one inline proxy; replace `server` with selected IPv6; strip providers/groups. |

Platform implementations (Swift / future Windows & Android) must produce equivalent outputs for these fixtures. Full fixture corpus will be extracted from `apps/macos` tests in a follow-up change.
