import entomologist.{type ErrorLog, type Occurrence, ErrorLog}
import gleam/int
import gleam/list
import gleam/option
import lustre/attribute.{attribute}
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/svg

/// Returns an element with the rendered HTML for the given error list
pub fn wisp_logs(logs: List(ErrorLog)) -> Element(Nil) {
  root_template([header(""), logs_main(logs)])
}

/// Returns an element with the rendered HTML for the given error and its occurrences
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
      html.link([
        attribute.href(
          "https://cdn.jsdelivr.net/npm/nerdfonts-web@1.0.1/nf.min.css",
        ),
        attribute.rel("stylesheet"),
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
      html.a(
        [attribute.href("/dev/entomologist"), attribute.class("nf title")],
        [
          html.text(""),
        ],
      ),
      html.a([attribute.href("/dev/entomologist"), attribute.class("title")], [
        html.text("Entomologist UI"),
      ]),
      html.span([], [
        case text {
          "" -> html.text("")
          _ -> html.text(text)
        },
      ]),
    ]),
  ])
}

fn logs_main(logs: List(ErrorLog)) -> Element(Nil) {
  let post_target = "/dev/entomologist"

  html.main([], [
    html.section([attribute.class("topmost")], [search_bar(post_target:)]),
    html.section([], [logs_table(logs)]),
  ])
}

fn occurrences_main(
  occurrences: List(Occurrence),
  error: ErrorLog,
) -> Element(Nil) {
  html.main([], [
    html.section([], [error_description(error)]),
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
    muted:,
    tags:,
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
        ..level_to_element(level)
      ]),
      html.p([], [html.text("Module: " <> module)]),
      html.p([], [html.text("Function: " <> function)]),
      html.p([], [html.text("Arity: " <> int.to_string(arity))]),
      html.p([], [html.text("File: " <> file)]),
      html.p([], [html.text("Line: " <> int.to_string(line))]),
      html.p([], [
        html.text(
          "Tags: "
          <> list.fold(tags, "", with: fn(acc, tag) { acc <> " | " <> tag }),
        ),
      ]),
      html.p([], [
        html.text("Last_occurrence: " <> int.to_string(last_occurrence)),
      ]),
    ]),
    html.div([], [
      case resolved {
        True -> html.h1([attribute.class("nf ok")], [html.text("󱜙 Resolved")])
        False ->
          html.h1([attribute.class("nf nok")], [html.text(" Unresolved")])
      },
      case muted {
        True -> html.p([attribute.class("nf shh")], [html.text("Muted  ")])
        False ->
          html.p([attribute.class("nf notshh")], [html.text("Not muted  ")])
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
        html.th([attribute("scope", "col"), attribute.class("full")], [
          html.text(" Full_log "),
        ]),
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
    int.to_string(el.id)
      |> occurrence_id_cell,

    int.to_string(el.timestamp)
      |> html.text
      |> list.wrap
      |> cell(id, "message"),

    option.unwrap(el.full_contents, "")
      |> html.text
      |> list.wrap
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
        html.th([attribute("scope", "col"), attribute.class("message-header")], [
          html.text(" Message "),
        ]),
        html.th([attribute("scope", "col"), attribute.class("timestamp")], [
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
    int.to_string(log.id) |> log_id_cell,
    level_to_element(log.level)
      |> cell(id, "level"),

    html.text(log.message)
      |> list.wrap
      |> cell(id, "message"),

    int.to_string(log.last_occurrence)
      |> html.text
      |> list.wrap
      |> cell(id, "occurrence"),
  ])
}

fn occurrence_id_cell(el: String) -> Element(Nil) {
  html.td([attribute.class("id"), attribute("scope", "row")], [html.text(el)])
}

fn log_id_cell(el: String) -> Element(Nil) {
  html.td([attribute.class("id"), attribute.scope("row")], [
    html.a([attribute.href("/dev/entomologist/" <> el)], [html.text(el)]),
  ])
}

fn cell(el: List(Element(Nil)), id: Int, ty: String) -> Element(Nil) {
  html.td([attribute("scope", "row")], [
    html.div(
      [
        attribute.class("flex-row expand"),
        attribute.id(int.to_string(id) <> ty),
      ],
      [
        html.div(
          [
            attribute.class("block"),
            attribute.id(int.to_string(id) <> ty),
          ],
          el,
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

  let form_attributes = [
    attribute.action(dest),
    attribute.method("post"),
  ]

  let text_attributes = [
    attribute.class("search_bar"),
    attribute.type_("text"),
    attribute.placeholder("Search"),
  ]

  html.form([attribute.id("search"), ..form_attributes], [
    html.textarea(
      [attribute.class("message"), attribute.name("message"), ..text_attributes],
      "",
    ),
    html.div([attribute.class("filters")], [
      html.select([attribute.name("level"), attribute.class("field")], [
        html.option([attribute.value("")], "Choose a level"),
        html.option([attribute.value("alert")], "Alert"),
        html.option([attribute.value("critical")], "Critical"),
        html.option([attribute.value("debug")], "Debug"),
        html.option([attribute.value("emergency")], "Emergency"),
        html.option([attribute.value("error")], "Error"),
        html.option([attribute.value("info")], "Info"),
        html.option([attribute.value("notice")], "Notice"),
        html.option([attribute.value("warning")], "Warning"),
      ]),
      html.input([
        attribute.name("module"),
        attribute.type_("text"),
        attribute.placeholder("Module name"),
        attribute.class("field"),
      ]),
      html.input([
        attribute.name("function"),
        attribute.type_("text"),
        attribute.placeholder("Function name"),
        attribute.class("field"),
      ]),
      html.input([
        attribute.name("arity"),
        attribute.type_("number"),
        attribute.style("appearance", "textfield"),
        attribute.class("field"),
        attribute.placeholder("Function arity"),
      ]),
      html.input([
        attribute.name("file"),
        attribute.type_("text"),
        attribute.class("field"),
        attribute.placeholder("File of origin"),
      ]),
      html.input([
        attribute.name("line"),
        attribute.class("field"),
        attribute.type_("number"),
        attribute.style("appearance", "textfield"),
        attribute.placeholder("Line number"),
      ]),
      // TODO: Substitute with range
      // https://github.com/DisguisedPigeon/entomologist/issues/7#issuecomment-3536768601
      html.input([
        attribute.name("last_occurrence"),
        attribute.type_("number"),
        attribute.style("appearance", "textfield"),
        attribute.class("field"),
        attribute.placeholder("Timestamp"),
      ]),
      html.select([attribute.class("field"), attribute.name("resolved")], [
        html.option([attribute.value("unresolved")], "Unresolved"),
        html.option([attribute.value("resolved")], "Resolved"),
      ]),
      html.select([attribute.class("field"), attribute.name("muted")], [
        html.option([attribute.value("unmuted")], "Not muted"),
        html.option([attribute.value("muted")], "Muted"),
      ]),
    ]),
    html.button(
      [
        attribute.for("search"),
        attribute.class("submit"),
        attribute.type_("submit"),
      ],
      [html.text("Search")],
    ),
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

fn level_to_element(level: entomologist.Level) -> List(Element(Nil)) {
  let gen_element = fn(level: String, class: String, emoji: String) -> List(
    Element(Nil),
  ) {
    [
      html.p(
        [
          attribute.class("nf nopad nomar " <> class),
          attribute.style("margin-right", ".5rem"),
        ],
        [
          html.text(emoji),
          html.b([], [html.text(level)]),
        ],
      ),
    ]
  }

  case level {
    entomologist.Emergency -> gen_element("emergency", "red", " ")
    entomologist.Alert -> gen_element("alert", "red", " ")
    entomologist.Critical -> gen_element("critical", "red", " ")
    entomologist.ErrorLevel -> gen_element("error", "red", " ")
    entomologist.Warning -> gen_element("warning", "yellow", " ")
    entomologist.Notice -> gen_element("notice", "blue", " ")
    entomologist.Info -> gen_element("info", "blue", " ")
    entomologist.Debug -> gen_element("debug", "green", " ")
  }
}
