import entomologist as ent
import entomologist_extensions/internal/sql
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/string
import gleam/time/timestamp

/// Wraps a string in another.
pub fn wrap(s: String, with c: String) -> String {
  c <> s <> c
}

/// Transforms a list to a string using a transform function on every element.
pub fn list_to_string(l: List(a), transform: fn(a) -> String) -> String {
  "[" <> list.map(l, transform) |> string.join(",") <> "]"
}

/// Calls the return() callback when result has value `Error`.
///
/// return should be small so callback can be handled by a `use`.
pub fn result_guard(
  when_error result: Result(a, b),
  return return: fn(b) -> c,
  callback cb: fn(a) -> c,
) -> c {
  case result {
    Ok(a) -> cb(a)
    Error(v) -> return(v)
  }
}

pub fn parse_level(level: String) -> Result(ent.Level, Nil) {
  case level {
    "alert" -> Ok(ent.Alert)
    "critical" -> Ok(ent.Critical)
    "debug" -> Ok(ent.Debug)
    "emergency" -> Ok(ent.Emergency)
    "error" -> Ok(ent.ErrorLevel)
    "info" -> Ok(ent.Info)
    "notice" -> Ok(ent.Notice)
    "warning" -> Ok(ent.Warning)
    _ -> Error(Nil)
  }
}

pub fn level_encoder(level: sql.Level) -> String {
  case level {
    sql.Info -> "info"
    sql.Debug -> "debug"
    sql.Notice -> "notice"
    sql.Warning -> "warning"
    sql.Error -> "error"
    sql.Critical -> "critical"
    sql.Alert -> "alert"
    sql.Emergency -> "emergency"
  }
}

pub fn extract_log_search_fields(
  acc: ent.SearchData,
  value: #(String, String),
) -> ent.SearchData {
  case value {
    #(_, "") -> acc
    #("muted", "muted") -> ent.SearchData(..acc, muted: Some(True))
    #("muted", "unmuted") -> ent.SearchData(..acc, muted: Some(False))
    #("file", file) -> ent.SearchData(..acc, file: Some(file))
    #("module", module) -> ent.SearchData(..acc, module: Some(module))
    #("message", message) -> ent.SearchData(..acc, message: Some(message))
    #("function", function) -> ent.SearchData(..acc, function: Some(function))
    #("resolved", "resolved") -> ent.SearchData(..acc, resolved: Some(True))
    #("resolved", "unresolved") -> ent.SearchData(..acc, resolved: Some(False))

    #("level", level) -> {
      use level <- result_guard(
        when_error: parse_level(level),
        return: fn(_) -> ent.SearchData { acc },
      )

      ent.SearchData(..acc, level: Some(level))
    }

    #("line", line) -> {
      use line <- result_guard(
        when_error: int.parse(line),
        return: fn(_) -> ent.SearchData { acc },
      )

      ent.SearchData(..acc, line: Some(line))
    }

    #("arity", arity) -> {
      use arity <- result_guard(
        when_error: int.parse(arity),
        return: fn(_) -> ent.SearchData { acc },
      )

      ent.SearchData(..acc, arity: Some(arity))
    }

    #("occurrence_range_start", occurrence_start) -> {
      let occurrence_start =
        timestamp.parse_rfc3339(occurrence_start <> "T00:00:00Z")

      use occurrence_start <- result_guard(
        when_error: occurrence_start,
        return: fn(_) { acc },
      )

      let occurrence_range_start =
        timestamp.to_unix_seconds(occurrence_start)
        |> float.round
        |> Some

      ent.SearchData(..acc, occurrence_range_start:)
    }

    #("occurrence_range_end", occurrence_end) -> {
      let occurrence_end =
        timestamp.parse_rfc3339(occurrence_end <> "T00:00:00Z")

      use occurrence_end <- result_guard(
        when_error: occurrence_end,
        return: fn(_) { acc },
      )

      let occurrence_range_end =
        occurrence_end
        |> timestamp.to_unix_seconds()
        |> float.round
        |> Some

      ent.SearchData(..acc, occurrence_range_end:)
    }
    _ -> acc
  }
}
