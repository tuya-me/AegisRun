// ============================================================
// AegisRun v0.7.0 — 默认策略数据（唯一维护点）
// 所有预设规则集中在此文件，修改规则只需改这一个文件
// ============================================================

// ── 域名黑名单 ──

///|
pub fn default_domain_blacklist() -> Array[(String, String)] {
  [
    ("evil.com", "known-malware-c2"),
    ("stealer.cc", "data-exfil-host"),
    ("192.168.*", "internal-network"),
    ("10.*", "private-network"),
    ("172.16.*", "private-network"),
    ("127.0.0.1", "loopback"),
    ("localhost", "loopback"),
  ]
}

// ── 域名后缀（*.cn → www.example.cn）──

///|
pub fn default_domain_suffixes() -> Array[String] {
  ["*.cn", "*.ru", "*.tk"]
}

// ── IP 前缀（192.168.* → 192.168.1.1）──

///|
pub fn default_ip_prefixes() -> Array[String] {
  ["10.", "172.", "192.168."]
}

// ── 域名白名单 ──

///|
pub fn default_domain_whitelist() -> Array[(String, String)] {
  [
    ("api.github.com", "GitHub-API"),
    ("wttr.in", "weather-API"),
  ]
}

// ── 敏感路径（Linux / macOS / Windows）──

///|
pub fn default_sensitive_paths() -> Array[String] {
  [
    // Linux 系统文件
    "/etc/passwd", "/etc/shadow", "/etc/ssl/private/", "/var/run/secrets/",
    "/proc/self/environ", "/root/.bash_history", "/var/log/auth.log",
    // 开发者凭证
    "~/.ssh/", "~/.aws/", "~/.gnupg/", "~/.kube/config",
    // macOS
    "~/Library/Keychains/",
    "~/Library/Application Support/Google/Chrome/",
    "~/Library/Application Support/Firefox/",
    // Windows
    "C:\\Windows\\System32\\config\\",
    "C:\\Users\\*\\.kube\\config",
    "C:\\Users\\*\\AppData\\Roaming\\npm\\npmrc",
    "C:\\ProgramData\\Docker\\config.json",
    // 高危文件类型
    ".pem", ".key", ".env", "config.yaml",
  ]
}

// ── 敏感环境变量模式 ──

///|
pub fn default_env_patterns() -> Array[String] {
  [
    // AI 服务
    "OPENAI_API_KEY", "ANTHROPIC_API_KEY", "COHERE_API_KEY", "DEEPSEEK_API_KEY",
    "GOOGLE_AI_API_KEY",
    // 云平台
    "AWS_SECRET", "AWS_ACCESS_KEY", "GCP_", "AZURE_",
    "ALIBABA_CLOUD", "TENCENT_CLOUD", "HUAWEI_CLOUD",
    // 数据库
    "DATABASE_URL", "REDIS_URL", "MONGODB_URI", "RABBITMQ_URL",
    "POSTGRES_", "MYSQL_",
    // CI/CD
    "GITHUB_TOKEN", "GITLAB_TOKEN", "BITBUCKET_",
    "CIRCLECI_", "JENKINS_", "TRAVIS_",
    // 通信/支付
    "SENDGRID_API", "TWILIO_", "STRIPE_",
    "SLACK_TOKEN", "SLACK_WEBHOOK", "NOTION_TOKEN",
    // 容器/K8s
    "DOCKER_PASSWORD", "DOCKER_AUTH", "KUBECONFIG", "KUBE_",
    // 加密/证书
    "PRIVATE_KEY", "SSL_KEY", "CERTIFICATE",
    "PGP_", "GPG_", "NPM_TOKEN", "PYPI_TOKEN",
  ]
}

// ── 环境变量关键词（检测 KEY/SECRET/TOKEN 等通用模式）──

///|
pub fn env_keywords() -> Array[String] {
  ["KEY", "SECRET", "TOKEN", "PASSWORD", "CREDENTIAL"]
}

// ── 超时/内存默认值 ──

///|
pub fn default_timeout_ms() -> Int { 30000 }

///|
pub fn default_memory_kb() -> Int { 262144 }
