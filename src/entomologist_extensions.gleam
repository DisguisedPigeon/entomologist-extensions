//// This module contains the extra entomologist functionality.
////
//// Examples of usage are linked in the function documentation if avaliable

import entomologist as ent
import entomologist_extensions/internal/ui/html_components
import gleam/float
import gleam/http
import gleam/http/request.{Request}
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/string
import gleam/time/timestamp
import lustre/element
import pog.{type Connection} as db
import wisp.{type Request, type Response}

/// Auxiliary function.
///
/// Calls the return() callback when result has value `Error`.
/// return should be small so callback can be handled by a `use`
fn result_guard(
  when_error result: Result(a, b),
  return return: fn(b) -> c,
  callback cb: fn(a) -> c,
) -> c {
  case result {
    Ok(a) -> cb(a)
    Error(v) -> return(v)
  }
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
      get_entomologist(connection)

    ["dev", "entomologist", "search"], Request(method: http.Get, ..) ->
      get_search(request, connection)

    ["dev", "entomologist", "css"], Request(method: http.Get, ..) ->
      wisp.response(200)
      |> wisp.set_header("content-type", "text/css")
      |> wisp.set_body(wisp.Text(css))
      |> wisp.set_body(wisp.File("resources/styles.css", 0, option.None))

    ["dev", "entomologist", id], Request(method: http.Get, ..) ->
      get_id(id, connection)

    ["dev", "entomologist", id, "tag"], Request(method: http.Post, ..) ->
      post_tag(id, request, connection)

    _, _ -> callback()
  }
}

fn get_entomologist(connection: Connection) -> Response {
  use data <- result_guard(
    when_error: ent.show(connection),
    return: fn(message: String) -> Response {
      wisp.log_warning(message)
      wisp.internal_server_error()
    },
  )

  let html =
    html_components.wisp_logs(data)
    |> element.to_string

  wisp.html_response("<!DOCTYPE html>\n" <> html, 200)
}

fn get_search(request: Request, connection: Connection) -> Response {
  let query = request.get_query(request)

  use query <- result_guard(query, fn(_) {
    wisp.bad_request("no query provided")
  })

  let logs =
    list.fold(
      over: query,
      from: ent.default_search_data(),
      with: extract_log_search_fields,
    )
    |> ent.search(connection, _)

  use logs <- result_guard(
    when_error: logs,
    return: fn(message: String) -> Response {
      wisp.log_warning(message)
      wisp.internal_server_error()
    },
  )

  let html =
    html_components.wisp_logs(logs)
    |> element.to_string

  wisp.html_response("<!DOCTYPE html>\n" <> html, 200)
}

fn get_id(id: String, connection: Connection) -> Response {
  use id <- result_guard(int.parse(id), return: fn(_) {
    wisp.bad_request("id field is not a string")
  })

  use data <- result_guard(
    ent.log_data(id, connection),
    return: fn(message: String) {
      wisp.log_warning("failed retrieving log data: " <> message)
      wisp.internal_server_error()
    },
  )

  use occurrences <- result_guard(
    ent.occurrences(id, connection),
    return: fn(message: String) {
      wisp.log_warning("failed retrieving occurrences: " <> message)
      wisp.internal_server_error()
    },
  )

  let html =
    html_components.wisp_occurrences(occurrences, data)
    |> element.to_string

  wisp.html_response("<!DOCTYPE html>\n" <> html, 200)
}

fn post_tag(id: String, request: Request, connection: Connection) -> Response {
  use id: Int <- result_guard(
    when_error: int.parse(id),
    return: fn(_: Nil) -> Response { wisp.bad_request("id must be a number") },
  )
  use data <- wisp.require_form(request)

  case data.values {
    [#("tag", v)] -> add_tag(v, id, connection)
    [_] -> wisp.bad_request("The tags should be encoded as tag=[NAME]")
    [] -> wisp.bad_request("Some tag must be provided")
    _ -> wisp.bad_request("Only a tag should be provided")
  }
}

fn add_tag(tag_name: String, log_id: Int, connection: db.Connection) -> Response {
  case ent.add_tag(connection, log_id, tag_name) {
    Ok(Nil) -> wisp.redirect("/dev/entomologist/" <> int.to_string(log_id))
    //Error() -> wisp.redirect("/dev/entomologist/" <> int.to_string(log_id))
    Error(str) -> {
      let duplicate_response =
        "Query: add_tag - Constraint violated: logtag_pkey"

      case string.starts_with(str, duplicate_response) {
        True -> wisp.redirect("/dev/entomologist/" <> int.to_string(log_id))
        False -> {
          wisp.log_warning(str)
          wisp.internal_server_error()
        }
      }
    }
  }
}

fn extract_log_search_fields(
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

fn parse_level(level: String) -> Result(ent.Level, Nil) {
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

const css = ":root{color-scheme:dark;font-size:100%;--measure:60vw;--ratio:1.5;--color:#f8e3c4;--main-color:#6b1fb1;--accent-color:#cc3495;--bg-color:#0b0630;--s0:1rem;--s1:calc(var(--s0) * var(--ratio));--s2:calc(var(--s1) * var(--ratio));--s3:calc(var(--s2) * var(--ratio));--s4:calc(var(--s3) * var(--ratio));--s5:calc(var(--s4) * var(--ratio));--s-1:calc(var(--s0) / var(--ratio));--s-2:calc(var(--s-1) / var(--ratio));--s-3:calc(var(--s-2) / var(--ratio));--s-4:calc(var(--s-3) / var(--ratio));--s-5:calc(var(--s-4) / var(--ratio));--s-6:calc(var(--s-5) / var(--ratio));--s-7:calc(var(--s-6) / var(--ratio));--s-8:calc(var(--s-7) / var(--ratio));--s-9:calc(var(--s-8) / var(--ratio))}::selection{background:var(--main-color)}*{font-optical-sizing:auto;box-sizing:border-box;max-inline-size:var(--measure);line-height:var(--ratio);border:0;margin:0;padding:0;font-family:system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif;font-style:normal;color:var(--color)}em{font-style:italic}body,centernav,div,footer,header,html,main{max-inline-size:none}img,table,video{max-width:100%}h1,h2,h3,h4,h5,h6,p{text-wrap:pretty;@-moz-document url-prefix(){text-wrap:wrap}}h1{font-weight:bold;max-inline-size:7ch;font-size:var(--s3);line-height:var(--s3)}h2{font-weight:bold;font-size:var(--s1);line-height:var(--s2)}h3{font-weight:bold;font-size:var(--s1);line-height:var(--s1)}html{background-color:var(--bg-color);height:100%}header{background:var(--accent-color);color:var(--bg-color);padding-inline:var(--s0);padding-block:var(--s-2)}header a:visited{background:var(--accent-color);color:var(--bg-color)}main{min-height:100dvh;padding-inline:var(--s4);padding-block:var(--s2)}hr{border:none;border-bottom:1px solid color-mix(in oklab, var(--color) 50%, transparent)}a{color:var(--main-color);font-weight:bold;font-style:inherit;text-decoration:none}a:hover{text-decoration:underline}a:visited{color:var(--accent-color)}svg{width:1rem;height:1rem}.stack{display:flex;flex-direction:column;justify-content:flex-start}.stack > *{margin-block:0}.stack > *+*{margin-block-start:var(--s0)}.stack-row{display:flex;flex-direction:row;justify-content:flex-start}.stack-row > *{margin-inline:0}.stack-row > *+*{margin-inline-start:var(--s0)}.box{padding:var(--s1);color:inherit}.switcher{display:flex;flex-wrap:wrap;gap:var(--s1);--threshold:30rem}.switcher > *{flex-grow:1;flex-basis:calc((var(--threshold) - 100%) * 999)}.center{box-sizing:content-box;max-inline-size:var(--measure);margin-inline:auto;padding-inline-start:var(--s1);padding-inline-end:var(--s1)}.with-sidebar{display:flex;flex-wrap:wrap;gap:var(--s1)}.with-sidebar > :last-child{flex-basis:11em;flex-grow:1}.with-sidebar > :first-child{flex-basis:0;flex-grow:999;min-inline-size:50%}.sidebar-left{display:flex;flex-wrap:wrap;gap:var(--s1)}.sidebar-left > :first-child{flex-basis:10%;flex-grow:1}.sidebar-left > :last-child{flex-basis:0;flex-grow:999;min-inline-size:75%}.grid{display:grid;grid-gap:1rem;--minimum:20ch}@supports (width: min(var(--minimum), 100%)){.grid{grid-template-columns:repeat(auto-fit, minmax(min(var(--minimum), 100%), 1fr))}}.cluster{display:flex;flex-wrap:wrap;gap:var(--space, 1rem);justify-content:center;align-items:center}.log-box{border:var(--s-5) solid var(--color);background-color:var(--bg-color);box-shadow:var(--s-3) var(--s-3) var(--accent-color)}.occurrence-box{border:var(--s-5) solid var(--color);background-color:var(--bg-color);box-shadow:var(--s-3) var(--s-3) var(--accent-color)}.fields-box{border:var(--s-5) solid var(--color);background-color:var(--bg-color);box-shadow:var(--s-3) var(--s-3) var(--accent-color);padding:var(--s-1);height:auto;overflow:auto}.contents-box{padding:inherit;color:var(--accent-color)}.tag-box{border:var(--s-5) solid var(--color);background-color:var(--bg-color);box-shadow:var(--s-3) var(--s-3) var(--accent-color);padding:var(--s-1);height:auto;overflow:auto}.unstyled-list{list-style-type:none;padding-inline-start:0}.red{--color:#cc5151}.blue{--color:#7bbdf7}.green{--color:#bdf77b}.yellow{--color:#f7f37b}select{position:relative;top:0;left:0;transition:top 0.3s, left 0.3s, box-shadow 0.3s}select:focus{background:var(--accent-color);color:var(--bg-color);box-shadow:0 0 var(--accent-color);top:var(--s-4);left:var(--s-4);box-shadow:0 0 var(--accent-color);transition:top 0.3s, left 0.3s, box-shadow 0.3s}input{position:relative;top:0;left:0;transition:top 0.3s, left 0.3s, box-shadow 0.3s}input:focus{background:var(--accent-color);color:var(--bg-color);box-shadow:0 0 var(--accent-color);top:var(--s-4);left:var(--s-4);box-shadow:0 0 var(--accent-color);transition:top 0.3s, left 0.3s, box-shadow 0.3s}textarea{position:relative;top:0;left:0;transition:top 0.3s, left 0.3s, box-shadow 0.3s}textarea:focus{background:var(--accent-color);color:var(--bg-color);box-shadow:0 0 var(--accent-color);top:var(--s-4);left:var(--s-4);box-shadow:0 0 var(--accent-color);transition:top 0.3s, left 0.3s, box-shadow 0.3s}button{position:relative;top:0;left:0;width:auto;padding:var(--s-5);background:var(--bg-color);border:var(--s-9) solid var(--color);box-shadow:var(--s-4) var(--s-4) var(--accent-color);transition:top 0.3s, left 0.3s, box-shadow 0.3s}button:hover{top:var(--s-4);left:var(--s-4);box-shadow:0 0 var(--accent-color)}button:active{background:var(--accent-color);color:var(--bg-color)}.form-field{height:var(--s2);background:var(--bg-color);border:var(--s-9) solid var(--color);box-shadow:var(--s-3) var(--s-3) var(--accent-color)}select{text-indent:0.4ch}.search-btn{width:25%;height:var(--s3)}.search-txt{width:75%;height:var(--s3)}.search-txt{width:75%;height:var(--s3)}.fields-header{padding:0 var(--s1) var(--s1);justify-content:space-between}.round{border-radius:50%;aspect-ratio:1;width:auto;height:100%;font-size:calc(var(--size) / 1.5)}.flex{display:flex}.plus-button-flex{width:var(--size);justify-content:center}hgroup h1,hgroup h2,hgroup h3,hgroup h4,hgroup h5,hgroup h6,hgroup p{padding:var(--s-3)}"
