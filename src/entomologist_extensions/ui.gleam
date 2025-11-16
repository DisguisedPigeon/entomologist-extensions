import entomologist
import entomologist_extensions/ui/html_components
import gleam/http
import gleam/http/request.{Request}
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/result
import lustre/element
import pog.{type Connection}
import wisp

/// Middleware to intercept http requests to entomologist specific paths
///
/// the following paths and methods are intercepted:
/// - GET /dev/entomologist
/// - POST /dev/entomologist
/// - GET /dev/entomologist/css
/// - GET /dev/entomologist/[number]
/// - POST /dev/entomologist/[number]
///
/// ## Usage example
/// ```gleam
/// import wisp.{type Request, type Response}
/// import entomologist_extensions/ui
///
/// // type Context {
/// //   Context(connection: pog.Connection, ...)
/// // }
///
/// fn middlewares(request: Request, context: Context, callback: fn(Request) -> Response) -> Response {
///   use <- ui.wisp_middleware(request, connection, callback)
///   callback(request)
/// }
/// ```
pub fn wisp_middleware(
  request: wisp.Request,
  connection: Connection,
  callback: fn() -> wisp.Response,
) -> wisp.Response {
  case wisp.path_segments(request), request {
    ["dev", "entomologist", "css"], Request(method: http.Get, ..) ->
      wisp.response(200)
      |> wisp.set_header("content-type", "text/css")
      |> wisp.set_body(
        css
        |> wisp.Text,
      )
      |> wisp.set_body(wisp.File(
        "../entomologist_extensions/resources/styles.css",
        limit: option.None,
        offset: 0,
      ))
    ["dev", "entomologist"], Request(method: http.Get, ..) ->
      case entomologist.show(connection) {
        Ok(data) -> {
          {
            "<!DOCTYPE html>"
            <> html_components.wisp_logs(data) |> element.to_string
          }
          |> wisp.html_response(200)
        }
        _ -> wisp.internal_server_error()
      }

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
            echo s
            Error(Nil)
          }
        }
      }
      |> result.unwrap(wisp.not_found())

    //  TODO : Occurrences search
    ["dev", "entomologist", id], Request(method: http.Post, ..) -> {
      let assert Ok(_id) = int.parse(id)
      wisp.unsupported_media_type([])
      // use data <- wisp.require_form(request)
      // case entomologist.search {
      //
      // }
    }
    ["dev", "entomologist"], Request(method: http.Post, ..) -> {
      use data <- wisp.require_form(request)
      echo data

      case
        data.values
        |> list.fold(entomologist.default_search_data(), extract_field)
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

fn extract_field(
  acc: entomologist.SearchData,
  value: #(String, String),
) -> entomologist.SearchData {
  case value {
    #(_, "") -> acc
    #("arity", arity) -> {
      use arity <- result_guard(int.parse(arity), acc)
      entomologist.SearchData(..acc, arity: Some(arity))
    }
    #("file", file) -> entomologist.SearchData(..acc, file: Some(file))
    #("function", function) ->
      entomologist.SearchData(..acc, function: Some(function))
    #("last_occurrence", last_occurrence) -> {
      use last_occurrence <- result_guard(int.parse(last_occurrence), acc)
      entomologist.SearchData(..acc, last_occurrence: Some(last_occurrence))
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
    #("snoozed", "snoozed") ->
      entomologist.SearchData(..acc, snoozed: Some(True))
    #("snoozed", "awake") ->
      entomologist.SearchData(..acc, snoozed: Some(False))
    // TODO: message filtering
    #("message", _message) -> acc
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

fn result_guard(result: Result(a, b), return: c, cb: fn(a) -> c) -> c {
  case result {
    Ok(a) -> cb(a)
    Error(_) -> return
  }
}

const css = "header,th{background-color:var(--color-underwater_blue)}td[class=id],th{text-align:center}.flex-row,main,nav,section{display:flex}:root{font-family:sans-serif;--color-faff_pink:#ffaff3;--color-gleam_white:#fefefc;--color-unnamed_blue:#a6f0fc;--color-aged_plastic_yellow:#fffbe8;--color-unexpected_aubergine:#584355;--color-underwater_blue:#292d3e;--color-charcoal:#2f2f2f;--color-gleam_black:#1e1e1e;--color-blacker:#151515}body{background-color:var(--color-blacker);color:var(--color-gleam_white)}header{padding:.5rem;margin:0 0 2rem}nav{margin:auto;flex-direction:row;max-width:80%;justify-content:flex-start}main{align-items:center;flex-direction:column;width:100%}section{padding:0 2.5rem;width:60%;justify-content:center}table{width:100%;table-layout:fixed;font-size:.875rem;line-height:calc(1.25 / .875);text-align:left;border-collapse:collapse}td,th,tr{border:1px solid #000}thead{font-size:.75rem}.title,.title:visited,span{font-size:1.125rem;line-height:calc(1.75/1.25);text-decoration:none}th[class=id]{width:2rem;max-width:2rem}th[class=level]{width:6rem;max-width:6rem}th[class=occurrence]{max-width:15rem;width:12rem}th{padding:1rem 1.5rem}td{height:4rem;background-color:#1f212e;font-weight:500;padding:.5rem 1.5rem}td:hover .flex-row button[class=copy]:hover{background-color:rgba(255,255,255,.2);color:var(--color-gleam_white)}td:hover .flex-row button[class=copy]{background-color:rgba(255,255,255,0);color:rgba(255,255,255,.1);border:1px solid;box-shadow:3px 3px 6px rgba(0,0,0,.1)}button[class=copy]{position:absolute;top:50%;left:100%;-ms-transform:translate(-50%,-50%);transform:translate(-50%,-50%);transition:.5s;max-height:1.7em;height:1.7em;max-width:2em;width:2em;background-color:rgba(255,255,255,0);color:rgba(255,255,255,0);border:0;border-radius:5px;box-shadow:0 0 transparent}button[class=search],input{padding:.5rem;border:none;background-color:var(--color-underwater_blue);color:var(--color-gleam_white);margin:1rem}button[class=search]{width:20%}input{width:80%}a:visited{color:var(--color-unexpected_aubergine)}a{color:var(--color-unnamed_blue)}span{margin-left:1em;margin-right:1em}.flex-row{flex-direction:row;justify-content:space-between;position:relative;width:100%;height:100%}.block{display:block;max-height:4rem;max-width:90%;overflow:auto;word-break:break-word}.title,.title:visited{color:var(--color-faff_pink);font-weight:700}"
