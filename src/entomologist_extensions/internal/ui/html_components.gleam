import entomologist.{type ErrorLog, type Occurrence, ErrorLog}
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/time/calendar
import gleam/time/timestamp
import lustre/attribute.{attribute}
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/svg

/// Returns an element with the rendered HTML for the given error list
pub fn wisp_logs(logs: List(ErrorLog)) -> Element(Nil) {
  [
    header(""),
    logs_main(logs),
  ]
  |> root_template
}

/// Returns an element with the rendered HTML for the given error and its occurrences
pub fn wisp_occurrences(
  occurrences: List(Occurrence),
  error: ErrorLog,
) -> Element(Nil) {
  [
    header("- Log " <> int.to_string(error.id)),
    log_details(occurrences, error),
  ]
  |> root_template
}

fn root_template(body: List(Element(Nil))) -> Element(Nil) {
  html.html([attribute("lang", "en")], [
    head(),
    html.body([], body),
  ])
}

fn head() {
  html.head([], [
    html.meta([attribute.charset("UTF-8")]),
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
      attribute.content("width=device-width, initial-scale=1.0"),
      attribute.name("viewport"),
    ]),
    html.script(
      [],
      "function copy(t){navigator.clipboard.writeText(t),alert('Copied '+t)}",
    ),
    html.title([], "Entomologist"),
  ])
}

fn header(text: String) -> Element(Nil) {
  html.header([], [
    html.nav([], [
      html.a([attribute.href("/dev/entomologist")], [
        html.text(" "),
        html.text("Entomologist UI "),
      ]),
      html.span([], [html.text(text)]),
    ]),
  ])
}

fn logs_main(logs: List(ErrorLog)) -> Element(Nil) {
  let target = "/dev/entomologist/search"

  html.main([attribute.class("stack center")], [
    html.section([], [search_bar(target:)]),
    html.section([], [log_list(logs)]),
  ])
}

fn log_details(occurrences: List(Occurrence), error: ErrorLog) -> Element(Nil) {
  html.main([attribute.class("stack center")], [
    html.section([], [error_description(error)]),
    html.section([], [tags(error)]),
    html.section([], [occurrences_list(occurrences)]),
  ])
}

fn tags(error: ErrorLog) -> Element(Nil) {
  let id = int.to_string(error.id)

  html.hgroup([attribute.class("box fields-box")], [
    html.div(
      [
        attribute.class("stack-row fields-header"),
      ],
      [
        html.h4([], [
          html.text("Tags "),
        ]),

        html.form(
          [
            attribute.class("stack-row"),
            attribute.method("post"),
            attribute.action("/dev/entomologist/" <> id <> "/tag"),
          ],
          [
            html.input([
              attribute.name("tag"),
              attribute.class("form-field"),
              attribute.type_("text"),
              attribute.placeholder(" Tag name"),
            ]),
            html.button(
              [
                attribute.class("round flex plus-button-flex"),
                attribute.type_("submit"),
                attribute.style("--size", "var(--s2)"),
              ],
              [
                html.text("󰐕"),
              ],
            ),
          ],
        ),
      ],
    ),
    html.div([], [render_tags(error.tags)]),
  ])
}

fn error_description(error: ErrorLog) -> Element(Nil) {
  let ErrorLog(id:, message:, resolved:, muted:, ..) = error

  html.article([attribute.class("with-sidebar")], [
    html.article([attribute.class("stack")], [
      html.hgroup([], [
        html.h1([], [html.text("Log " <> int.to_string(id))]),
        html.p([attribute.style("overflow", "auto")], [html.text(message)]),
      ]),
      html.div(
        [
          attribute.class("cluster"),
          attribute.style("justify-content", "start"),
        ],
        render_details(error),
      ),
    ]),
    html.div([], [
      case resolved {
        True -> html.h3([], [html.text("󱜙 Resolved")])
        False -> html.h3([], [html.text(" Unresolved")])
      },
      case muted {
        True -> html.p([], [html.text("Muted  ")])
        False -> html.p([], [html.text("Not muted  ")])
      },
    ]),
  ])
}

fn occurrences_list(occurrences: List(Occurrence)) -> Element(Nil) {
  let compare_timestamp = fn(e1: Occurrence, e2: Occurrence) {
    int.compare(e2.timestamp, e1.timestamp)
  }

  html.ul(
    [attribute.class("stack unstyled-list")],
    list.sort(occurrences, compare_timestamp)
      |> list.map(occurrence_box),
  )
}

fn occurrence_box(occ: Occurrence) -> Element(Nil) {
  html.li([attribute.class("box occurrence-box")], [
    html.div([attribute.class("sidebar-left")], [
      html.div([], [
        html.h2([], [
          int.to_string(occ.id)
          |> html.text,
        ]),
        html.p([], [
          html.text(
            timestamp.from_unix_seconds(occ.timestamp)
            |> timestamp.to_rfc3339(calendar.utc_offset)
            <> " ",
          ),
        ]),
      ]),
      html.div([attribute.class("box contents-box")], [
        option.unwrap(occ.full_contents, "")
        |> html.text,
      ]),
    ]),
  ])
}

fn log_list(logs: List(ErrorLog)) -> Element(Nil) {
  let compare_last_timestamp = fn(e1: ErrorLog, e2: ErrorLog) {
    int.compare(e2.last_occurrence, e1.last_occurrence)
  }
  html.ul(
    [attribute.class("stack unstyled-list")],
    list.sort(logs, compare_last_timestamp)
      |> list.map(log_box),
  )
}

fn log_box(log: ErrorLog) -> Element(Nil) {
  html.li([attribute.class(level_to_color(log.level))], [
    html.article([attribute.class("box log-box")], [
      html.a([attribute.href("/dev/entomologist/" <> int.to_string(log.id))], [
        html.h2(
          [
            attribute.id(int.to_string(log.id)),
            attribute.style("overflow", "auto"),
          ],
          [
            html.text(level_to_icon(log.level) <> " " <> log.message),
          ],
        ),
      ]),
      html.p([], [
        html.text(
          timestamp.from_unix_seconds(log.last_occurrence)
          |> timestamp.to_rfc3339(calendar.utc_offset)
          <> " ",
        ),
        attribute("onclick", "copy(\"" <> log.message <> "\")")
          |> list.wrap()
          |> html.button([svg_clipboard()]),
      ]),
    ]),
  ])
}

fn search_bar(target dest: String) -> Element(Nil) {
  // I extracted some of the html attributes clear up the ones related to logic.
  // I'll add more filters later

  html.form(
    [
      attribute.class("stack"),
      attribute.method("get"),
      attribute.action(dest),
    ],
    [
      html.div([attribute.class("switcher")], [
        html.select(
          [
            attribute.name("level"),
            attribute.class("form-field"),
            attribute.placeholder(" Level"),
          ],
          [
            html.option([attribute.value("")], "Select a level"),
            html.option([attribute.value("alert")], "Alert"),
            html.option([attribute.value("critical")], "Critical"),
            html.option([attribute.value("debug")], "Debug"),
            html.option([attribute.value("emergency")], "Emergency"),
            html.option([attribute.value("error")], "Error"),
            html.option([attribute.value("info")], "Info"),
            html.option([attribute.value("notice")], "Notice"),
            html.option([attribute.value("warning")], "Warning"),
          ],
        ),
        html.input([
          attribute.name("module"),
          attribute.class("form-field"),
          attribute.type_("text"),
          attribute.placeholder(" Module name"),
        ]),
        html.input([
          attribute.class("form-field"),
          attribute.name("function"),
          attribute.type_("text"),
          attribute.placeholder(" Function name"),
        ]),
        html.input([
          attribute.name("arity"),
          attribute.type_("number"),
          attribute.class("form-field"),
          attribute.style("appearance", "textfield"),
          attribute.placeholder(" Function arity"),
        ]),
        html.input([
          attribute.name("file"),
          attribute.type_("text"),
          attribute.class("form-field"),
          attribute.placeholder(" File of origin"),
        ]),
        html.input([
          attribute.name("line"),
          attribute.type_("number"),
          attribute.class("form-field"),
          attribute.style("appearance", "textfield"),
          attribute.placeholder(" Line number"),
        ]),
        html.input([
          attribute.name("occurrence_range_start"),
          attribute.class("form-field"),
          attribute.type_("date"),
          attribute.style("appearance", "textfield"),
          attribute.placeholder("Last occurrence range start"),
        ]),
        html.input([
          attribute.name("occurrence_range_end"),
          attribute.class("form-field"),
          attribute.type_("date"),
          attribute.style("appearance", "textfield"),
          attribute.placeholder("Last occurrence range end"),
        ]),
        html.select(
          [attribute.class("form-field"), attribute.name("resolved")],
          [
            html.option([attribute.value("")], "Select a state"),
            html.option([attribute.value("unresolved")], "Unresolved"),
            html.option([attribute.value("resolved")], "Resolved"),
          ],
        ),
        html.select([attribute.class("form-field"), attribute.name("muted")], [
          html.option([attribute.value("")], "Select a visibility"),
          html.option([attribute.value("unmuted")], "Not muted"),
          html.option([attribute.value("muted")], "Muted"),
        ]),
      ]),
      html.div([attribute.class("stack-row")], [
        html.textarea(
          [
            attribute.title(
              "If a word starts with #, it will be interpreted as a tag",
            ),
            attribute.class("search-txt form-field"),
            attribute.name("message"),
            attribute.type_("text"),
            attribute.placeholder(" Search"),
          ],
          "",
        ),
        html.button(
          [
            attribute.class("search-btn form-field"),
            attribute.for("search"),
            attribute.type_("submit"),
          ],
          [html.text("Search")],
        ),
      ]),
    ],
  )
}

fn svg_clipboard() {
  svg.svg(
    [
      attribute("viewBox", "0 0 16 16"),
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

fn render_details(log: entomologist.ErrorLog) {
  let ErrorLog(
    id:,
    level:,
    module:,
    function:,
    arity:,
    file:,
    line:,
    last_occurrence:,
    ..,
  ) = log

  [
    #("Id", html.text(int.to_string(id))),
    #(
      "Level",
      html.div([attribute.class(level_to_color(level))], [
        html.text(level_to_icon(level) <> level_to_text(level)),
      ]),
    ),
    #("Module", html.text(module)),
    #("Function", html.text(function)),
    #("Arity", int.to_string(arity) |> html.text()),
    #("File", html.text(file)),
    #("Line", int.to_string(line) |> html.text()),
    #("Last_occurrence", int.to_string(last_occurrence) |> html.text()),
  ]
  |> render_fields
}

fn render_tags(tags: List(String)) -> Element(Nil) {
  html.div(
    [attribute.class("cluster tags")],
    list.map(tags, fn(tag) {
      html.div([attribute.class("box tag-box")], [html.text(tag)])
    }),
  )
}

fn render_fields(fields: List(#(String, Element(Nil)))) -> List(Element(Nil)) {
  use field <- list.map(fields)
  let #(name, value) = field

  fields_box([
    html.h4([], [
      html.text(name <> " "),
    ]),
    html.div([], [value]),
  ])
}

fn fields_box(elements: List(Element(Nil))) -> Element(Nil) {
  html.article([attribute.class("box fields-box")], elements)
}

fn level_to_icon(level: entomologist.Level) -> String {
  case level {
    entomologist.Emergency -> " "
    entomologist.Alert -> " "
    entomologist.Critical -> " "
    entomologist.ErrorLevel -> " "
    entomologist.Warning -> " "
    entomologist.Notice -> " "
    entomologist.Info -> " "
    entomologist.Debug -> " "
  }
}

fn level_to_text(level: entomologist.Level) -> String {
  case level {
    entomologist.Emergency -> "emergency"
    entomologist.Alert -> "alert"
    entomologist.Critical -> "critical"
    entomologist.ErrorLevel -> "errorLevel"
    entomologist.Warning -> "warning"
    entomologist.Notice -> "notice"
    entomologist.Info -> "info"
    entomologist.Debug -> "debug"
  }
}

fn level_to_color(level: entomologist.Level) -> String {
  case level {
    entomologist.Emergency -> "red"
    entomologist.Alert -> "red"
    entomologist.Critical -> "red"
    entomologist.ErrorLevel -> "red"
    entomologist.Warning -> "yellow"
    entomologist.Notice -> "blue"
    entomologist.Info -> "blue"
    entomologist.Debug -> "green"
  }
}
