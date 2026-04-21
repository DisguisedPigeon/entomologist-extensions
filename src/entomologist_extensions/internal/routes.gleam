import entomologist as ent
import entomologist_extensions/internal/ui/html_components
import entomologist_extensions/internal/util
import gleam/http/request
import gleam/int
import gleam/list
import gleam/string
import lustre/element
import pog.{type Connection} as db
import wisp.{type Request, type Response}

pub fn get_entomologist(connection: Connection) -> Response {
  use data <- util.result_guard(
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

pub fn get_search(request: Request, connection: Connection) -> Response {
  let query = request.get_query(request)

  use query <- util.result_guard(query, fn(_) {
    wisp.bad_request("no query provided")
  })

  let logs =
    list.fold(
      over: query,
      from: ent.default_search_data(),
      with: util.extract_log_search_fields,
    )
    |> ent.search(connection, _)

  use logs <- util.result_guard(
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

pub fn get_id(id: String, connection: Connection) -> Response {
  use id <- util.result_guard(int.parse(id), return: fn(_) {
    wisp.bad_request("id field is not a string")
  })

  use data <- util.result_guard(
    ent.log_data(id, connection),
    return: fn(message: String) {
      wisp.log_warning("failed retrieving log data: " <> message)
      wisp.internal_server_error()
    },
  )

  use occurrences <- util.result_guard(
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

pub fn post_tag(
  id: String,
  request: Request,
  connection: Connection,
) -> Response {
  use id: Int <- util.result_guard(
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

pub fn add_tag(
  tag_name: String,
  log_id: Int,
  connection: db.Connection,
) -> Response {
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
