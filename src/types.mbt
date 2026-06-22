// ────────────────────────────────────────────
// AegisRun — Core Type Definitions
// All shared types used across modules
// ────────────────────────────────────────────

// ── Result type (pre-Option in MoonBit) ──
enum Result[T, E] {
  Ok(T)
  Err(E)
}

// ── Capability: what a tool requests ──
enum FilePerm {
  Read
  Write
  ReadWrite
}

struct NetworkPolicy {
  // Allowed domains (exact match or suffix like "*.example.com")
  domains : List[String]
  // Allowed IP ranges in CIDR notation (Future: Full)
  ip_ranges : List[String]
}

struct FilePolicy {
  path : String
  permission : FilePerm
  max_depth : Int        // 0 = only this file/dir, N = N levels deep
  allowed_extensions : List[String]  // empty = all
  max_file_size_kb : Int // 0 = unlimited
}

struct SqlPolicy {
  alias : String          // Alias exposed to tool (not real connection string)
  tables : List[SqlTableRule]
}

struct SqlTableRule {
  name : String
  permissions : List[String]    // ["SELECT", "INSERT", ...]
  allowed_columns : List[String]  // empty = all
  max_rows : Int                // 0 = unlimited
  require_where : Bool          // Must have WHERE for DELETE/UPDATE
  forbidden_operations : List[String]  // ["DROP", "ALTER", "TRUNCATE"]
}

enum Capability {
  Network(NetworkPolicy)
  FileSystem(FilePolicy)
  EnvVar(String)           // env var name
  Sql(SqlPolicy)
  Timeout(Int)             // max execution time in ms
  Memory(Int)              // max memory in KB
}

// ── Tool manifest (declared by tool author) ──
struct ToolManifest {
  id : String
  name : String
  version : String
  author : String
  description : String
  // Hash of the .wasm file for integrity verification
  wasm_hash : String
  // What the tool says it needs (may be lying!)
  declared_capabilities : List[Capability]
  // Input/output JSON Schema strings
  input_schema : String
  output_schema : String
  // Tags for discovery
  tags : List[String]
}

// ── Tool execution result ──
struct ToolResult {
  tool_id : String
  output : String
  elapsed_ms : Int
  exit_code : Int         // 0 = success
  errors : List[String]
}

// ── Audit log entry ──
struct AuditEntry {
  timestamp : String      // ISO 8601
  tool_id : String
  session_id : String
  action : String         // "install" | "execute" | "deny" | "error"
  input_snapshot : String // truncated if > 1KB
  output_snapshot : String
  decision : String       // "allow" | "deny" | "timeout" | "error"
  reason : String         // Why was this decision made?
  elapsed_ms : Int
}

// ── Policy decision helper ──
enum PolicyDecision {
  Allow(String)           // Allowed, with reason
  Deny(String)            // Denied, with reason
  Warning(String)         // Allowed but logged as warning
}
