//// This module contains the extra entomologist functionality.
////
//// Examples of usage are linked in the function documentation if avaliable

import argv
import entomologist_extensions/internal/routes
import entomologist_extensions/internal/sql
import entomologist_extensions/internal/util.{
  parse_error_msg, result_with_message,
}
import gleam/bool
import gleam/dict
import gleam/erlang/process
import gleam/http
import gleam/http/request.{Request}
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option
import gleam/otp/actor
import gleam/otp/static_supervisor as supervisor
import gleam/result
import gleam/string
import gsv
import pog.{type Connection}
import simplifile
import wisp.{type Request, type Response}

type Error {
  PogError(pog.QueryError)
}

pub type Table {
  LogToTag
  Logs
  Tags
  Occurrences
}

pub type LogRow {
  LogRow(
    id: Int,
    message: String,
    level: sql.Level,
    module: String,
    function: String,
    arity: Int,
    file: String,
    line: Int,
    last_occurrence: Int,
    resolved: Bool,
    muted: Bool,
  )
}

fn default_logrow() {
  LogRow(
    id: -1,
    message: "",
    level: sql.Info,
    module: "",
    function: "",
    arity: -1,
    file: "",
    line: -1,
    last_occurrence: -1,
    resolved: False,
    muted: False,
  )
}

pub type OccurrenceRow {
  OccurrenceRow(id: Int, log: Int, timestamp: Int, full_contents: String)
}

fn default_ocurrencerow() {
  OccurrenceRow(id: -1, log: -1, timestamp: -1, full_contents: "")
}

pub type SqlData {
  Log2Tag(List(#(Int, Int)))
  Log(List(LogRow))
  Tag(List(#(Int, String)))
  Occurrence(List(OccurrenceRow))
}

const file_discriminators = [
  #(LogToTag, "log_to_tag.csv"),
  #(Logs, "logs.csv"),
  #(Tags, "tags.csv"),
  #(Occurrences, "occurrences.csv"),
]

/// Main function.
///
/// It calls the export function, since the rest of the project is designed as a library.
pub fn main() {
  let pool_name = process.new_name("postgres_pool")
  let assert Ok(_) = create_pool(pool_name:)

  let db = pog.named_connection(pool_name)

  case argv.load().arguments {
    ["export", file_prefix] -> {
      let content = export(db) |> dict.to_list()
      let assert Ok(_) =
        {
          use #(k, discriminator), #(k2, contents) <- list.map2(
            file_discriminators,
            content,
          )

          assert k == k2 as "both should be ordered (?)"

          let file = file_prefix <> discriminator

          let file_written = simplifile.write(to: file, contents:)
          use Nil <- result.try(file_written)

          Ok(Nil)
        }
        |> result.all()
        |> result.map_error(string.inspect)

      Nil
    }

    ["import", file_prefix] -> {
      let result = {
        use string_data <- result.try(read(file_prefix))

        let parsed_data =
          dict.fold(string_data, Ok([]), fn(acc, key, value) {
            // error short-circuit
            use data <- result.try(acc)

            use row <- result.try(parse_csv(key, value))
            [row, ..data] |> Ok
          })
          |> result.map_error(fn(e) { "Error parsing data: " <> e })

        use data <- result.try(parsed_data)
        insert_data(data)
      }
      use <- result.lazy_unwrap(result)

      let assert Error(s) = result
      panic as s
    }

    ["help"] | _ ->
      "Usage: gleam run -m entomologist_extensions export <file prefix>"
      |> io.println
  }
}

fn read(prefix: String) -> Result(dict.Dict(Table, String), String) {
  list.map(file_discriminators, fn(v) {
    let #(k, discriminator) = v

    let file = prefix <> discriminator

    let contents = simplifile.read(from: file)
    use contents <- result.try(contents)
    Ok(#(k, contents))
  })
  |> result.all()
  |> result.map(dict.from_list)
  |> result.map_error(fn(e) { string.inspect(e) })
}

fn parse_csv(key: Table, val: String) -> Result(SqlData, String) {
  use rows <- result.try(
    gsv.to_dicts(val, ";")
    |> result.map_error(fn(e) {
      case e {
        gsv.UnescapedQuote(line:) ->
          "Found unescaped quote on line " <> line |> int.to_string
        gsv.MissingClosingQuote(starting_line:) ->
          "Found unmatched quote on line " <> starting_line |> int.to_string
      }
    }),
  )

  case key {
    LogToTag -> into_log_to_tag(rows) |> result.all() |> result.map(Log2Tag)
    Logs -> into_logs(rows) |> result.all() |> result.map(Log)
    Tags -> into_tags(rows) |> result.all() |> result.map(Tag)
    Occurrences ->
      into_occurrences(rows) |> result.all() |> result.map(Occurrence)
  }
}

fn into_occurrences(
  rows: List(dict.Dict(String, String)),
) -> List(Result(OccurrenceRow, String)) {
  use row <- list.map(rows)
  use acc, key, value <- dict.fold(row, from: Ok(default_ocurrencerow()))

  use acc <- result.try(acc)

  case key {
    "full_contents" -> OccurrenceRow(..acc, full_contents: value) |> Ok

    "id" -> {
      let value =
        int.parse(value)
        |> result_with_message(parse_error_msg("log", "int", value))

      use id <- result.try(value)
      OccurrenceRow(..acc, id:) |> Ok
    }
    "log" -> {
      let value =
        int.parse(value)
        |> result_with_message(parse_error_msg("log", "int", value))

      use log <- result.try(value)
      OccurrenceRow(..acc, log:) |> Ok
    }
    "timestamp" -> {
      let value =
        int.parse(value)
        |> result_with_message(parse_error_msg("log", "int", value))

      use timestamp <- result.try(value)
      OccurrenceRow(..acc, timestamp:) |> Ok
    }

    _ ->
      Error(
        "ERROR: CSV format failure.\tUnexpected field `"
        <> key
        <> "` while parsing occurrences",
      )
  }
}

fn into_tags(
  rows: List(dict.Dict(String, String)),
) -> List(Result(#(Int, String), String)) {
  use row <- list.map(rows)
  use acc, key, value <- dict.fold(row, from: Ok(#(-1, "")))

  use acc <- result.try(acc)

  case key {
    "name" -> Ok(#(acc.0, value))
    "id" -> {
      let value =
        int.parse(value)
        |> result_with_message(parse_error_msg("log", "int", value))

      use value <- result.try(value)
      #(value, acc.1) |> Ok
    }

    "logs" -> Ok(acc)

    _ ->
      Error(
        "ERROR: CSV format failure.\tUnexpected field `"
        <> key
        <> "` while parsing tags",
      )
  }
}

fn into_log_to_tag(
  rows: List(dict.Dict(String, String)),
) -> List(Result(#(Int, Int), String)) {
  use row <- list.map(rows)
  use acc, key, value <- dict.fold(row, from: Ok(#(-1, -1)))

  use acc <- result.try(acc)

  case key {
    "log" -> {
      let value =
        int.parse(value)
        |> result_with_message(parse_error_msg("log", "int", value))

      use value <- result.try(value)
      #(value, acc.1) |> Ok
    }
    "tag" -> {
      let value =
        int.parse(value)
        |> result_with_message(parse_error_msg("tag", "int", value))

      use value <- result.try(value)
      Ok(#(acc.0, value))
    }
    _ ->
      Error(
        "ERROR: CSV format failure.\tUnexpected field `"
        <> key
        <> "` log to tag",
      )
  }
}

fn into_logs(
  rows: List(dict.Dict(String, String)),
) -> List(Result(LogRow, String)) {
  use row <- list.map(rows)
  use acc, key, value <- dict.fold(row, from: Ok(default_logrow()))

  use acc <- result.try(acc)

  // id: Int,
  // message: String,
  // level: sql.Level,
  // module: String,
  // function: String,
  // arity: Int,
  // file: String,
  // line: Int,
  // last_occurrence: Int,
  // resolved: Bool,
  // muted: Bool,

  case key {
    //Duplicate data. Stored in log2tag and occurrence.log
    //It's there to ease tooling usage with the csv
    "tags" -> Ok(acc)
    "occurrences" -> Ok(acc)

    "message" -> LogRow(..acc, message: value) |> Ok
    "module" -> LogRow(..acc, module: value) |> Ok
    "function" -> LogRow(..acc, function: value) |> Ok
    "file" -> LogRow(..acc, file: value) |> Ok

    "resolved" ->
      util.bool_parser(value, key)
      |> result.map(fn(resolved) { LogRow(..acc, resolved:) })

    "muted" ->
      util.bool_parser(value, key)
      |> result.map(fn(muted) { LogRow(..acc, muted:) })

    "level" ->
      util.level_parser(value)
      |> result.map(fn(level) { LogRow(..acc, level:) })

    "id" -> {
      let value =
        int.parse(value)
        |> result_with_message(parse_error_msg("log id", "int", value))

      use value <- result.try(value)
      LogRow(..acc, id: value) |> Ok
    }
    "arity" -> {
      let value =
        int.parse(value)
        |> result_with_message(parse_error_msg("log arity", "int", value))

      use value <- result.try(value)
      LogRow(..acc, arity: value) |> Ok
    }
    "line" -> {
      let value =
        int.parse(value)
        |> result_with_message(parse_error_msg("log line", "int", value))

      use value <- result.try(value)
      LogRow(..acc, line: value) |> Ok
    }
    "last_occurrence" -> {
      let value =
        int.parse(value)
        |> result_with_message(parse_error_msg("last occurrence", "int", value))

      use value <- result.try(value)
      LogRow(..acc, last_occurrence: value) |> Ok
    }
    _ ->
      Error(
        "ERROR: CSV format failure.\tUnexpected field `"
        <> key
        <> "` while parsing logs",
      )
  }
}

fn insert_data(data: List(SqlData)) -> Result(Nil, String) {
  let pool_name = process.new_name("postgres_pool")
  let assert Ok(_) = create_pool(pool_name:)

  let conn = pog.named_connection(pool_name)

  list.map(data, fn(v) {
    case v {
      Log2Tag(v) -> insert_log_to_tag(v, conn)
      Log(v) -> insert_logs(v, conn)
      Tag(v) -> insert_tags(v, conn)
      Occurrence(v) -> insert_occurrences(v, conn)
    }
  })
  |> result.all()
  |> result.map(fn(_) { Nil })
}

fn insert_occurrences(
  v: List(OccurrenceRow),
  conn: Connection,
) -> Result(Nil, String) {
  case v {
    [] -> Ok(Nil)
    [OccurrenceRow(..) as occurrence, ..rest] ->
      sql.insert_occurrence(
        conn,
        occurrence.log,
        occurrence.timestamp,
        // TODO: This is probably stupid
        occurrence.full_contents |> json.string,
      )
      |> result.map_error(util.describe_error(_, "insert_logs"))
      |> result.try(fn(_) { insert_occurrences(rest, conn) })
  }
}

fn insert_tags(
  v: List(#(Int, String)),
  conn: Connection,
) -> Result(Nil, String) {
  case v {
    [] -> Ok(Nil)
    [#(id, name), ..rest] ->
      sql.insert_tag(conn, id, name)
      |> result.map_error(util.describe_error(_, "insert_logs"))
      |> result.try(fn(_) { insert_tags(rest, conn) })
  }
}

fn insert_log_to_tag(
  v: List(#(Int, Int)),
  conn: Connection,
) -> Result(Nil, String) {
  case v {
    [] -> Ok(Nil)
    [#(log, tag), ..rest] ->
      sql.insert_log_to_tag(conn, log, tag)
      |> result.map_error(util.describe_error(_, "insert_log_to_tag"))
      |> result.try(fn(_) { insert_log_to_tag(rest, conn) })
  }
}

fn insert_logs(v: List(LogRow), conn: pog.Connection) -> Result(Nil, String) {
  case v {
    [] -> Ok(Nil)
    [LogRow(..) as log, ..rest] ->
      sql.insert_log(
        conn,
        log.id,
        log.message,
        log.level,
        log.module,
        log.function,
        log.arity,
        log.file,
        log.line,
        log.last_occurrence,
        log.resolved,
        log.muted,
      )
      |> result.map_error(util.describe_error(_, "insert_logs"))
      |> result.try(fn(_) { insert_logs(rest, conn) })
  }
}

/// Export the DB to a csv file on the server.
///
/// This should never be exposed to te client,
/// since it serves admin purposes only
pub fn export(connection: pog.Connection) -> dict.Dict(Table, String) {
  let assert Ok(log_to_tag) =
    sql.export_log_to_tag(connection)
    |> result.map_error(PogError)
    |> log2tag_to_csv
    as "Log2Tag should be serializable as a csv"

  let assert Ok(logs) =
    sql.export_logs(connection)
    |> result.map_error(PogError)
    |> logs_to_csv
    as "Logs should be serializable as a csv"

  let assert Ok(tags) =
    sql.export_tags(connection)
    |> result.map_error(PogError)
    |> tags_to_csv
    as "Tags should be serializable as a csv"

  let assert Ok(occurrences) =
    sql.export_occurrences(connection)
    |> result.map_error(PogError)
    |> occurrences_to_csv
    as "Occurrences should be serializable as a csv"

  dict.new()
  |> dict.insert(LogToTag, log_to_tag)
  |> dict.insert(Logs, logs)
  |> dict.insert(Tags, tags)
  |> dict.insert(Occurrences, occurrences)
}

fn occurrences_to_csv(
  query_return: Result(pog.Returned(sql.ExportOccurrencesRow), Error),
) -> Result(String, Error) {
  use pog.Returned(count: _, rows:) <- result.try(query_return)

  list.map(rows, fn(row) {
    [
      #("id", int.to_string(row.id)),
      #("log", int.to_string(row.log)),
      #("timestamp", int.to_string(row.timestamp)),
      #(
        "full_contents",
        row.full_contents
          |> option.map(string.remove_prefix(_, "\""))
          |> option.map(string.remove_suffix(_, "\""))
          |> option.unwrap("NONE"),
      ),
    ]
    |> list.reverse
    |> dict.from_list
  })
  |> gsv.from_dicts(separator: ";", line_ending: gsv.Windows)
  |> Ok
}

fn tags_to_csv(
  query_return: Result(pog.Returned(sql.ExportTagsRow), Error),
) -> Result(String, Error) {
  use pog.Returned(count: _, rows:) <- result.try(query_return)

  list.map(rows, fn(v) {
    [
      #("id", int.to_string(v.id)),
      #("name", v.name),
      #("logs", util.list_to_string(v.logs, int.to_string)),
    ]
    |> dict.from_list
  })
  |> gsv.from_dicts(separator: ";", line_ending: gsv.Windows)
  |> Ok
}

fn logs_to_csv(
  query_return: Result(pog.Returned(sql.ExportLogsRow), Error),
) -> Result(String, Error) {
  use pog.Returned(count: _, rows:) <- result.try(query_return)

  list.map(rows, fn(row) {
    [
      #("message", row.message),
      #("module", row.module),
      #("function", row.function),
      #("file", row.file),

      #("tags", util.list_to_string(row.tags, int.to_string)),
      #("occurrences", util.list_to_string(row.occurrences, int.to_string)),

      #("level", util.level_encoder(row.level)),

      #("id", int.to_string(row.id)),
      #("arity", int.to_string(row.arity)),
      #("line", int.to_string(row.line)),
      #("last_occurrence", int.to_string(row.last_occurrence)),

      #("resolved", bool.to_string(row.resolved)),
      #("muted", bool.to_string(row.muted)),
    ]
    |> dict.from_list
  })
  |> gsv.from_dicts(separator: ";", line_ending: gsv.Windows)
  |> Ok
}

fn log2tag_to_csv(
  query_return: Result(pog.Returned(sql.ExportLogToTagRow), Error),
) -> Result(String, Error) {
  use pog.Returned(count: _, rows:) <- result.try(query_return)

  list.map(rows, fn(row) {
    [
      #("log", int.to_string(row.log)),
      #("tag", int.to_string(row.tag)),
    ]
    |> dict.from_list
  })
  |> gsv.from_dicts(separator: ";", line_ending: gsv.Windows)
  |> Ok
}

/// Middleware to intercept http requests to entomologist specific paths
///
/// the following paths and methods are intercepted:
/// - GET /dev/entomologist: Renders a list with all logs
///
/// - POST /dev/entomologist: Submits a search query
///
/// - GET /dev/entomologist/[number]:
///     Renders the details about a log, including occurrences of said log,
///     details about the occurence, location...
///
/// - POST /dev/entomologist/[number]/tag:
///     Adds a tag to the given post.
///
/// - GET /dev/entomologist/css: Serves the CSS for the intercepted pages
///
/// # Usage example
/// [Wisp integration](https://hexdocs.pm/entomologist_extensions/wisp-integration.html)
pub fn wisp_middleware(
  request: Request,
  connection: Connection,
  callback: fn() -> Response,
) -> Response {
  case wisp.path_segments(request), request {
    ["dev", "entomologist"], Request(method: http.Get, ..) ->
      routes.get_entomologist(connection)

    ["dev", "entomologist", "search"], Request(method: http.Get, ..) ->
      routes.get_search(request, connection)

    ["dev", "entomologist", "css"], Request(method: http.Get, ..) ->
      wisp.response(200)
      |> wisp.set_header("content-type", "text/css")
      |> wisp.set_body(wisp.Text(css))
      |> wisp.set_body(wisp.File("resources/styles.css", 0, option.None))

    ["dev", "entomologist", id], Request(method: http.Get, ..) ->
      routes.get_id(id, connection)

    ["dev", "entomologist", id, "tag"], Request(method: http.Post, ..) ->
      routes.post_tag(id, request, connection)

    _, _ -> callback()
  }
}

fn create_pool(
  pool_name pool_name: process.Name(pog.Message),
) -> Result(actor.Started(supervisor.Supervisor), actor.StartError) {
  let pool =
    pog.default_config(pool_name)
    |> pog.host("localhost")
    |> pog.password(option.Some("postgres"))
    |> pog.pool_size(15)
    |> pog.supervised

  supervisor.new(supervisor.RestForOne)
  |> supervisor.add(pool)
  |> supervisor.start()
}

const css = ":root{color-scheme:dark;font-size:100%;--measure:60vw;--ratio:1.5;--color:#f8e3c4;--main-color:#6b1fb1;--accent-color:#cc3495;--bg-color:#0b0630;--s0:1rem;--s1:calc(var(--s0) * var(--ratio));--s2:calc(var(--s1) * var(--ratio));--s3:calc(var(--s2) * var(--ratio));--s4:calc(var(--s3) * var(--ratio));--s5:calc(var(--s4) * var(--ratio));--s-1:calc(var(--s0) / var(--ratio));--s-2:calc(var(--s-1) / var(--ratio));--s-3:calc(var(--s-2) / var(--ratio));--s-4:calc(var(--s-3) / var(--ratio));--s-5:calc(var(--s-4) / var(--ratio));--s-6:calc(var(--s-5) / var(--ratio));--s-7:calc(var(--s-6) / var(--ratio));--s-8:calc(var(--s-7) / var(--ratio));--s-9:calc(var(--s-8) / var(--ratio))}::selection{background:var(--main-color)}*{font-optical-sizing:auto;box-sizing:border-box;max-inline-size:var(--measure);line-height:var(--ratio);border:0;margin:0;padding:0;font-family:system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif;font-style:normal;color:var(--color)}em{font-style:italic}body,centernav,div,footer,header,html,main{max-inline-size:none}img,table,video{max-width:100%}h1,h2,h3,h4,h5,h6,p{text-wrap:pretty;@-moz-document url-prefix(){text-wrap:wrap}}h1{font-weight:bold;max-inline-size:7ch;font-size:var(--s3);line-height:var(--s3)}h2{font-weight:bold;font-size:var(--s1);line-height:var(--s2)}h3{font-weight:bold;font-size:var(--s1);line-height:var(--s1)}html{background-color:var(--bg-color);height:100%}header{background:var(--accent-color);color:var(--bg-color);padding-inline:var(--s0);padding-block:var(--s-2)}header a:visited{background:var(--accent-color);color:var(--bg-color)}main{min-height:100dvh;padding-inline:var(--s4);padding-block:var(--s2)}hr{border:none;border-bottom:1px solid color-mix(in oklab, var(--color) 50%, transparent)}a{color:var(--main-color);font-weight:bold;font-style:inherit;text-decoration:none}a:hover{text-decoration:underline}a:visited{color:var(--accent-color)}svg{width:1rem;height:1rem}.stack{display:flex;flex-direction:column;justify-content:flex-start}.stack > *{margin-block:0}.stack > *+*{margin-block-start:var(--s0)}.stack-row{display:flex;flex-direction:row;justify-content:flex-start}.stack-row > *{margin-inline:0}.stack-row > *+*{margin-inline-start:var(--s0)}.box{padding:var(--s1);color:inherit}.switcher{display:flex;flex-wrap:wrap;gap:var(--s1);--threshold:30rem}.switcher > *{flex-grow:1;flex-basis:calc((var(--threshold) - 100%) * 999)}.center{box-sizing:content-box;max-inline-size:var(--measure);margin-inline:auto;padding-inline-start:var(--s1);padding-inline-end:var(--s1)}.with-sidebar{display:flex;flex-wrap:wrap;gap:var(--s1)}.with-sidebar > :last-child{flex-basis:11em;flex-grow:1}.with-sidebar > :first-child{flex-basis:0;flex-grow:999;min-inline-size:50%}.sidebar-left{display:flex;flex-wrap:wrap;gap:var(--s1)}.sidebar-left > :first-child{flex-basis:10%;flex-grow:1}.sidebar-left > :last-child{flex-basis:0;flex-grow:999;min-inline-size:75%}.grid{display:grid;grid-gap:1rem;--minimum:20ch}@supports (width: min(var(--minimum), 100%)){.grid{grid-template-columns:repeat(auto-fit, minmax(min(var(--minimum), 100%), 1fr))}}.cluster{display:flex;flex-wrap:wrap;gap:var(--space, 1rem);justify-content:center;align-items:center}.log-box{border:var(--s-5) solid var(--color);background-color:var(--bg-color);box-shadow:var(--s-3) var(--s-3) var(--accent-color)}.occurrence-box{border:var(--s-5) solid var(--color);background-color:var(--bg-color);box-shadow:var(--s-3) var(--s-3) var(--accent-color)}.fields-box{border:var(--s-5) solid var(--color);background-color:var(--bg-color);box-shadow:var(--s-3) var(--s-3) var(--accent-color);padding:var(--s-1);height:auto;overflow:auto}.contents-box{padding:inherit;color:var(--accent-color)}.tag-box{border:var(--s-5) solid var(--color);background-color:var(--bg-color);box-shadow:var(--s-3) var(--s-3) var(--accent-color);padding:var(--s-1);height:auto;overflow:auto}.unstyled-list{list-style-type:none;padding-inline-start:0}.red{--color:#cc5151}.blue{--color:#7bbdf7}.green{--color:#bdf77b}.yellow{--color:#f7f37b}select{position:relative;top:0;left:0;transition:top 0.3s, left 0.3s, box-shadow 0.3s}select:focus{background:var(--accent-color);color:var(--bg-color);box-shadow:0 0 var(--accent-color);top:var(--s-4);left:var(--s-4);box-shadow:0 0 var(--accent-color);transition:top 0.3s, left 0.3s, box-shadow 0.3s}input{position:relative;top:0;left:0;transition:top 0.3s, left 0.3s, box-shadow 0.3s}input:focus{background:var(--accent-color);color:var(--bg-color);box-shadow:0 0 var(--accent-color);top:var(--s-4);left:var(--s-4);box-shadow:0 0 var(--accent-color);transition:top 0.3s, left 0.3s, box-shadow 0.3s}textarea{position:relative;top:0;left:0;transition:top 0.3s, left 0.3s, box-shadow 0.3s}textarea:focus{background:var(--accent-color);color:var(--bg-color);box-shadow:0 0 var(--accent-color);top:var(--s-4);left:var(--s-4);box-shadow:0 0 var(--accent-color);transition:top 0.3s, left 0.3s, box-shadow 0.3s}button{position:relative;top:0;left:0;width:auto;padding:var(--s-5);background:var(--bg-color);border:var(--s-9) solid var(--color);box-shadow:var(--s-4) var(--s-4) var(--accent-color);transition:top 0.3s, left 0.3s, box-shadow 0.3s}button:hover{top:var(--s-4);left:var(--s-4);box-shadow:0 0 var(--accent-color)}button:active{background:var(--accent-color);color:var(--bg-color)}.form-field{height:var(--s2);background:var(--bg-color);border:var(--s-9) solid var(--color);box-shadow:var(--s-3) var(--s-3) var(--accent-color)}select{text-indent:0.4ch}.search-btn{width:25%;height:var(--s3)}.search-txt{width:75%;height:var(--s3)}.search-txt{width:75%;height:var(--s3)}.fields-header{padding:0 var(--s1) var(--s1);justify-content:space-between}.round{border-radius:50%;aspect-ratio:1;width:auto;height:100%;font-size:calc(var(--size) / 1.5)}.flex{display:flex}.plus-button-flex{width:var(--size);justify-content:center}hgroup h1,hgroup h2,hgroup h3,hgroup h4,hgroup h5,hgroup h6,hgroup p{padding:var(--s-3)}"
