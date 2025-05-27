import gleam/http
import gleam/http/request.{Request}
import gleam/string_tree
import lustre/attribute.{attribute}
import lustre/element.{type Element}
import lustre/element/html
import wisp

pub fn wisp_middleware(
  request: wisp.Request,
  callback: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  case wisp.path_segments(request), request {
    ["dev", "entomologist"], Request(method: http.Get, ..) -> {
      wisp_document()
      |> wisp.html_response(200)
    }
    _, _ -> callback(request)
  }
}

fn full_html() -> Element(Nil) {
  html.html([attribute("lang", "en")], [
    html.head([], [
      html.meta([attribute("charset", "UTF-8")]),
      html.meta([
        attribute("content", "width=device-width, initial-scale=1.0"),
        attribute.name("viewport"),
      ]),
      html.title([], "Entomologist"),
    ]),
    html.body([], [html.p([], [element.text("Hello world!")])]),
  ])
}

pub fn lustre_element() -> Element(Nil) {
  full_html()
}

fn wisp_document() -> string_tree.StringTree {
  full_html()
  |> element.to_string_tree
  |> string_tree.prepend("<!DOCTYPE html>")
}
