// ============================================================
// AegisRun Runtime Sandbox Monitor — 运行时行为监控
// 参考: SkillDetonate (arXiv 2607.02357)
//       运行时执行脚本并通过 audit hook 拦截敏感操作
// ============================================================
//
// 原理:
//   1. 注入 Python audit hook，hook open/env/network/subprocess
//   2. 在目标脚本执行前预检查，DENY 则阻止操作
//   3. 收集所有敏感操作记录，合并到静态扫描结果
//
// 用法:
//   aegisrun sandbox-run malicious.py

use std::io::Write;
use std::process::{Command, Stdio};
use super::Policy;

/// 运行时监控结果
#[derive(Debug)]
pub struct RuntimeFinding {
    pub line: usize,         // 近似行号（来自 stack trace）
    pub kind: String,        // "file"/"env"/"network"/"shell"
    pub value: String,       // 操作目标
    pub blocked: bool,       // 是否被拦截
    pub detail: String,      // 详细说明
}

/// 生成 Python audit hook 包装脚本
fn generate_audit_wrapper(policy_json: &str) -> String {
    format!(r##"
import sys, os, json, traceback

# 从 AegisRun 加载策略
POLICY = json.loads('''{policy_json}''')

def check_path(path):
    path = str(path).replace('\\', '/')
    for p in POLICY['blocked_paths']:
        p = str(p).replace('\\', '/')
        if p == path:
            return False
        if p.startswith('*.') and path.endswith(p[1:]):
            return False
    for p in POLICY.get('path_prefixes', []):
        p = str(p).replace('\\', '/')
        if p and path.startswith(p):
            return False
    return True

def check_env(var):
    for p in POLICY['blocked_env_patterns']:
        if p == '*' or p.upper() in var.upper():
            return False
    for kw in ['KEY','SECRET','TOKEN','PASSWORD','CREDENTIAL']:
        if kw in var.upper():
            return False
    return True

def check_domain(domain):
    domain = str(domain).lower().strip()
    for d in POLICY['blocked_domains']:
        d = str(d).lower()
        if d == domain:
            return False
        if d.endswith('.*') and domain.startswith(d[:-2]):
            return False
    for d in POLICY.get('domain_suffixes', []):
        d = str(d).lower()
        if d.startswith('*.') and domain.endswith(d[1:]):
            return False
    return True

def deny(kind, value):
    print(f'[AEGISRUN] DENY {{kind}} {{value}}')
    raise PermissionError(f'AegisRun blocked {{kind}}: {{value}}')

def extract_host(value):
    text = str(value).strip("'()[] ")
    if ',' in text:
        text = text.split(',')[0].strip("'()[] ")
    if text.startswith(('http://', 'https://')):
        text = text.split('://', 1)[1].split('/', 1)[0]
    if ':' in text and not text.count(':') > 1:
        text = text.split(':', 1)[0]
    return text.strip('"\' ')

_ORIG_GETENV = os.getenv
_ORIG_ENVIRON = os.environ

def guarded_getenv(var, default=None):
    if not check_env(var):
        deny('env', var)
    return _ORIG_GETENV(var, default)

class GuardedEnviron:
    def __init__(self, inner):
        self._inner = inner
    def __getitem__(self, key):
        if not check_env(key):
            deny('env', key)
        return self._inner[key]
    def get(self, key, default=None):
        if not check_env(key):
            deny('env', key)
        return self._inner.get(key, default)
    def __setitem__(self, key, value):
        self._inner[key] = value
    def __delitem__(self, key):
        del self._inner[key]
    def __iter__(self):
        return iter(self._inner)
    def __len__(self):
        return len(self._inner)
    def __contains__(self, key):
        return key in self._inner
    def keys(self):
        return self._inner.keys()
    def items(self):
        return self._inner.items()
    def values(self):
        return self._inner.values()

os.getenv = guarded_getenv
os.environ = GuardedEnviron(_ORIG_ENVIRON)

import socket as _aegis_socket
import subprocess as _aegis_subprocess

_ORIG_CREATE_CONNECTION = _aegis_socket.create_connection
_ORIG_SOCKET_CONNECT = _aegis_socket.socket.connect
_ORIG_POPEN = _aegis_subprocess.Popen

def guarded_create_connection(address, *args, **kwargs):
    host = address[0] if isinstance(address, tuple) and address else extract_host(address)
    if not check_domain(host):
        deny('network', host)
    return _ORIG_CREATE_CONNECTION(address, *args, **kwargs)

def guarded_socket_connect(self, address):
    host = address[0] if isinstance(address, tuple) and address else extract_host(address)
    if not check_domain(host):
        deny('network', host)
    return _ORIG_SOCKET_CONNECT(self, address)

def guarded_popen(*popen_args, **popen_kwargs):
    cmd = str(popen_args[0] if popen_args else popen_kwargs.get('args', ''))
    print(f'[AEGISRUN] INFO shell {{cmd[:80]}}')
    for part in cmd.replace('[', ' ').replace(']', ' ').replace(',', ' ').split():
        target = part.strip('"\'')
        if target.startswith(('http://', 'https://')):
            host = extract_host(target)
            if not check_domain(host):
                deny('network', host)
        if (target.startswith('/') or target.startswith('~') or ':\\' in target) and not check_path(target):
            deny('path', target)
    return _ORIG_POPEN(*popen_args, **popen_kwargs)

_aegis_socket.create_connection = guarded_create_connection
_aegis_socket.socket.connect = guarded_socket_connect
_aegis_subprocess.Popen = guarded_popen

def audit_hook(event, args):
    if event == 'open':
        path = args[0] if args else ''
        if not check_path(path):
            deny('path', path)
    elif event == 'os.environ.__getitem__':
        var = args[0] if args else ''
        if not check_env(var):
            deny('env', var)
    elif event == 'subprocess.Popen':
        cmd = str(args[0] if args else '')
        print(f'[AEGISRUN] INFO shell: {{cmd[:80]}}')
        for part in cmd.replace('[', ' ').replace(']', ' ').replace(',', ' ').split():
            target = part.strip('"\'')
            if target.startswith(('http://', 'https://')):
                host = extract_host(target)
                if not check_domain(host):
                    deny('network', host)
            if (target.startswith('/') or target.startswith('~') or ':\\' in target) and not check_path(target):
                deny('path', target)
    elif event == 'socket.connect':
        addr = args[1] if len(args) > 1 else (args[0] if args else '')
        if isinstance(addr, tuple) and addr:
            host = str(addr[0])
        else:
            host = extract_host(addr)
        if not check_domain(host):
            deny('network', host)
    return None

sys.addaudithook(audit_hook)

# 加载并执行目标脚本
script_path = sys.argv[1] if len(sys.argv) > 1 else None
if script_path:
    for enc in ['utf-8', 'utf-16', 'gbk', 'latin-1']:
        try: f = open(script_path, encoding=enc); code = f.read(); f.close(); break
        except: continue
    try:
        exec(code)
    except (PermissionError, KeyError) as e:
        print(f'[AEGISRUN] BLOCKED: {{e}}')
    except Exception as e:
        print(f'[AEGISRUN] Script error: {{e}}')
"##, policy_json = policy_json)
}

/// 在沙箱中运行脚本并返回运行时发现
pub fn run_sandbox(script_path: &str, policy: &Policy) -> Vec<RuntimeFinding> {
    let mut findings = Vec::new();

    // 将策略序列化为 JSON（替换 \ 为 / 避免 Python 转义问题）
    let sanitize = |v: Vec<String>| -> Vec<String> {
        v.iter().map(|s| s.replace("\\", "/")).collect()
    };
    let policy_json = serde_json::json!({
        "blocked_domains": policy.blocked_domains,
        "domain_suffixes": policy.domain_suffixes,
        "blocked_paths": sanitize(policy.blocked_paths.clone()),
        "path_prefixes": sanitize(policy.path_prefixes.clone()),
        "blocked_env_patterns": policy.blocked_env_patterns,
    });

    // 生成审计包装器
    let wrapper = generate_audit_wrapper(&policy_json.to_string());

    // 写入临时审计文件
    let tmp_path = std::env::temp_dir().join("aegisrun_audit_wrapper.py");
    let mut tmp_file = std::fs::File::create(&tmp_path).expect("Failed to create audit wrapper");
    tmp_file.write_all(wrapper.as_bytes()).expect("Failed to write audit wrapper");

    // 运行: python -B audit_wrapper.py target_script.py
    let python_cmd = if cfg!(windows) { "python" } else { "python3" };
    let output = Command::new(python_cmd)
        .arg("-B")
        .arg(&tmp_path)
        .arg(script_path)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output();

    // 解析输出
    if let Ok(output) = output {
        let stdout = String::from_utf8_lossy(&output.stdout);
        let stderr = String::from_utf8_lossy(&output.stderr);

        for line in stdout.lines() {
            if line.starts_with("[AEGISRUN] DENY") {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() >= 3 {
                    let kind = parts[2].to_string();
                    let value = parts[3..].join(" ");
                    findings.push(RuntimeFinding {
                        line: 0,
                        kind,
                        value,
                        blocked: true,
                        detail: line.to_string(),
                    });
                }
            } else if line.starts_with("[AEGISRUN] INFO") {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() >= 3 {
                    let kind = parts[2].to_string();
                    let value = parts[3..].join(" ");
                    findings.push(RuntimeFinding {
                        line: 0,
                        kind,
                        value,
                        blocked: false,
                        detail: line.to_string(),
                    });
                }
            }
        }
        if !stderr.is_empty() {
            eprintln!("[sandbox-run] stderr: {}", stderr);
        }
    } else {
        eprintln!("[sandbox-run] Failed to execute script: {}", script_path);
    }

    // 清理
    let _ = std::fs::remove_file(&tmp_path);

    findings
}

/// 合并静态扫描和运行时监控结果
pub fn merge_findings(
    static_findings: &[super::ScanFinding],
    runtime_findings: &[RuntimeFinding],
) -> Vec<super::ScanFinding> {
    let mut merged: Vec<super::ScanFinding> = Vec::new();
    let mut seen = std::collections::HashSet::new();

    // 先加静态发现的（有行号）
    for f in static_findings {
        let key = format!("{}:{}", f.kind, f.value);
        if seen.insert(key) {
            merged.push(f.clone());
        }
    }

    // 再加运行时发现的（去重）
    for f in runtime_findings {
        let key = format!("runtime-{}:{}", f.kind, f.value);
        if seen.insert(key) {
            merged.push(super::ScanFinding {
                line: f.line,
                kind: format!("runtime-{}", f.kind),
                value: f.value.clone(),
                blocked: f.blocked,
            });
        }
    }

    merged
}
