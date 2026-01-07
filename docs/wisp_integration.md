# Wisp integration example
This library provides a wisp middleware that expands on native wisp logging
capabilities by saving the logs to a database using entomologist's API.

Here is an example of usage.

#### src/app.gleam
```gleam
import pog
import app/web

pub fn main() {
  let context = web.Context(db: setup_db())

  logging.configure()

  let assert Ok(Nil) = entomologist.configure(context.db)
    as "entomologist db setup failed"

  // Wisp setup
  let secret_key_base = wisp.random_string(64)

  let assert Ok(_) =
    web.handle_request(_, context)
    |> wisp_mist.handler(secret_key_base)
    |> todo as {
      "This is where you setup your server info as per wisp's instructions"
    }

  process.sleep_forever()
}

fn setup_db() -> pog.Connection {
  todo as "This is where you setup your connection as per pog's instructions"
}
```

#### src/app/web.gleam
```gleam
import entomologist_extensions/ui
import pog.{type Connection}
import wisp.{type Request, type Response}

pub type Context {
  Context(
    db: pog.Connection,
    // ... Add other data to the context
  )
}

// Your wisp middleware, mirroring once again the example
pub fn middleware(
  req: Request,
  context: Context,
  handle_request: fn(Request) -> Response,
) -> Response {
  use <- ui.wisp_middleware(req, context.db_connection)
  todo as "Add the wanted middlewares here."

  handle_request(req)
}

// Your wisp handler, mirroring wisp's example
pub fn handle_request(req: Request, context: Context) -> Response {
  use req <- middleware(req, context)
  todo as "Handle the request."
}
```
