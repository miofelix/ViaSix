//! User-space Mihomo process supervision (Windows MVP).

use crate::projection::{project_runtime_yaml, ProjectOptions};
use parking_lot::Mutex;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Clone, serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CoreStatus {
    pub running: bool,
    pub pid: Option<u32>,
    pub message: String,
    pub controller_port: Option<u16>,
}

pub struct CoreRuntime {
    inner: Mutex<Inner>,
}

struct Inner {
    child: Option<Child>,
    work_dir: PathBuf,
    controller_port: Option<u16>,
    controller_secret: Option<String>,
}

impl CoreRuntime {
    pub fn new(work_dir: PathBuf) -> Self {
        Self {
            inner: Mutex::new(Inner {
                child: None,
                work_dir,
                controller_port: None,
                controller_secret: None,
            }),
        }
    }

    pub fn status(&self) -> CoreStatus {
        let mut guard = self.inner.lock();
        self.reap_if_exited(&mut guard);
        match guard.child.as_ref() {
            Some(child) => CoreStatus {
                running: true,
                pid: Some(child.id()),
                message: format!("Mihomo running (pid {})", child.id()),
                controller_port: guard.controller_port,
            },
            None => CoreStatus {
                running: false,
                pid: None,
                message: "Mihomo stopped".into(),
                controller_port: None,
            },
        }
    }

    pub fn controller_credentials(&self) -> Option<(u16, String)> {
        let guard = self.inner.lock();
        match (&guard.controller_port, &guard.controller_secret) {
            (Some(port), Some(secret)) if guard.child.is_some() => Some((*port, secret.clone())),
            _ => None,
        }
    }

    pub fn start(
        &self,
        profile_yaml: Option<&str>,
        options: &ProjectOptions,
        mihomo_bin: &Path,
    ) -> Result<CoreStatus, String> {
        let mut guard = self.inner.lock();
        self.reap_if_exited(&mut guard);
        if guard.child.is_some() {
            return Err("Mihomo is already running".into());
        }

        if !mihomo_bin.is_file() {
            return Err(format!(
                "Mihomo binary not found at {}. Run `pnpm prebuild` first.",
                mihomo_bin.display()
            ));
        }

        let mut options = options.clone();
        if options.controller_secret.as_deref().unwrap_or("").is_empty() {
            let nanos = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .map(|d| d.as_nanos())
                .unwrap_or(0);
            options.controller_secret = Some(format!("viasix{nanos:x}"));
        }

        let runtime_yaml = project_runtime_yaml(profile_yaml, &options)
            .map_err(|e| e.contract_code().to_string())?;

        fs::create_dir_all(&guard.work_dir).map_err(io_err)?;
        let config_path = guard.work_dir.join("runtime.yaml");
        fs::write(&config_path, runtime_yaml).map_err(io_err)?;

        let mut command = Command::new(mihomo_bin);
        command
            .arg("-f")
            .arg(&config_path)
            .arg("-d")
            .arg(&guard.work_dir)
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null());

        let child = command.spawn().map_err(|e| {
            format!(
                "failed to spawn mihomo ({}): {e}",
                mihomo_bin.display()
            )
        })?;

        let pid = child.id();
        guard.child = Some(child);
        guard.controller_port = Some(options.controller_port);
        guard.controller_secret = options.controller_secret.clone();
        Ok(CoreStatus {
            running: true,
            pid: Some(pid),
            message: format!(
                "Mihomo started (pid {pid}, controller 127.0.0.1:{})",
                options.controller_port
            ),
            controller_port: Some(options.controller_port),
        })
    }

    pub fn stop(&self) -> Result<CoreStatus, String> {
        let mut guard = self.inner.lock();
        self.reap_if_exited(&mut guard);
        if let Some(mut child) = guard.child.take() {
            let _ = child.kill();
            let _ = child.wait();
        }
        guard.controller_port = None;
        guard.controller_secret = None;
        Ok(CoreStatus {
            running: false,
            pid: None,
            message: "Mihomo stopped".into(),
            controller_port: None,
        })
    }

    fn reap_if_exited(&self, guard: &mut Inner) {
        if let Some(child) = guard.child.as_mut() {
            match child.try_wait() {
                Ok(Some(_)) => {
                    guard.child = None;
                    guard.controller_port = None;
                    guard.controller_secret = None;
                }
                Ok(None) => {}
                Err(_) => {
                    guard.child = None;
                    guard.controller_port = None;
                    guard.controller_secret = None;
                }
            }
        }
    }
}

fn io_err(err: io::Error) -> String {
    err.to_string()
}

pub type SharedCore = Arc<CoreRuntime>;
