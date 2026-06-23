// ============================================================
// AegisRun v0.3.0 — DNS劫持检测 + IP黑名单
// ============================================================

pub struct IpBlockRule { prefix : String; reason : String }
pub struct IpBlacklist {
  exact_ips : @hashmap.HashMap[String, String]
  cidr_prefixes : Array[IpBlockRule]
  suspicious_asn : Array[String]
}
pub struct DnsCheckResult {
  domain : String; resolved_ip : String; expected_ip : String
  ip_in_blacklist : Bool; possible_hijack : Bool; hosts_file_tampered : Bool
}

pub fn new_ip_blacklist() -> IpBlacklist {
  let bl : IpBlacklist = { exact_ips: @hashmap.HashMap([], capacity=64), cidr_prefixes: [], suspicious_asn: [] }
  load_default_ip_rules(bl)
  bl
}

fn load_default_ip_rules(bl : IpBlacklist) -> Unit {
  // 1. RFC 1918 私有地址
  bl.cidr_prefixes.push({prefix: "10.", reason: "private-rfc1918"})
  bl.cidr_prefixes.push({prefix: "172.16.", reason: "private-rfc1918"})
  bl.cidr_prefixes.push({prefix: "192.168.", reason: "private-rfc1918"})
  // 2. 回环
  bl.exact_ips.set("127.0.0.1", "loopback")
  bl.exact_ips.set("0.0.0.0", "null-address")
  // 3. C2托管 (abuse.ch / AlienVault OTX)
  bl.cidr_prefixes.push({prefix: "5.45.", reason: "known-c2"})
  bl.cidr_prefixes.push({prefix: "185.130.", reason: "known-c2"})
  bl.cidr_prefixes.push({prefix: "194.26.", reason: "known-c2"})
  bl.cidr_prefixes.push({prefix: "45.155.", reason: "known-c2"})
  // 4. Tor出口
  bl.cidr_prefixes.push({prefix: "185.220.", reason: "tor-exit"})
  bl.cidr_prefixes.push({prefix: "23.129.", reason: "tor-exit"})
  bl.cidr_prefixes.push({prefix: "51.75.", reason: "tor-exit"})
  // 5. 钓鱼/恶意软件
  bl.cidr_prefixes.push({prefix: "91.121.", reason: "phishing"})
  bl.cidr_prefixes.push({prefix: "37.59.", reason: "malware"})
  // 6. 链路本地/组播
  bl.cidr_prefixes.push({prefix: "169.254.", reason: "link-local"})
  bl.cidr_prefixes.push({prefix: "224.", reason: "multicast"})
}

pub fn check_ip(bl : IpBlacklist, ip : String) -> Result[Unit, String] {
  match bl.exact_ips.get(ip) {
    Some(reason) => return Err("IP " + ip + " blacklisted: " + reason)
    None => ()
  }
  for rule in bl.cidr_prefixes {
    if ip.has_prefix(rule.prefix) {
      return Err("IP " + ip + " matches " + rule.prefix + " (" + rule.reason + ")")
    }
  }
  Ok(())
}

pub fn is_internal_ip(ip : String) -> Bool {
  ip.has_prefix("10.") || ip.has_prefix("172.16.") || ip.has_prefix("192.168.") || ip == "127.0.0.1" || ip.has_prefix("169.254.")
}

// DNS劫持综合检测
pub fn detect_dns_hijack(domain : String, resolved_ip : String, ip_bl : IpBlacklist, hosts_content : String) -> DnsCheckResult {
  let blocked = check_ip(ip_bl, resolved_ip)
  let hosts_ok = has_hosts_entry(hosts_content, domain, resolved_ip)
  let ip_blocked = match blocked { Err(_) => true; Ok(_) => false }
  let suspicious_redirect = hosts_ok && is_internal_ip(resolved_ip)
  {
    domain, resolved_ip, expected_ip: "",
    ip_in_blacklist: ip_blocked,
    possible_hijack: ip_blocked || suspicious_redirect,
    hosts_file_tampered: hosts_ok,
  }
}

fn has_hosts_entry(content : String, domain : String, expected_ip : String) -> Bool {
  let mut current = ""
  for i = 0; i < content.length(); i = i + 1 {
    if content[i] == '\n' || content[i] == '\r' {
      if current != "" && !current.has_prefix("#") && current.contains(domain) && !current.contains(expected_ip) {
        return true
      }
      current = ""
      if content[i] == '\r' && i + 1 < content.length() && content[i+1] == '\n' { continue }
    } else {
      current = current + content[i:i+1].to_owned()
    }
  }
  if current != "" && !current.has_prefix("#") && current.contains(domain) && !current.contains(expected_ip) { return true }
  false
}

// 检查hosts文件完整性
pub fn check_hosts_integrity(hosts_content : String) -> Array[String] {
  let suspicious : Array[String] = []
  let domains = ["github.com","google.com","microsoft.com","apple.com","paypal.com","alipay.com","openai.com","anthropic.com","npmjs.org","pypi.org"]
  let mut current = ""
  for i = 0; i < hosts_content.length(); i = i + 1 {
    if hosts_content[i] == '\n' || hosts_content[i] == '\r' {
      if current != "" && !current.has_prefix("#") {
        for d in domains {
          if current.contains(d) {
            let sp = current.find(" ")
            match sp { Some(pos) => { let ip = current[:pos].to_owned(); if is_internal_ip(ip) { suspicious.push("SUSPICIOUS: " + d + " -> " + ip) } }; None => () }
          }
        }
      }
      current = ""
    } else { current = current + hosts_content[i:i+1].to_owned() }
  }
  suspicious
}
