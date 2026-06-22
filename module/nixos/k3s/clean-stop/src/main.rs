//! k3s-clean-stop — typed k3s `ExecStopPost` reaper (replaces the writeShellScript).
//!
//! On k3s stop, `KillMode=process` (set deliberately, as upstream does — k3s
//! manages its embedded containerd + task-shims as cgroup-delegated children)
//! kills ONLY the k3s process and leaves orphaned:
//!   * containerd + its `containerd-shim*` processes, which tear down the
//!     shared overlay snapshot mounts while the next containerd races to
//!     re-mount the SAME snapshots → the ENOENT "snapshot corruption" class;
//!   * the actual pod WORKLOAD processes the shims managed — they re-parent to
//!     init and keep running, still holding their data-dir POSIX flocks, so the
//!     next start's fresh pod CrashLoops with "resource temporarily
//!     unavailable" on its lock (observed on rio's vmsingle/victoria-logs/
//!     vector after a k3s bounce, 2026-06-22).
//!
//! This reaper, run as `ExecStopPost` AFTER the main k3s process exits:
//!   1. reaps the orphaned containerd + `containerd-shim*` processes,
//!   2. (default) reaps orphaned pod workloads via the kubepods `cgroup.kill`
//!      (cgroup v2 — one write recursively SIGKILLs the pod-cgroup subtree),
//!   3. lazily unmounts the kubelet/agent mount tree, deepest-first,
//! so the next start finds a clean tree + released locks. Pure syscalls +
//! `/proc` + `/sys` reads — no subprocess, no `PATH` dependency, no shell. It
//! always exits 0: a clean stop must never fail the unit.

use std::fs;
use std::path::{Path, PathBuf};
use std::thread::sleep;
use std::time::Duration;

#[cfg(target_os = "linux")]
use std::ffi::CString;
#[cfg(target_os = "linux")]
use std::os::raw::c_char;

extern "C" {
    fn kill(pid: i32, sig: i32) -> i32;
}

// umount2(2) is Linux-only; this reaper only ever runs on k3s (Linux) nodes.
#[cfg(target_os = "linux")]
extern "C" {
    fn umount2(target: *const c_char, flags: i32) -> i32;
}

const SIGTERM: i32 = 15;
const SIGKILL: i32 = 9;
#[cfg(target_os = "linux")]
const MNT_FORCE: i32 = 1;
#[cfg(target_os = "linux")]
const MNT_DETACH: i32 = 2;

#[derive(Debug, PartialEq, Eq)]
struct Config {
    reap_grace_secs: u64,
    reap_workloads: bool,
    cgroup_root: String,
    mount_prefixes: Vec<String>,
}

impl Default for Config {
    fn default() -> Self {
        Config {
            reap_grace_secs: 3,
            reap_workloads: true,
            cgroup_root: "/sys/fs/cgroup".to_string(),
            mount_prefixes: Vec::new(),
        }
    }
}

fn parse_args<I: Iterator<Item = String>>(mut it: I) -> Config {
    let mut cfg = Config::default();
    while let Some(a) = it.next() {
        match a.as_str() {
            "--reap-grace" => {
                if let Some(v) = it.next() {
                    cfg.reap_grace_secs = v.parse().unwrap_or(cfg.reap_grace_secs);
                }
            }
            "--no-reap-workloads" => cfg.reap_workloads = false,
            "--cgroup-root" => {
                if let Some(v) = it.next() {
                    cfg.cgroup_root = v;
                }
            }
            "--mount-prefix" => {
                if let Some(v) = it.next() {
                    cfg.mount_prefixes.push(v);
                }
            }
            _ => {}
        }
    }
    cfg
}

/// True if a process with this `comm` (from `/proc/<pid>/comm`) is k3s's
/// containerd or one of its task-shims — the processes `KillMode=process`
/// orphans that hold the snapshot mounts.
fn is_containerd_proc(comm: &str) -> bool {
    let c = comm.trim();
    c == "containerd" || c.starts_with("containerd-shim")
}

/// Mountpoints under any of `prefixes`, deepest-first (reverse-sorted), parsed
/// from the contents of `/proc/self/mounts`. Deepest-first so a parent is
/// unmounted only after its children.
fn mounts_to_unmount(mounts: &str, prefixes: &[String]) -> Vec<String> {
    let mut out: Vec<String> = mounts
        .lines()
        .filter_map(|l| l.split_whitespace().nth(1)) // field 2 = mountpoint
        .filter(|mp| prefixes.iter().any(|p| mp.starts_with(p.as_str())))
        .map(|s| s.to_string())
        .collect();
    out.sort();
    out.reverse(); // deepest-first
    out.dedup();
    out
}

/// `cgroup.kill` files of every top-level kubepods cgroup under `cgroup_root`
/// (cgroup v2). Writing `1` to one recursively SIGKILLs that pod-cgroup
/// subtree. A non-kubepods cgroup (e.g. `system.slice`) is never touched.
fn kubepods_kill_files(cgroup_root: &Path) -> Vec<PathBuf> {
    let mut v = Vec::new();
    if let Ok(rd) = fs::read_dir(cgroup_root) {
        for e in rd.flatten() {
            if e.file_name().to_string_lossy().starts_with("kubepods") {
                let kill = e.path().join("cgroup.kill");
                if kill.exists() {
                    v.push(kill);
                }
            }
        }
    }
    v.sort();
    v
}

fn each_pid() -> Vec<i32> {
    let mut pids = Vec::new();
    if let Ok(rd) = fs::read_dir("/proc") {
        for e in rd.flatten() {
            if let Ok(pid) = e.file_name().to_string_lossy().parse::<i32>() {
                pids.push(pid);
            }
        }
    }
    pids
}

fn proc_comm(pid: i32) -> Option<String> {
    fs::read_to_string(format!("/proc/{pid}/comm"))
        .ok()
        .map(|s| s.trim().to_string())
}

fn signal(pid: i32, sig: i32) {
    // SAFETY: kill(2) on an i32 pid + signal; failure (ESRCH etc.) is ignored.
    unsafe {
        let _ = kill(pid, sig);
    }
}

#[cfg(target_os = "linux")]
fn umount_lazy(path: &str) {
    if let Ok(c) = CString::new(path) {
        // SAFETY: umount2(2) with a NUL-terminated path; failure is ignored
        // (a clean stop must never fail the unit).
        unsafe {
            let _ = umount2(c.as_ptr(), MNT_DETACH | MNT_FORCE);
        }
    }
}

// umount2(2) is Linux-only; the stub keeps the crate buildable + unit-testable
// on any host (the binary is only ever deployed to k3s Linux nodes).
#[cfg(not(target_os = "linux"))]
fn umount_lazy(_path: &str) {}

fn reap_containerd(grace: Duration) {
    let targets: Vec<i32> = each_pid()
        .into_iter()
        .filter(|p| proc_comm(*p).map(|c| is_containerd_proc(&c)).unwrap_or(false))
        .collect();
    for p in &targets {
        signal(*p, SIGTERM);
    }
    sleep(grace);
    for p in &targets {
        if Path::new(&format!("/proc/{p}")).exists() {
            signal(*p, SIGKILL);
        }
    }
}

fn reap_workloads(cgroup_root: &Path) {
    for kf in kubepods_kill_files(cgroup_root) {
        let _ = fs::write(&kf, b"1"); // cgroup v2: SIGKILLs the whole subtree
    }
}

fn unmount_tree(prefixes: &[String]) {
    let mounts = fs::read_to_string("/proc/self/mounts").unwrap_or_default();
    for mp in mounts_to_unmount(&mounts, prefixes) {
        umount_lazy(&mp);
    }
}

fn main() {
    let cfg = parse_args(std::env::args().skip(1));
    reap_containerd(Duration::from_secs(cfg.reap_grace_secs));
    if cfg.reap_workloads {
        reap_workloads(Path::new(&cfg.cgroup_root));
    }
    unmount_tree(&cfg.mount_prefixes);
    // A clean stop must never fail the unit.
    std::process::exit(0);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn containerd_match() {
        assert!(is_containerd_proc("containerd"));
        assert!(is_containerd_proc("containerd-shim-runc-v2"));
        assert!(is_containerd_proc("  containerd\n"));
        assert!(!is_containerd_proc("k3s-server"));
        assert!(!is_containerd_proc("kubelet"));
        assert!(!is_containerd_proc("k3s-clean-stop")); // never reaps itself
    }

    #[test]
    fn mounts_deepest_first_and_filtered() {
        let mounts = "\
proc /proc proc rw 0 0
tmpfs /var/lib/kubelet/pods/x/volumes/y tmpfs rw 0 0
tmpfs /var/lib/kubelet tmpfs rw 0 0
tmpfs /run/k3s/abc tmpfs rw 0 0
ext4 /home ext4 rw 0 0
";
        let got = mounts_to_unmount(
            mounts,
            &["/var/lib/kubelet".to_string(), "/run/k3s".to_string()],
        );
        assert_eq!(
            got,
            vec![
                "/var/lib/kubelet/pods/x/volumes/y".to_string(), // deepest first
                "/var/lib/kubelet".to_string(),
                "/run/k3s/abc".to_string(),
            ]
        );
        assert!(!got.iter().any(|m| m == "/home" || m == "/proc"));
    }

    #[test]
    fn kubepods_discovery_ignores_other_slices() {
        let tmp =
            std::env::temp_dir().join(format!("k3s-clean-stop-cg-{}", std::process::id()));
        let kp = tmp.join("kubepods.slice");
        fs::create_dir_all(&kp).unwrap();
        fs::write(kp.join("cgroup.kill"), b"0").unwrap();
        let sys = tmp.join("system.slice");
        fs::create_dir_all(&sys).unwrap();
        fs::write(sys.join("cgroup.kill"), b"0").unwrap(); // must be ignored

        let found = kubepods_kill_files(&tmp);
        assert_eq!(found.len(), 1, "only the kubepods slice's cgroup.kill");
        assert!(found[0].ends_with("kubepods.slice/cgroup.kill"));
        let _ = fs::remove_dir_all(&tmp);
    }

    #[test]
    fn args_parse_full() {
        let cfg = parse_args(
            [
                "--reap-grace",
                "5",
                "--no-reap-workloads",
                "--mount-prefix",
                "/a",
                "--mount-prefix",
                "/b",
                "--cgroup-root",
                "/cg",
            ]
            .iter()
            .map(|s| s.to_string()),
        );
        assert_eq!(cfg.reap_grace_secs, 5);
        assert!(!cfg.reap_workloads);
        assert_eq!(cfg.mount_prefixes, vec!["/a".to_string(), "/b".to_string()]);
        assert_eq!(cfg.cgroup_root, "/cg");
    }

    #[test]
    fn args_parse_defaults() {
        let cfg = parse_args(std::iter::empty());
        assert_eq!(cfg.reap_grace_secs, 3);
        assert!(cfg.reap_workloads); // default ON
        assert_eq!(cfg.cgroup_root, "/sys/fs/cgroup");
        assert!(cfg.mount_prefixes.is_empty());
    }
}
