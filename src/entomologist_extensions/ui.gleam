import entomologist.{type ErrorLog}
import gleam/http
import gleam/http/request.{Request}
import gleam/int
import gleam/json
import gleam/list
import gleam/string
import gleam/string_tree
import lustre/attribute.{attribute}
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/svg
import pog.{type Connection}
import wisp

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
        css()
        |> string_tree.from_string
        |> wisp.Text,
      )

    ["dev", "entomologist"], Request(method: http.Get, ..) -> {
      case entomologist.show(connection) {
        Ok(data) -> {
          wisp_document(data)
          |> wisp.html_response(200)
        }
        _ -> wisp.internal_server_error()
      }
    }
    _, _ -> callback()
  }
}

fn full_html(errors: List(ErrorLog)) -> Element(Nil) {
  html.html([attribute("lang", "en")], [
    html.head([], [
      html.meta([attribute("charset", "UTF-8")]),
      html.link([
        attribute.rel("stylesheet"),
        attribute.href("/dev/entomologist/css"),
      ]),
      //html.script(
      //  [attribute.src("https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4")],
      //  "",
      //),
      html.meta([
        attribute("content", "width=device-width, initial-scale=1.0"),
        attribute.name("viewport"),
      ]),
      html.script(
        [],
        "function copy(t){const e=document.getElementById(t).textContent;navigator.clipboard.writeText(e),alert('Copied '+e)}",
      ),
      html.title([], "Entomologist"),
    ]),
    html.body([], [header(), main(errors)]),
  ])
}

fn header() -> Element(Nil) {
  html.header([], [
    html.nav([], [
      html.a([attribute.href("#"), attribute.class("title")], [
        html.text(" Entomologist UI "),
      ]),
    ]),
  ])
}

fn main(errors: List(ErrorLog)) -> Element(Nil) {
  html.main([attribute.class("items-center flex flex-col w-full")], [
    html.section([], [table(errors)]),
  ])
}

fn table(errors: List(ErrorLog)) -> Element(Nil) {
  html.table(
    [attribute.class("w-full text-sm text-left rtl:text-right table-fixed")],
    [
      html.thead([attribute.class("text-xs uppercase bg-underwater_blue")], [
        html.tr([], [
          html.th([attribute("scope", "col"), attribute.class("id")], [
            html.text(" Id "),
          ]),
          html.th([attribute("scope", "col"), attribute.class("level")], [
            html.text(" Level "),
          ]),
          html.th([attribute("scope", "col")], [html.text(" Message ")]),
          html.th([attribute("scope", "col"), attribute.class("occurrence")], [
            html.text(" Last_occurrence "),
          ]),
        ]),
      ]),
      html.tbody(
        [],
        list.sort(errors, fn(e1, e2) {
          int.compare(e2.last_occurrence, e1.last_occurrence)
        })
          |> list.index_map(row(list.length(errors))),
      ),
    ],
  )
}

fn row(length: Int) -> fn(ErrorLog, Int) -> Element(Nil) {
  fn(el: ErrorLog, index: Int) -> Element(Nil) {
    case index {
      i if i == length - 1 -> last_row(el, i)
      i -> middle_row(el, i)
    }
  }
}

fn middle_row(el: ErrorLog, id: Int) -> Element(Nil) {
  html.tr([attribute.class("border-b bg-gray-900")], [
    el.id |> int.to_string |> id_cell,
    el.level |> entomologist.encode_level |> json.to_string |> cell(id, "level"),
    cell(el.message, id, "message"),
    el.last_occurrence |> int.to_string |> cell(id, "occurrence"),
  ])
}

fn last_row(el: ErrorLog, id) -> Element(Nil) {
  html.tr([attribute.class("bg-gray-900")], [
    el.id |> int.to_string |> id_cell,
    el.level |> entomologist.encode_level |> json.to_string |> cell(id, "level"),
    cell(el.message, id, "message"),
    el.last_occurrence |> int.to_string |> cell(id, "occurrence"),
  ])
}

fn id_cell(el: String) -> Element(Nil) {
  html.td([attribute.class("id"), attribute("scope", "row")], [html.text(el)])
}

fn cell(el: String, id: Int, ty: String) -> Element(Nil) {
  html.td([attribute("scope", "row")], [
    html.div(
      [attribute.class("flex-row"), attribute.id(int.to_string(id) <> ty)],
      [
        html.div(
          [attribute.class("block"), attribute.id(int.to_string(id) <> ty)],
          [html.text(el)],
        ),
        html.button(
          [attribute("onclick", "copy('" <> int.to_string(id) <> ty <> "')")],
          [svg_clipboard()],
        ),
      ],
    ),
  ])
}

fn wisp_document(errors: List(ErrorLog)) -> string_tree.StringTree {
  full_html(errors)
  |> element.to_string_tree
  |> string_tree.prepend("<!DOCTYPE html>")
}

fn svg_clipboard() {
  svg.svg(
    [
      attribute("viewBox", "0 0 16 16"),
      attribute.class("bi bi-clipboard"),
      attribute("fill", "currentColor"),
      attribute("height", "100%"),
      attribute("width", "100%"),
      attribute("xmlns", "http://www.w3.org/2000/svg"),
    ],
    [
      svg.path([
        attribute(
          "d",
          "M4 1.5H3a2 2 0 0 0-2 2V14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V3.5a2 2 0 0 0-2-2h-1v1h1a1 1 0 0 1 1 1V14a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1V3.5a1 1 0 0 1 1-1h1z",
        ),
      ]),
      svg.path([
        attribute(
          "d",
          "M9.5 1a.5.5 0 0 1 .5.5v1a.5.5 0 0 1-.5.5h-3a.5.5 0 0 1-.5-.5v-1a.5.5 0 0 1 .5-.5zm-3-1A1.5 1.5 0 0 0 5 1.5v1A1.5 1.5 0 0 0 6.5 4h3A1.5 1.5 0 0 0 11 2.5v-1A1.5 1.5 0 0 0 9.5 0z",
        ),
      ]),
    ],
  )
}

fn css() {
  "header,th{background-color:var(--color-underwater_blue)}td[class=id],th{text-align:center}button,td:hover .flex-row button{background-color:rgba(255,255,255,0)}.flex-row,main{display:flex;width:100%}:root{font-family:sans-serif;--color-faff_pink:#ffaff3;--color-gleam_white:#fefefc;--color-unnamed_blue:#a6f0fc;--color-aged_plastic_yellow:#fffbe8;--color-unexpected_aubergine:#584355;--color-underwater_blue:#292d3e;--color-charcoal:#2f2f2f;--color-gleam_black:#1e1e1e;--color-blacker:#151515}body{background-color:var(--color-blacker);color:var(--color-gleam_white)}header{padding:.5rem;margin:0 0 2rem}nav{margin:auto;display:flex;flex-direction:row;max-width:80%;justify-content:flex-start}main{align-items:center;flex-direction:column}section{padding:0 2.5rem;width:80%;display:flex;justify-content:center}table{width:80%;table-layout:fixed;font-size:.875rem;line-height:calc(1.25 / .875);text-align:left;border-collapse:collapse}td,th,tr{border:1px solid #000}thead{font-size:.75rem}th[class=id]{width:2rem;max-width:2rem}th[class=level]{width:6rem;max-width:6rem}th[class=occurrence]{max-width:15rem;width:12rem}th{padding:1rem 1.5rem}td{height:4rem;background-color:#1f212e;font-weight:500;padding:.5rem 1.5rem}td:hover .flex-row button:hover{background-color:rgba(255,255,255,.2);color:var(--color-gleam_white)}td:hover .flex-row button{color:rgba(255,255,255,.1);border:1px solid;box-shadow:3px 3px 6px rgba(0,0,0,.1)}button{position:absolute;top:50%;left:100%;-ms-transform:translate(-50%,-50%);transform:translate(-50%,-50%);transition:.5s;max-height:1.7em;height:1.7em;max-width:2em;width:2em;color:rgba(255,255,255,0);border:0;border-radius:5px;box-shadow:0 0 transparent}.flex-row{flex-direction:row;justify-content:space-between;position:relative;height:100%}.block{display:block;max-height:4rem;max-width:90%;overflow:auto;word-break:break-word}.title{color:var(--color-faff_pink);font-size:1.125rem;font-weight:700;line-height:calc(1.75/1.25);text-decoration:none}"
}
