// AegisRun v1.2 — SQL Resource Guard

///|
pub struct SqlTableRule {
  name : String
  permissions : Array[String]
  allowed_columns : Array[String]
  max_rows : Int
  require_where : Bool
  forbidden_ops : Array[String]
}

///|
pub struct SqlConnection {
  db_alias : String
  real_path : String
  tables : Array[SqlTableRule]
  mut query_count : Int
  mut blocked_count : Int
}

///|
pub fn make_sql_rule(
  name : String,
  permissions : Array[String],
  allowed_columns : Array[String],
  max_rows : Int,
  require_where : Bool,
  forbidden_ops : Array[String],
) -> SqlTableRule {
  { name, permissions, allowed_columns, max_rows, require_where, forbidden_ops }
}

///|
pub fn new_sql_connection(
  db_alias : String,
  real_path : String,
) -> SqlConnection {
  { db_alias, real_path, tables: [], query_count: 0, blocked_count: 0 }
}

///|
pub fn SqlConnection::add_table(
  self : SqlConnection,
  rule : SqlTableRule,
) -> Unit {
  self.tables.push(rule)
}

///|
pub fn SqlConnection::guard_query(
  self : SqlConnection,
  query : String,
) -> Result[String, String] {
  self.query_count = self.query_count + 1
  let upper = query.to_upper()
  let no_dbl_space = upper // already cleaned in caller

  // 1. Forbidden ops
  if no_dbl_space.contains("DROP TABLE") ||
    no_dbl_space.contains("DROP DATABASE") {
    self.blocked_count = self.blocked_count + 1
    return Err("BLOCKED: DROP forbidden on '" + self.db_alias + "'")
  }
  if no_dbl_space.contains("ALTER TABLE") ||
    no_dbl_space.contains("ALTER DATABASE") {
    self.blocked_count = self.blocked_count + 1
    return Err("BLOCKED: ALTER forbidden on '" + self.db_alias + "'")
  }
  if no_dbl_space.contains("TRUNCATE") {
    self.blocked_count = self.blocked_count + 1
    return Err("BLOCKED: TRUNCATE forbidden on '" + self.db_alias + "'")
  }

  // 2. Extract table name and check rules
  let table_name = extract_table(no_dbl_space)
  match table_name {
    None => {
      self.blocked_count = self.blocked_count + 1
      Err("BLOCKED: cannot determine table")
    }
    Some(t) => {
      let rule = find_rule(self.tables, t)
      match rule {
        None => {
          self.blocked_count = self.blocked_count + 1
          Err("BLOCKED: table '" + t + "' not granted")
        }
        Some(r) => {
          let op = detect_op(no_dbl_space)
          match op {
            None => {
              self.blocked_count = self.blocked_count + 1
              Err("BLOCKED: unknown operation")
            }
            Some(op_name) =>
              if !is_allowed(r.permissions, op_name) {
                self.blocked_count = self.blocked_count + 1
                Err("BLOCKED: " + op_name + " not allowed on '" + t + "'")
              } else if r.require_where &&
                (op_name == "DELETE" || op_name == "UPDATE") &&
                !no_dbl_space.contains("WHERE") {
                self.blocked_count = self.blocked_count + 1
                Err("BLOCKED: " + op_name + " on '" + t + "' requires WHERE")
              } else if op_name == "SELECT" &&
                r.allowed_columns.length() > 0 &&
                no_dbl_space.contains("SELECT *") {
                self.blocked_count = self.blocked_count + 1
                Err("BLOCKED: SELECT * not allowed on '" + t + "'")
              } else {
                Ok("SQL query on '" + self.db_alias + "' → ALLOWED")
              }
          }
        }
      }
    }
  }
}

///|
/// v0.7.0: 默认 SQL 连接（sandbox 集成用）
pub fn default_sql_connection() -> SqlConnection {
  let conn = new_sql_connection("default-db", ":memory:")
  conn.add_table(
    make_sql_rule(
      "users",
      ["SELECT", "INSERT", "UPDATE"],
      ["id", "name", "email"],
      1000,
      true,
      [],
    ),
  )
  conn.add_table(
    make_sql_rule("secrets", ["SELECT"], ["id", "key_name"], 10, true, [
      "DROP", "ALTER", "TRUNCATE",
    ]),
  )
  conn
}

///|
pub fn SqlConnection::sql_guard_stats(self : SqlConnection) -> String {
  "SQL Guard '" +
  self.db_alias +
  "': " +
  self.query_count.to_string() +
  " queries, " +
  self.blocked_count.to_string() +
  " blocked"
}

// Helpers

///|
fn extract_table(query : String) -> String? {
  // INSERT INTO <table> ...
  let into_pos = query.find("INTO ")
  match into_pos {
    Some(idx) => {
      let rest = query[idx + 5:]
      let space_pos = rest.find(" ")
      match space_pos {
        None => Some(rest.to_owned())
        Some(e) => Some(rest[:e].to_owned())
      }
    }
    None => {
      // SELECT/DELETE/UPDATE FROM <table> ...
      let from_pos = query.find("FROM ")
      match from_pos {
        None => None
        Some(idx) => {
          let rest = query[idx + 5:]
          let space_pos = rest.find(" ")
          match space_pos {
            None => Some(rest.to_owned())
            Some(e) => Some(rest[:e].to_owned())
          }
        }
      }
    }
  }
}

///|
fn find_rule(tables : Array[SqlTableRule], name : String) -> SqlTableRule? {
  for r in tables {
    if r.name.to_upper() == name {
      return Some(r)
    }
  }
  None
}

///|
fn detect_op(query : String) -> String? {
  if query.has_prefix("SELECT") {
    Some("SELECT")
  } else if query.has_prefix("INSERT") {
    Some("INSERT")
  } else if query.has_prefix("UPDATE") {
    Some("UPDATE")
  } else if query.has_prefix("DELETE") {
    Some("DELETE")
  } else {
    None
  }
}

///|
fn is_allowed(perms : Array[String], op : String) -> Bool {
  for p in perms {
    if p == op {
      return true
    }
  }
  false
}
