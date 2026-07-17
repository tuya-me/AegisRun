// ============================================================
// AegisRun Concurrency Limiter Tests
// ============================================================

fn err_msg(r : Result[String, String]) -> String {
  match r {
    Ok(_) => "UNEXPECTED_OK"
    Err(e) => e
  }
}

///|
test "limiter_default_creation" {
  let l = default_limiter()
  let stats = ConcurrencyLimiter::limiter_stats(l)
  assert_eq(stats.contains("global=0/100"), true)
  assert_eq(stats.contains("queue=0/200"), true)
  assert_eq(stats.contains("allowed=0"), true)
  assert_eq(stats.contains("rejected=0"), true)
}

///|
test "limiter_acquire_success" {
  let l = default_limiter()
  let result = ConcurrencyLimiter::acquire(l, "bash", "session-1")
  assert_eq(result.is_ok(), true)
  assert_eq(result.unwrap().contains("ACQUIRED"), true)
  assert_eq(result.unwrap().contains("1/100"), true)
}

///|
test "limiter_multiple_acquires" {
  let l = default_limiter()
  let r1 = ConcurrencyLimiter::acquire(l, "bash", "session-1")
  let r2 = ConcurrencyLimiter::acquire(l, "read", "session-1")
  let r3 = ConcurrencyLimiter::acquire(l, "bash", "session-2")
  assert_eq(r1.is_ok(), true)
  assert_eq(r2.is_ok(), true)
  assert_eq(r3.is_ok(), true)
  let stats = ConcurrencyLimiter::limiter_stats(l)
  assert_eq(stats.contains("global=3/100"), true)
  assert_eq(stats.contains("allowed=3"), true)
}

///|
test "limiter_global_limit_enforced" {
  let l = new_limiter({
    max_total: 2,
    max_per_tool: 10,
    max_per_session: 5,
    queue_size: 1,
    queue_timeout_ms: 5000,
  })
  let r1 = ConcurrencyLimiter::acquire(l, "tool-a", "s1")
  let r2 = ConcurrencyLimiter::acquire(l, "tool-b", "s2")
  assert_eq(r1.is_ok(), true)
  assert_eq(r2.is_ok(), true)
  let r3 = ConcurrencyLimiter::acquire(l, "tool-c", "s3")
  assert_eq(r3.is_err(), true)
  assert_eq(err_msg(r3).contains("QUEUED"), true)
}

///|
test "limiter_queue_full_rejects" {
  let l = new_limiter({
    max_total: 1,
    max_per_tool: 10,
    max_per_session: 10,
    queue_size: 1,
    queue_timeout_ms: 5000,
  })
  let r1 = ConcurrencyLimiter::acquire(l, "tool-a", "s1")
  assert_eq(r1.is_ok(), true)
  let r2 = ConcurrencyLimiter::acquire(l, "tool-b", "s2")
  assert_eq(r2.is_err(), true)
  assert_eq(err_msg(r2).contains("QUEUED"), true)
  let r3 = ConcurrencyLimiter::acquire(l, "tool-c", "s3")
  assert_eq(r3.is_err(), true)
  assert_eq(err_msg(r3).contains("REJECTED"), true)
}

///|
test "limiter_per_tool_limit" {
  let l = new_limiter({
    max_total: 100,
    max_per_tool: 2,
    max_per_session: 10,
    queue_size: 10,
    queue_timeout_ms: 5000,
  })
  let r1 = ConcurrencyLimiter::acquire(l, "bash", "s1")
  let r2 = ConcurrencyLimiter::acquire(l, "bash", "s2")
  assert_eq(r1.is_ok(), true)
  assert_eq(r2.is_ok(), true)
  let r3 = ConcurrencyLimiter::acquire(l, "bash", "s3")
  assert_eq(r3.is_err(), true)
  assert_eq(err_msg(r3).contains("tool 'bash' limit 2"), true)
}

///|
test "limiter_per_session_limit" {
  let l = new_limiter({
    max_total: 100,
    max_per_tool: 10,
    max_per_session: 2,
    queue_size: 10,
    queue_timeout_ms: 5000,
  })
  let r1 = ConcurrencyLimiter::acquire(l, "bash", "s1")
  let r2 = ConcurrencyLimiter::acquire(l, "read", "s1")
  assert_eq(r1.is_ok(), true)
  assert_eq(r2.is_ok(), true)
  let r3 = ConcurrencyLimiter::acquire(l, "write", "s1")
  assert_eq(r3.is_err(), true)
  assert_eq(err_msg(r3).contains("session limit 2"), true)
}

///|
test "limiter_release_decrements" {
  let l = default_limiter()
  let _ = ConcurrencyLimiter::acquire(l, "bash", "s1")
  let _ = ConcurrencyLimiter::acquire(l, "read", "s2")
  let stats_before = ConcurrencyLimiter::limiter_stats(l)
  assert_eq(stats_before.contains("global=2/100"), true)
  ConcurrencyLimiter::release(l, "bash", "s1")
  let stats_after = ConcurrencyLimiter::limiter_stats(l)
  assert_eq(stats_after.contains("global=1/100"), true)
}

///|
test "limiter_release_allows_new_acquire" {
  let l = new_limiter({
    max_total: 1,
    max_per_tool: 1,
    max_per_session: 1,
    queue_size: 0,
    queue_timeout_ms: 5000,
  })
  let r1 = ConcurrencyLimiter::acquire(l, "bash", "s1")
  assert_eq(r1.is_ok(), true)
  let r2 = ConcurrencyLimiter::acquire(l, "bash", "s2")
  assert_eq(r2.is_err(), true)
  ConcurrencyLimiter::release(l, "bash", "s1")
  let r3 = ConcurrencyLimiter::acquire(l, "bash", "s2")
  assert_eq(r3.is_ok(), true)
}

///|
test "limiter_set_tool_limit" {
  let l = default_limiter()
  ConcurrencyLimiter::set_tool_limit(l, "bash", 3)
  let r1 = ConcurrencyLimiter::acquire(l, "bash", "s1")
  let r2 = ConcurrencyLimiter::acquire(l, "bash", "s2")
  let r3 = ConcurrencyLimiter::acquire(l, "bash", "s3")
  assert_eq(r1.is_ok(), true)
  assert_eq(r2.is_ok(), true)
  assert_eq(r3.is_ok(), true)
  let r4 = ConcurrencyLimiter::acquire(l, "bash", "s4")
  assert_eq(r4.is_err(), true)
  assert_eq(err_msg(r4).contains("tool 'bash' limit 3"), true)
}

///|
test "limiter_rejected_count_increments" {
  let l = new_limiter({
    max_total: 1,
    max_per_tool: 1,
    max_per_session: 10,
    queue_size: 0,
    queue_timeout_ms: 5000,
  })
  let _ = ConcurrencyLimiter::acquire(l, "bash", "s1")
  let _ = ConcurrencyLimiter::acquire(l, "bash", "s2")
  let _ = ConcurrencyLimiter::acquire(l, "read", "s3")
  let stats = ConcurrencyLimiter::limiter_stats(l)
  assert_eq(stats.contains("rejected=2"), true)
}

///|
test "limiter_release_does_not_go_negative" {
  let l = default_limiter()
  ConcurrencyLimiter::release(l, "nonexistent", "nonexistent")
  let stats = ConcurrencyLimiter::limiter_stats(l)
  assert_eq(stats.contains("global=0/100"), true)
}

///|
test "limiter_different_tools_independent" {
  let l = new_limiter({
    max_total: 100,
    max_per_tool: 1,
    max_per_session: 10,
    queue_size: 10,
    queue_timeout_ms: 5000,
  })
  let r1 = ConcurrencyLimiter::acquire(l, "bash", "s1")
  let r2 = ConcurrencyLimiter::acquire(l, "read", "s2")
  let r3 = ConcurrencyLimiter::acquire(l, "write", "s3")
  assert_eq(r1.is_ok(), true)
  assert_eq(r2.is_ok(), true)
  assert_eq(r3.is_ok(), true)
}

///|
test "limiter_different_sessions_independent" {
  let l = new_limiter({
    max_total: 100,
    max_per_tool: 10,
    max_per_session: 1,
    queue_size: 10,
    queue_timeout_ms: 5000,
  })
  let r1 = ConcurrencyLimiter::acquire(l, "bash", "s1")
  let r2 = ConcurrencyLimiter::acquire(l, "bash", "s2")
  let r3 = ConcurrencyLimiter::acquire(l, "bash", "s3")
  assert_eq(r1.is_ok(), true)
  assert_eq(r2.is_ok(), true)
  assert_eq(r3.is_ok(), true)
}
