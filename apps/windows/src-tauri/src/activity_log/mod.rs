//! In-process activity log shared with the UI (macOS AppState.logs analogue).

use serde::{Deserialize, Serialize};
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ActivityEntry {
    pub id: u64,
    pub at: u64,
    pub level: String,
    pub source: String,
    pub message: String,
}

#[derive(Debug, Default)]
pub struct ActivityLog {
    next_id: u64,
    entries: Vec<ActivityEntry>,
    capacity: usize,
}

impl ActivityLog {
    pub fn new(capacity: usize) -> Self {
        Self {
            next_id: 1,
            entries: Vec::new(),
            capacity: capacity.max(1),
        }
    }

    pub fn push(&mut self, level: &str, source: &str, message: impl Into<String>) -> ActivityEntry {
        let entry = ActivityEntry {
            id: self.next_id,
            at: now_ms(),
            level: level.to_string(),
            source: source.to_string(),
            message: message.into(),
        };
        self.next_id = self.next_id.saturating_add(1);
        self.entries.push(entry.clone());
        if self.entries.len() > self.capacity {
            let overflow = self.entries.len() - self.capacity;
            self.entries.drain(0..overflow);
        }
        entry
    }

    pub fn list(&self) -> Vec<ActivityEntry> {
        self.entries.clone()
    }

    pub fn clear(&mut self) {
        self.entries.clear();
    }
}

fn now_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as u64)
        .unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn respects_capacity() {
        let mut log = ActivityLog::new(3);
        log.push("info", "app", "a");
        log.push("info", "app", "b");
        log.push("info", "app", "c");
        log.push("info", "app", "d");
        let list = log.list();
        assert_eq!(list.len(), 3);
        assert_eq!(list[0].message, "b");
        assert_eq!(list[2].message, "d");
    }
}
