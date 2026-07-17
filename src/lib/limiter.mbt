// AegisRun v1.3 — 3D Concurrency Limiter

///|
pub struct LimiterConfig {
  max_total : Int
  max_per_tool : Int
  max_per_session : Int
  queue_size : Int
  queue_timeout_ms : Int
}

///|
pub struct ConcurrencyLimiter {
  config : LimiterConfig
  mut global_active : Int
  tool_active : @hashmap.HashMap[String, Int]
  session_active : @hashmap.HashMap[String, Int]
  tool_limits : @hashmap.HashMap[String, Int]
  mut queue_length : Int
  mut total_allowed : Int
  mut total_rejected : Int
}

///|
pub fn new_limiter(config : LimiterConfig) -> ConcurrencyLimiter {
  {
    config,
    global_active: 0,
    tool_active: @hashmap.HashMap([], capacity=16),
    session_active: @hashmap.HashMap([], capacity=16),
    tool_limits: @hashmap.HashMap([], capacity=8),
    queue_length: 0,
    total_allowed: 0,
    total_rejected: 0,
  }
}

///|
pub fn default_limiter() -> ConcurrencyLimiter {
  new_limiter({
    max_total: 100,
    max_per_tool: 10,
    max_per_session: 5,
    queue_size: 200,
    queue_timeout_ms: 60000,
  })
}

///|
pub fn ConcurrencyLimiter::set_tool_limit(
  self : ConcurrencyLimiter,
  tool_id : String,
  limit : Int,
) -> Unit {
  self.tool_limits.set(tool_id, limit)
}

///|
fn ConcurrencyLimiter::get_tool_limit(
  self : ConcurrencyLimiter,
  tool_id : String,
) -> Int {
  match self.tool_limits.get(tool_id) {
    Some(v) => v
    None => self.config.max_per_tool
  }
}

///|
pub fn ConcurrencyLimiter::acquire(
  self : ConcurrencyLimiter,
  tool_id : String,
  session_id : String,
) -> Result[String, String] {
  if self.global_active >= self.config.max_total {
    if self.queue_length >= self.config.queue_size {
      self.total_rejected = self.total_rejected + 1
      return Err("REJECTED: global limit " + self.config.max_total.to_string())
    }
    self.queue_length = self.queue_length + 1
    return Err("QUEUED: position " + self.queue_length.to_string())
  }
  let tool_limit = self.get_tool_limit(tool_id)
  let current_tool = match self.tool_active.get(tool_id) {
    Some(v) => v
    None => 0
  }
  if current_tool >= tool_limit {
    self.total_rejected = self.total_rejected + 1
    return Err(
      "REJECTED: tool '" + tool_id + "' limit " + tool_limit.to_string(),
    )
  }
  let current_session = match self.session_active.get(session_id) {
    Some(v) => v
    None => 0
  }
  if current_session >= self.config.max_per_session {
    self.total_rejected = self.total_rejected + 1
    return Err(
      "REJECTED: session limit " + self.config.max_per_session.to_string(),
    )
  }
  self.global_active = self.global_active + 1
  self.tool_active.set(tool_id, current_tool + 1)
  self.session_active.set(session_id, current_session + 1)
  self.total_allowed = self.total_allowed + 1
  Ok(
    "ACQUIRED: " +
    self.global_active.to_string() +
    "/" +
    self.config.max_total.to_string(),
  )
}

///|
pub fn ConcurrencyLimiter::release(
  self : ConcurrencyLimiter,
  tool_id : String,
  session_id : String,
) -> Unit {
  if self.global_active > 0 {
    self.global_active = self.global_active - 1
  }
  let ct = match self.tool_active.get(tool_id) {
    Some(v) => v
    None => 0
  }
  if ct > 0 {
    self.tool_active.set(tool_id, ct - 1)
  }
  let cs = match self.session_active.get(session_id) {
    Some(v) => v
    None => 0
  }
  if cs > 0 {
    self.session_active.set(session_id, cs - 1)
  }
  if self.queue_length > 0 {
    self.queue_length = self.queue_length - 1
  }
}

///|
pub fn ConcurrencyLimiter::limiter_stats(self : ConcurrencyLimiter) -> String {
  "Limiter: global=" +
  self.global_active.to_string() +
  "/" +
  self.config.max_total.to_string() +
  " queue=" +
  self.queue_length.to_string() +
  "/" +
  self.config.queue_size.to_string() +
  " allowed=" +
  self.total_allowed.to_string() +
  " rejected=" +
  self.total_rejected.to_string()
}

