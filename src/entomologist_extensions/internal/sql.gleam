//// This module contains the code to run the sql queries defined in
//// `./src/entomologist_extensions/internal/sql`.
//// > 🐿️ This module was generated automatically using v4.6.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import gleam/json.{type Json}
import gleam/option.{type Option}
import pog

/// A row you get from running the `export_log_to_tag` query
/// defined in `./src/entomologist_extensions/internal/sql/export_log_to_tag.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ExportLogToTagRow {
  ExportLogToTagRow(log: Int, tag: Int)
}

/// Runs the `export_log_to_tag` query
/// defined in `./src/entomologist_extensions/internal/sql/export_log_to_tag.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn export_log_to_tag(
  db: pog.Connection,
) -> Result(pog.Returned(ExportLogToTagRow), pog.QueryError) {
  let decoder = {
    use log <- decode.field(0, decode.int)
    use tag <- decode.field(1, decode.int)
    decode.success(ExportLogToTagRow(log:, tag:))
  }

  "select 
    log,
    tag
from log2tag
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `export_logs` query
/// defined in `./src/entomologist_extensions/internal/sql/export_logs.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ExportLogsRow {
  ExportLogsRow(
    id: Int,
    message: String,
    level: Level,
    module: String,
    function: String,
    arity: Int,
    file: String,
    line: Int,
    last_occurrence: Int,
    resolved: Bool,
    muted: Bool,
    tags: List(Int),
    occurrences: List(Int),
  )
}

/// Runs the `export_logs` query
/// defined in `./src/entomologist_extensions/internal/sql/export_logs.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn export_logs(
  db: pog.Connection,
) -> Result(pog.Returned(ExportLogsRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use message <- decode.field(1, decode.string)
    use level <- decode.field(2, level_decoder())
    use module <- decode.field(3, decode.string)
    use function <- decode.field(4, decode.string)
    use arity <- decode.field(5, decode.int)
    use file <- decode.field(6, decode.string)
    use line <- decode.field(7, decode.int)
    use last_occurrence <- decode.field(8, decode.int)
    use resolved <- decode.field(9, decode.bool)
    use muted <- decode.field(10, decode.bool)
    use tags <- decode.field(11, decode.list(decode.int))
    use occurrences <- decode.field(12, decode.list(decode.int))
    decode.success(ExportLogsRow(
      id:,
      message:,
      level:,
      module:,
      function:,
      arity:,
      file:,
      line:,
      last_occurrence:,
      resolved:,
      muted:,
      tags:,
      occurrences:,
    ))
  }

  "select 
    l.id,
    l.message,
    l.level,
    l.module,
    l.function,
    l.arity,
    l.file,
    l.line,
    l.last_occurrence,
    l.resolved,
    l.muted,
    coalesce(array_remove(array_agg(lt.tag), null), '{}') as tags,
    coalesce(array_remove(array_agg(o.id), null), '{}') as occurrences
from logs as l
left join log2tag as lt on l.id = lt.log
left join occurrences as o on l.id = o.log
group by l.id;
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `export_occurrences` query
/// defined in `./src/entomologist_extensions/internal/sql/export_occurrences.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ExportOccurrencesRow {
  ExportOccurrencesRow(
    id: Int,
    log: Int,
    timestamp: Int,
    full_contents: Option(String),
  )
}

/// Runs the `export_occurrences` query
/// defined in `./src/entomologist_extensions/internal/sql/export_occurrences.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn export_occurrences(
  db: pog.Connection,
) -> Result(pog.Returned(ExportOccurrencesRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use log <- decode.field(1, decode.int)
    use timestamp <- decode.field(2, decode.int)
    use full_contents <- decode.field(3, decode.optional(decode.string))
    decode.success(ExportOccurrencesRow(id:, log:, timestamp:, full_contents:))
  }

  "select * from occurrences;
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `export_tags` query
/// defined in `./src/entomologist_extensions/internal/sql/export_tags.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ExportTagsRow {
  ExportTagsRow(id: Int, name: String, logs: List(Int))
}

/// Runs the `export_tags` query
/// defined in `./src/entomologist_extensions/internal/sql/export_tags.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn export_tags(
  db: pog.Connection,
) -> Result(pog.Returned(ExportTagsRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use name <- decode.field(1, decode.string)
    use logs <- decode.field(2, decode.list(decode.int))
    decode.success(ExportTagsRow(id:, name:, logs:))
  }

  "select 
    id,
    name,
    coalesce(array_remove(array_agg(lt.log), null), '{}') as logs
from tags as t
left join log2tag as lt on lt.tag = t.id
group by t.id;
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `insert_log` query
/// defined in `./src/entomologist_extensions/internal/sql/insert_log.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_log(
  db: pog.Connection,
  arg_1: Int,
  arg_2: String,
  arg_3: Level,
  arg_4: String,
  arg_5: String,
  arg_6: Int,
  arg_7: String,
  arg_8: Int,
  arg_9: Int,
  arg_10: Bool,
  arg_11: Bool,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "insert into logs (
    id, message, level, module, function, arity, file, line, last_occurrence, resolved, muted
) values ( $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11 )
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(level_encoder(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.parameter(pog.int(arg_6))
  |> pog.parameter(pog.text(arg_7))
  |> pog.parameter(pog.int(arg_8))
  |> pog.parameter(pog.int(arg_9))
  |> pog.parameter(pog.bool(arg_10))
  |> pog.parameter(pog.bool(arg_11))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `insert_log_to_tag` query
/// defined in `./src/entomologist_extensions/internal/sql/insert_log_to_tag.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_log_to_tag(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "insert into log2tag (log, tag)
values ( $1, $2 )
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `insert_occurrence` query
/// defined in `./src/entomologist_extensions/internal/sql/insert_occurrence.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type InsertOccurrenceRow {
  InsertOccurrenceRow(id: Int)
}

/// Runs the `insert_occurrence` query
/// defined in `./src/entomologist_extensions/internal/sql/insert_occurrence.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_occurrence(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
  arg_3: Json,
) -> Result(pog.Returned(InsertOccurrenceRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    decode.success(InsertOccurrenceRow(id:))
  }

  "insert into
    occurrences(log, timestamp, full_contents)
values
    ($1, $2, $3)
returning id;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.text(json.to_string(arg_3)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `insert_tag` query
/// defined in `./src/entomologist_extensions/internal/sql/insert_tag.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_tag(
  db: pog.Connection,
  arg_1: Int,
  arg_2: String,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "insert into tags (id, name) values ($1, $2)
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

// --- Enums -------------------------------------------------------------------

/// Corresponds to the Postgres `level` enum.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type Level {
  Debug
  Info
  Notice
  Warning
  Error
  Critical
  Alert
  Emergency
}

fn level_decoder() -> decode.Decoder(Level) {
  use level <- decode.then(decode.string)
  case level {
    "debug" -> decode.success(Debug)
    "info" -> decode.success(Info)
    "notice" -> decode.success(Notice)
    "warning" -> decode.success(Warning)
    "error" -> decode.success(Error)
    "critical" -> decode.success(Critical)
    "alert" -> decode.success(Alert)
    "emergency" -> decode.success(Emergency)
    _ -> decode.failure(Debug, "Level")
  }
}

fn level_encoder(level) -> pog.Value {
  case level {
    Debug -> "debug"
    Info -> "info"
    Notice -> "notice"
    Warning -> "warning"
    Error -> "error"
    Critical -> "critical"
    Alert -> "alert"
    Emergency -> "emergency"
  }
  |> pog.text
}
