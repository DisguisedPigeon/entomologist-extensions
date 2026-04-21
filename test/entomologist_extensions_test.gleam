import birdie
import entomologist
import entomologist/internal/logger_api
import entomologist_extensions.{LogToTag, Logs, Occurrences, Tags}
import envoy
import gleam/dict
import gleam/dynamic/decode
import gleam/erlang/charlist
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option
import gleam/otp/static_supervisor as supervisor
import gleam/result
import gleam/string
import gleeunit
import gleeunit/should
import logging
import pog

pub fn main() -> Nil {
  let pool_name = process.new_name("postgres_pool")
  let assert Ok(_) = create_pool(pool_name:)

  let connection = pog.named_connection(pool_name)
  set_connection(pool_name)

  logging.configure()
  logging.set_level(logging.Debug)
  let assert Ok(Nil) = entomologist.configure(connection)
    as "configuration should end successfully"

  create_tables(pog.named_connection(pool_name))

  let assert Ok(_) =
    "set session characteristics as transaction isolation level serializable"
    |> pog.query
    |> pog.execute(connection)
    as "There should be no issue setting the isolation level for the session."

  gleeunit.main()
}

pub fn exporting_generation_test() {
  let connection = get_connection() |> pog.named_connection

  list.map([1, 2, 3, 4], fn(_) { logging.log(logging.Info, "Sample log") })

  logging.log(logging.Error, "Sample log 2")
  logging.log(logging.Debug, "Sample log 3")

  let assert Ok([log, log2, _]) = entomologist.show(connection)

  let assert Ok(Nil) = entomologist.add_tag(connection, log.id, "New Tag")
  let assert Ok(Nil) = entomologist.add_tag(connection, log2.id, "New Tag")
  let assert Ok(Nil) = entomologist.add_tag(connection, log2.id, "Other Tag")

  entomologist_extensions.export(connection)
  |> dict.fold(from: "", with: fn(acc, k, v) {
    let acc = case acc {
      "" -> ""
      _ -> acc <> "\n\n"
    }

    case k {
      LogToTag ->
        acc
        <> "LogToTag =======================================================================\n"
        <> v
      Logs ->
        acc
        <> "Logs ===========================================================================\n"
        <> v
      Tags ->
        acc
        <> "Tags ===========================================================================\n"
        <> v
      Occurrences ->
        acc
        <> "Occurrences ====================================================================\n"
        <> v
    }
  })
  |> birdie.snap(title: "exporting generation")
}

/// DB setup
fn create_tables(connection: pog.Connection) -> Nil {
  case
    "
    create type level as enum (
        'emergency',
        'alert',
        'critical',
        'error',
        'warning',
        'notice',
        'info',
        'debug'
    )"
    |> pog.query
    |> pog.execute(connection)
  {
    Ok(_) -> Nil
    Error(pog.PostgresqlError(
      "42710",
      "duplicate_object",
      "type \"level\" already exists",
    )) -> Nil
    Error(e) ->
      panic as {
        "unexpected error when creating type level: " <> string.inspect(e)
      }
  }

  let assert Ok(_) =
    "create table if not exists logs (
       id bigserial not null unique primary key,
       message text not null,
       level level not null,
       module text not null,
       function text not null,
       arity int not null,
       file text not null,
       line int not null,
       last_occurrence bigint not null,
       resolved bool not null default false,
       muted bool not null default false
     );"
    |> pog.query
    |> pog.execute(connection)
    as "table logs should be created without issues."

  let assert Ok(_) =
    "create table if not exists occurrences (
       id bigserial not null unique primary key,
       log bigint not null references logs(id) on delete cascade,
       timestamp bigint not null,
       full_contents json
     );"
    |> pog.query
    |> pog.execute(connection)
    as "table occurrences should be created without issues."

  let assert Ok(_) =
    "create table if not exists tags (
       id bigserial not null unique primary key,
       name text not null unique
     );"
    |> pog.query
    |> pog.execute(connection)
    as "tag table should be created successfully."

  let assert Ok(_) =
    "create table if not exists log2tag (
       log bigserial not null references logs(id) on delete cascade,
       tag bigserial not null references tags(id),
       constraint logtag_pkey primary key (log, tag)
     );"
    |> pog.query
    |> pog.execute(connection)
    as "log2tag table should be created successfully."

  let assert Ok(_) =
    "delete from log2tag"
    |> pog.query
    |> pog.execute(connection)
    as "table log2tag should be emptied. Even if its empty it won't fail."

  let assert Ok(_) =
    "delete from tags"
    |> pog.query
    |> pog.execute(connection)
    as "table tags should be emptied. Even if its empty it won't fail. This wont fail since all log2tag mappings are deleted."

  let assert Ok(_) =
    "delete from occurrences"
    |> pog.query
    |> pog.execute(connection)
    as "table occurrences should be emptied. Even if its empty it won't fail."

  let assert Ok(_) =
    "delete from logs"
    |> pog.query
    |> pog.execute(connection)
    as "table logs should be emptied. If its empty it won't fail. This wont fail since all occurrences are deleted and all log2tag mappings are too."

  Nil
}

// Creates a named pool to be transformed into a pog connection
fn create_pool(pool_name pool_name: process.Name(pog.Message)) {
  let pool =
    pog.default_config(pool_name)
    |> pog.port(5431)
    |> pog.host("localhost")
    |> pog.user("postgres")
    |> pog.password(option.Some("postgres"))
    |> pog.database("test")
    |> pog.pool_size(1)
    |> pog.supervised

  supervisor.new(supervisor.RestForOne)
  |> supervisor.add(pool)
  |> supervisor.start()
}

@external(erlang, "test_ffi", "set")
fn set_connection(connection: process.Name(pog.Message)) -> Nil

@external(erlang, "test_ffi", "get")
fn get_connection() -> process.Name(pog.Message)
