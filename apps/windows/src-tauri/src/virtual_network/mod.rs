//! Virtual network (Wintun / Windows Service) capability surface.
//!
//! Full TUN is intentionally not implemented yet. This module defines the
//! product-facing status API and a fail-closed stub so UI/CI can depend on a
//! stable interface without enabling unsafe network changes.

use serde::Serialize;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum VirtualNetworkBackend {
    /// Planned: Windows Service + Wintun adapter.
    WintunService,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct VirtualNetworkStatus {
    pub available: bool,
    pub enabled: bool,
    pub backend: VirtualNetworkBackend,
    pub message: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct VirtualNetworkCapability {
    pub supported: bool,
    pub backend: VirtualNetworkBackend,
    pub requires_elevation: bool,
    pub message: String,
}

/// Fail-closed manager. Enable returns a structured "not implemented" error.
pub struct VirtualNetworkManager {
    enabled: bool,
}

impl Default for VirtualNetworkManager {
    fn default() -> Self {
        Self { enabled: false }
    }
}

impl VirtualNetworkManager {
    pub fn capability() -> VirtualNetworkCapability {
        VirtualNetworkCapability {
            supported: false,
            backend: VirtualNetworkBackend::WintunService,
            requires_elevation: true,
            message: "Wintun + privileged Windows Service is planned; not available in this build"
                .into(),
        }
    }

    pub fn status(&self) -> VirtualNetworkStatus {
        let capability = Self::capability();
        VirtualNetworkStatus {
            available: capability.supported,
            enabled: self.enabled,
            backend: capability.backend,
            message: if self.enabled {
                "Virtual network enabled (unexpected in stub)".into()
            } else {
                capability.message
            },
        }
    }

    pub fn enable(&mut self) -> Result<VirtualNetworkStatus, String> {
        Err(
            "virtualInterface is not implemented on Windows yet (planned: Wintun Service)"
                .into(),
        )
    }

    pub fn disable(&mut self) -> Result<VirtualNetworkStatus, String> {
        self.enabled = false;
        Ok(self.status())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn enable_is_fail_closed() {
        let mut mgr = VirtualNetworkManager::default();
        assert!(mgr.enable().is_err());
        assert!(!mgr.status().enabled);
        assert!(!VirtualNetworkManager::capability().supported);
    }
}
