import entomologist.{type ErrorLog, type Occurrence, ErrorLog}
import gleam/int
import gleam/list
import gleam/option
import lustre/attribute.{attribute}
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/svg

/// Returns a string_tree with the rendered HTML for the given error list
pub fn wisp_logs(logs: List(ErrorLog)) -> Element(Nil) {
  root_template([header(""), logs_main(logs)])
}

/// Returns a string_tree with the rendered HTML for the given error and its occurrences
pub fn wisp_occurrences(
  occurrences: List(Occurrence),
  error: ErrorLog,
) -> Element(Nil) {
  root_template([
    header("Log " <> int.to_string(error.id)),
    occurrences_main(occurrences, error),
  ])
}

fn root_template(body) -> Element(Nil) {
  html.html([attribute("lang", "en")], [
    html.head([], [
      html.meta([attribute("charset", "UTF-8")]),
      html.link([
        attribute.rel("stylesheet"),
        attribute.href("/dev/entomologist/css"),
      ]),
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
    html.body([], body),
  ])
}

fn header(text: String) -> Element(Nil) {
  html.header([], [
    html.nav([], [
      html.a([attribute.href("/dev/entomologist"), attribute.class("title")], [
        html.text("󰦥 Entomologist UI"),
      ]),
      html.span([], [
        case text {
          "" -> html.text("")
          _ -> html.text("- " <> text)
        },
      ]),
    ]),
  ])
}

fn logs_main(logs: List(ErrorLog)) -> Element(Nil) {
  let post_target = "/dev/entomologist"

  html.main([], [
    html.section([], [search_bar(post_target:)]),
    html.section([], [logs_table(logs)]),
  ])
}

fn occurrences_main(
  occurrences: List(Occurrence),
  error: ErrorLog,
) -> Element(Nil) {
  let post_target = "/dev/entomologist/" <> int.to_string(error.id)

  html.main([], [
    html.section([], [error_description(error)]),
    html.section([], [search_bar(post_target:)]),
    html.section([], [occurrences_table(occurrences)]),
  ])
}

fn error_description(error: ErrorLog) -> Element(Nil) {
  let ErrorLog(
    id:,
    message:,
    level:,
    module:,
    function:,
    arity:,
    file:,
    line:,
    resolved:,
    last_occurrence:,
    snoozed:,
  ) = error

  html.div([attribute.class("error_details")], [
    html.div([attribute.class("internal_data")], [
      html.hgroup([], [
        html.h1([], [html.text("Log " <> int.to_string(id))]),
        html.p([], [html.text(message)]),
      ]),
      html.div([attribute.class("flex-row")], [
        html.p(
          [
            attribute.class("nopad nomar"),
            attribute.styles([#("margin-right", "1em")]),
          ],
          [html.text("Level: ")],
        ),
        level_to_element(level),
      ]),
      html.p([], [html.text("Module: " <> module)]),
      html.p([], [html.text("Function: " <> function)]),
      html.p([], [html.text("Arity: " <> int.to_string(arity))]),
      html.p([], [html.text("File: " <> file)]),
      html.p([], [html.text("Line: " <> int.to_string(line))]),
      html.p([], [
        html.text("Last_occurrence: " <> int.to_string(last_occurrence)),
      ]),
    ]),
    html.div([], [
      case resolved {
        True -> html.h1([attribute.class("ok")], [html.text("󱜙 Resolved")])
        False -> html.h1([attribute.class("nok")], [html.text(" Unresolved")])
      },
      case snoozed {
        True -> html.p([attribute.class("eepy")], [html.text("Sleeping 󰒲 ")])
        False -> html.p([attribute.class("aware")], [html.text("Not slept 󰒳 ")])
      },
    ]),
  ])
}

fn occurrences_table(occurrences: List(Occurrence)) -> Element(Nil) {
  html.table([], [
    html.thead([], [
      html.tr([], [
        html.th([attribute("scope", "col"), attribute.class("id")], [
          html.text(" Id "),
        ]),
        html.th([attribute("scope", "col"), attribute.class("timestamp")], [
          html.text(" Timestamp "),
        ]),
        html.th([attribute("scope", "col")], [html.text(" Full_log ")]),
      ]),
    ]),
    html.tbody(
      [],
      list.sort(occurrences, fn(e1, e2) {
        int.compare(e2.timestamp, e1.timestamp)
      })
        |> list.index_map(occurrence_row),
    ),
  ])
}

fn occurrence_row(el: Occurrence, id: Int) -> Element(Nil) {
  html.tr([], [
    el.id |> int.to_string |> occurrence_id_cell,
    cell(el.timestamp |> int.to_string, id, "message"),
    case el.full_contents {
      option.Some(e) -> e
      option.None -> ""
    }
      |> cell(id, "occurrence"),
  ])
}

fn logs_table(logs: List(ErrorLog)) -> Element(Nil) {
  html.table([], [
    html.thead([], [
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
      list.sort(logs, fn(e1, e2) {
        int.compare(e2.last_occurrence, e1.last_occurrence)
      })
        |> list.index_map(log_row),
    ),
  ])
}

fn log_row(log: ErrorLog, id: Int) -> Element(Nil) {
  html.tr([], [
    log.id |> int.to_string |> log_id_cell,
    log.level |> level_to_element |> level_cell(id),
    cell(log.message, id, "message"),
    log.last_occurrence |> int.to_string |> cell(id, "occurrence"),
  ])
}

fn occurrence_id_cell(el: String) -> Element(Nil) {
  html.td([attribute.class("id"), attribute("scope", "row")], [html.text(el)])
}

fn log_id_cell(el: String) -> Element(Nil) {
  html.td([attribute.class("id"), attribute("scope", "row")], [
    html.a([attribute.href("/dev/entomologist/" <> el)], [html.text(el)]),
  ])
}

fn level_cell(el: Element(Nil), id: Int) -> Element(Nil) {
  html.td([attribute("scope", "row")], [
    html.div(
      [
        attribute.class("flex-row expand"),
        attribute.id(int.to_string(id) <> "level"),
      ],
      [
        html.div(
          [attribute.class("block"), attribute.id(int.to_string(id) <> "level")],
          [el],
        ),
        html.button(
          [
            attribute.class("copy"),
            attribute(
              "onclick",
              "copy('" <> int.to_string(id) <> "level" <> "')",
            ),
          ],
          [svg_clipboard()],
        ),
      ],
    ),
  ])
}

fn cell(el: String, id: Int, ty: String) -> Element(Nil) {
  html.td([attribute("scope", "row")], [
    html.div(
      [
        attribute.class("flex-row expand"),
        attribute.id(int.to_string(id) <> ty),
      ],
      [
        html.div(
          [attribute.class("block"), attribute.id(int.to_string(id) <> ty)],
          [html.text(el)],
        ),
        html.button(
          [
            attribute.class("copy"),
            attribute("onclick", "copy('" <> int.to_string(id) <> ty <> "')"),
          ],
          [svg_clipboard()],
        ),
      ],
    ),
  ])
}

fn search_bar(post_target dest: String) -> Element(Nil) {
  // I extracted some of the html attributes clear up the ones related to logic.
  // I'll add more filters later

  let form_attributes = [attribute.action(dest), attribute.method("post")]
  let text_attributes = [
    attribute.class("search_bar"),
    attribute.type_("text"),
    attribute.placeholder("Search"),
  ]
  let button_attributes = [
    attribute.class("search_button"),
    attribute.type_("submit"),
  ]

  html.form([attribute.id("search"), ..form_attributes], [
    html.input([attribute.name("search_text"), ..text_attributes]),
    html.button([attribute.for("search"), ..button_attributes], [
      html.text("Search"),
    ]),
  ])
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

fn level_to_element(level: entomologist.Level) -> Element(Nil) {
  let remove_spacing = "nopad nomar "

  let gen_element = fn(level: String, emoji: String) -> Element(Nil) {
    html.p([attribute.class(remove_spacing <> level)], [
      html.text(emoji <> level),
    ])
  }

  case level {
    entomologist.Emergency -> gen_element("emergency", "󱐋 ")
    entomologist.Alert -> gen_element("alert", "󱐋 ")
    entomologist.Critical -> gen_element("critical", "󱐋 ")
    entomologist.ErrorLevel -> gen_element("error", "󱐋 ")
    entomologist.Warning -> gen_element("warning", " ")
    entomologist.Notice -> gen_element("notice", " ")
    entomologist.Info -> gen_element("info", " ")
    entomologist.Debug -> gen_element("debug", " ")
  }
}
