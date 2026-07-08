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
    for p in POLICY['blocked_paths']:
        if p == path or (p.endswith('*') and path.startswith(p[:-1])):
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
    for d in POLICY['blocked_domains']:
        if d == domain or (d.startswith('*.') and domain.endswith(d[1:])):
            return False
        if d.endswith('.*') and domain.startswith(d[:-2]):
            return False
    return True

def audit_hook(event, args):
    findings = []
    if event == 'open':
        path = args[0] if args else ''
        if not check_path(path):
            findings.append(('path', path, True, f'DENY: open {{path}}'))
            print(f'[AEGISRUN] DENY open {{path}}')
            raise PermissionError(f'AegisRun blocked: {{path}}')
    elif event == 'os.environ.__getitem__':
        var = args[0] if args else ''
        if not check_env(var):
            findings.append(('env', var, True, f'DENY: getenv {{var}}'))
            print(f'[AEGISRUN] DENY getenv {{var}}')
            raise KeyError(f'AegisRun blocked env: {{var}}')
    elif event == 'subprocess.Popen':
        cmd = str(args[0] if args else '')
        print(f'[AEGISRUN] INFO shell: {{cmd[:80]}}')
        findings.append(('shell', cmd[:80], False, f'INFO: {{cmd[:80]}}'))
        for part in cmd.split():
            if part.startswith('http://') or part.startswith('https://'):
                for d in POLICY['blocked_domains']:
                    if d in part:
                        findings.append(('network', part, True, f'DENY: {{part}}'))
                        print(f'[AEGISRUN] DENY network {{part}}')
                        return False
    elif event == 'socket.connect':
        addr = str(args[0] if args else '')
        host = addr.split(',')[0].strip("'() ").strip('"')
        if not check_domain(host):
            findings.append(('network', host, True, f'DENY: socket {{host}}'))
            print(f'[AEGISRUN] DENY socket {{host}}')
    return None

sys.addaudithook(audit_hook)

# 加载并执行目标脚本
script_path = sys.argv[1] if len(sys.argv) > 1 else None
if script_path:
    with open(script_path, encoding='utf-8') as f:
        code = f.read()
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
        "blocked_paths": sanitize(policy.blocked_paths.clone()),
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
