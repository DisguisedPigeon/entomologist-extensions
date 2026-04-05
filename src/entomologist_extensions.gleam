//// This module contains the extra entomologist functionality.
////
//// Examples of usage are linked in the function documentation if avaliable

import entomologist
import entomologist_extensions/internal/ui/html_components
import gleam/float
import gleam/http
import gleam/http/request.{Request}
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/result
import gleam/time/timestamp
import lustre/element
import pog.{type Connection}
import wisp

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
/// - GET /dev/entomologist/css: Serves the CSS for the intercepted pages
///
/// # Usage example
/// [Wisp integration](https://hexdocs.pm/entomologist_extensions/wisp-integration.html)
pub fn wisp_middleware(
  request: wisp.Request,
  connection: Connection,
  callback: fn() -> wisp.Response,
) -> wisp.Response {
  case wisp.path_segments(request), request {
    ["dev", "entomologist", "css"], Request(method: http.Get, ..) ->
      wisp.response(200)
      |> wisp.set_header("content-type", "text/css")
      |> wisp.set_body(wisp.Text(css))

    ["dev", "entomologist", id], Request(method: http.Get, ..) ->
      {
        use id <- result.try(int.parse(id))
        use error <- result.try(
          entomologist.log_data(id, connection)
          |> result.map_error(fn(_) { Nil }),
        )

        case entomologist.occurrences(id, connection) {
          Ok(l) ->
            {
              "<!DOCTYPE html>"
              <> html_components.wisp_occurrences(l, error) |> element.to_string
            }
            |> wisp.html_response(200)
            |> Ok
          Error(s) -> {
            echo "Errored with data: " <> s
            Error(Nil)
          }
        }
      }
      |> result.unwrap(wisp.not_found())

    ["dev", "entomologist"], Request(method: http.Post, ..) -> {
      use data <- wisp.require_form(request)

      case
        data.values
        |> list.fold(
          entomologist.default_search_data(),
          extract_log_search_field,
        )
        |> entomologist.search(connection, _)
      {
        Ok(logs) ->
          {
            "<!DOCTYPE html>"
            <> html_components.wisp_logs(logs)
            |> element.to_string
          }
          |> wisp.html_response(200)
        Error(_) -> wisp.internal_server_error()
      }
    }
    _, _ -> callback()
  }
}

fn extract_log_search_field(
  acc: entomologist.SearchData,
  value: #(String, String),
) -> entomologist.SearchData {
  case value {
    #(_, "") -> acc
    #("message", message) ->
      entomologist.SearchData(..acc, message: Some(message))
    #("arity", arity) -> {
      use arity <- result_guard(int.parse(arity), acc)
      entomologist.SearchData(..acc, arity: Some(arity))
    }
    #("file", file) -> entomologist.SearchData(..acc, file: Some(file))
    #("function", function) ->
      entomologist.SearchData(..acc, function: Some(function))
    #("occurrence_range_start", occurrence_range_start) -> {
      let occurrence_range_start =
        timestamp.parse_rfc3339(occurrence_range_start <> "T00:00:00Z")
      use occurrence_range_start <- result_guard(occurrence_range_start, acc)
      let occurrence_range_start =
        timestamp.to_unix_seconds(occurrence_range_start)
        |> float.round
        |> Some

      entomologist.SearchData(..acc, occurrence_range_start:)
    }
    #("occurrence_range_end", occurrence_range_end) -> {
      use occurrence_range_end <- result_guard(
        timestamp.parse_rfc3339(occurrence_range_end <> "T00:00:00Z"),
        acc,
      )
      let occurrence_range_end =
        timestamp.to_unix_seconds(occurrence_range_end)
        |> float.round
        |> Some
      entomologist.SearchData(..acc, occurrence_range_end:)
    }
    #("level", level) -> {
      use level <- result_guard(parse_level(level), acc)
      entomologist.SearchData(..acc, level: Some(level))
    }
    #("line", line) -> {
      use line <- result_guard(int.parse(line), acc)
      entomologist.SearchData(..acc, line: Some(line))
    }
    #("module", module) -> entomologist.SearchData(..acc, module: Some(module))
    #("resolved", "resolved") ->
      entomologist.SearchData(..acc, resolved: Some(True))
    #("resolved", "unresolved") ->
      entomologist.SearchData(..acc, resolved: Some(False))
    #("muted", "muted") -> entomologist.SearchData(..acc, muted: Some(True))
    #("muted", "unmuted") -> entomologist.SearchData(..acc, muted: Some(False))
    _ -> acc
  }
}

fn parse_level(level: String) -> Result(entomologist.Level, Nil) {
  case level {
    "alert" -> Ok(entomologist.Alert)
    "critical" -> Ok(entomologist.Critical)
    "debug" -> Ok(entomologist.Debug)
    "emergency" -> Ok(entomologist.Emergency)
    "error" -> Ok(entomologist.ErrorLevel)
    "info" -> Ok(entomologist.Info)
    "notice" -> Ok(entomologist.Notice)
    "warning" -> Ok(entomologist.Warning)
    _ -> Error(Nil)
  }
}

const css = ":root{color-scheme:dark;font-size:100%;--measure:60vw;--ratio:1.5;--color:#f8e3c4;--main-color:#6b1fb1;--accent-color:#cc3495;--bg-color:#0b0630;--s0:1rem;--s1:calc(var(--s0) * var(--ratio));--s2:calc(var(--s1) * var(--ratio));--s3:calc(var(--s2) * var(--ratio));--s4:calc(var(--s3) * var(--ratio));--s5:calc(var(--s4) * var(--ratio));--s-1:calc(var(--s0) / var(--ratio));--s-2:calc(var(--s-1) / var(--ratio));--s-3:calc(var(--s-2) / var(--ratio));--s-4:calc(var(--s-3) / var(--ratio));--s-5:calc(var(--s-4) / var(--ratio));--s-6:calc(var(--s-5) / var(--ratio));--s-7:calc(var(--s-6) / var(--ratio));--s-8:calc(var(--s-7) / var(--ratio));--s-9:calc(var(--s-8) / var(--ratio))}::selection{background:var(--main-color)}*{font-optical-sizing:auto;box-sizing:border-box;max-inline-size:var(--measure);line-height:var(--ratio);border:0;margin:0;padding:0;font-family:system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif;font-style:normal;color:var(--color)}em{font-style:italic}body,centernav,div,footer,header,html,main{max-inline-size:none}img,table,video{max-width:100%}h1,h2,h3,h4,h5,h6,p{text-wrap:pretty;@-moz-document url-prefix(){text-wrap:wrap}}h1{font-weight:bold;max-inline-size:7ch;font-size:var(--s3);line-height:var(--s3)}h2{font-weight:bold;font-size:var(--s1);line-height:var(--s2)}h3{font-weight:bold;font-size:var(--s1);line-height:var(--s1)}html{background-color:var(--bg-color);height:100%}header{background:var(--accent-color);color:var(--bg-color);padding-inline:var(--s0);padding-block:var(--s-2)}header a:visited{background:var(--accent-color);color:var(--bg-color)}main{min-height:100dvh;padding-inline:var(--s4);padding-block:var(--s2)}hr{border:none;border-bottom:1px solid color-mix(in oklab, var(--color) 50%, transparent)}a{color:var(--main-color);font-weight:bold;font-style:inherit;text-decoration:none}a:hover{text-decoration:underline}a:visited{color:var(--accent-color)}svg{width:1rem;height:1rem}.stack{display:flex;flex-direction:column;justify-content:flex-start}.stack > *{margin-block:0}.stack > *+*{margin-block-start:var(--s0)}.stack-row{display:flex;flex-direction:row;justify-content:flex-start}.stack-row > *{margin-inline:0}.stack-row > *+*{margin-inline-start:var(--s0)}.box{padding:var(--s1);color:inherit}.switcher{display:flex;flex-wrap:wrap;gap:var(--s1);--threshold:30rem}.switcher > *{flex-grow:1;flex-basis:calc((var(--threshold) - 100%) * 999)}.center{box-sizing:content-box;max-inline-size:var(--measure);margin-inline:auto;padding-inline-start:var(--s1);padding-inline-end:var(--s1)}.with-sidebar{display:flex;flex-wrap:wrap;gap:var(--s1)}.with-sidebar > :last-child{flex-basis:11em;flex-grow:1}.with-sidebar > :first-child{flex-basis:0;flex-grow:999;min-inline-size:50%}.sidebar-left{display:flex;flex-wrap:wrap;gap:var(--s1)}.sidebar-left > :first-child{flex-basis:10%;flex-grow:1}.sidebar-left > :last-child{flex-basis:0;flex-grow:999;min-inline-size:75%}.grid{display:grid;grid-gap:1rem;--minimum:20ch}@supports (width: min(var(--minimum), 100%)){.grid{grid-template-columns:repeat(auto-fit, minmax(min(var(--minimum), 100%), 1fr))}}.cluster{display:flex;flex-wrap:wrap;gap:var(--space, 1rem);justify-content:center;align-items:center}.log-box{border:var(--s-5) solid var(--color);background-color:var(--bg-color);box-shadow:var(--s-3) var(--s-3) var(--accent-color)}.occurrence-box{border:var(--s-5) solid var(--color);background-color:var(--bg-color);box-shadow:var(--s-3) var(--s-3) var(--accent-color)}.fields-box{border:var(--s-5) solid var(--color);background-color:var(--bg-color);box-shadow:var(--s-3) var(--s-3) var(--accent-color);padding:var(--s-1);height:auto;overflow:auto}.contents-box{padding:inherit;color:var(--accent-color)}.tag-box{border:var(--s-5) solid var(--color);background-color:var(--bg-color);box-shadow:var(--s-3) var(--s-3) var(--accent-color);padding:var(--s-1);height:auto;overflow:auto}.unstyled-list{list-style-type:none;padding-inline-start:0}.red{--color:#cc5151}.blue{--color:#7bbdf7}.green{--color:#bdf77b}.yellow{--color:#f7f37b}select{position:relative;top:0;left:0;transition:top 0.3s, left 0.3s, box-shadow 0.3s}select:focus{background:var(--accent-color);color:var(--bg-color);box-shadow:0 0 var(--accent-color);top:var(--s-4);left:var(--s-4);box-shadow:0 0 var(--accent-color);transition:top 0.3s, left 0.3s, box-shadow 0.3s}input{position:relative;top:0;left:0;transition:top 0.3s, left 0.3s, box-shadow 0.3s}input:focus{background:var(--accent-color);color:var(--bg-color);box-shadow:0 0 var(--accent-color);top:var(--s-4);left:var(--s-4);box-shadow:0 0 var(--accent-color);transition:top 0.3s, left 0.3s, box-shadow 0.3s}textarea{position:relative;top:0;left:0;transition:top 0.3s, left 0.3s, box-shadow 0.3s}textarea:focus{background:var(--accent-color);color:var(--bg-color);box-shadow:0 0 var(--accent-color);top:var(--s-4);left:var(--s-4);box-shadow:0 0 var(--accent-color);transition:top 0.3s, left 0.3s, box-shadow 0.3s}button{position:relative;top:0;left:0;width:auto;padding:var(--s-5);background:var(--bg-color);border:var(--s-9) solid var(--color);box-shadow:var(--s-4) var(--s-4) var(--accent-color);transition:top 0.3s, left 0.3s, box-shadow 0.3s}button:hover{top:var(--s-4);left:var(--s-4);box-shadow:0 0 var(--accent-color)}button:active{background:var(--accent-color);color:var(--bg-color)}.form-field{height:var(--s2);background:var(--bg-color);border:var(--s-9) solid var(--color);box-shadow:var(--s-3) var(--s-3) var(--accent-color)}select{text-indent:0.4ch}.search-btn{width:25%;height:var(--s3)}.search-txt{width:75%;height:var(--s3)}.search-txt{width:75%;height:var(--s3)}.fields-header{padding:0 var(--s1) var(--s1);justify-content:space-between}.round{border-radius:50%;aspect-ratio:1;width:auto;height:100%;font-size:calc(var(--size) / 1.5)}.flex{display:flex}.plus-button-flex{width:var(--size);justify-content:center}hgroup h1,hgroup h2,hgroup h3,hgroup h4,hgroup h5,hgroup h6,hgroup p{padding:var(--s-3)}"
