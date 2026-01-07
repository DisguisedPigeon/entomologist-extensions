# Entomologist extensions

[![Package Version](https://img.shields.io/hexpm/v/entomologist_extensions)](https://hex.pm/packages/entomologist_extensions)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/entomologist_extensions/)

# Installation
```sh
gleam add entomologist_extensions@1
```

# Basic usage example
```gleam
//// app.gleam
pub fn main() {
  let context =
    Context(
        ..todo as "Add fields to the context if needed",
        db: setup_db()
    )

  logging.configure()

  let assert Ok(Nil) = entomologist.configure(context.db)
    as "entomologist db setup failed"

  // Wisp setup
  let secret_key_base = wisp.random_string(64)

  let assert Ok(_) =
    handle_request(_, context)
    |> wisp_mist.handler(secret_key_base)
    |> todo as {
      "This is where you setup your server info as per wisp's instructions"
    }

  process.sleep_forever()
}

fn setup_db() -> pog.Connection {
  todo as "This is where you setup your connection as per pog's instructions"
}

//// app/handler.gleam
// Your wisp handler, mirroring wisp's example
pub fn handle_request(req: Request, c: Context) -> Response {
  use req <- middleware(req, c)
  todo as "Handle the request."
}

//// app/middleware.gleam
import entomologist_extensions

// Your wisp middleware, mirroring once again the example
pub fn middleware(req: Request, c: Context, handle_request) -> Nil {
  use <- ui.wisp_middleware(req, c.db_connection)
  todo as "Add the wanted middlewares here."

  handle_request(req)
}
```

Further documentation can be found at <https://hexdocs.pm/entomologist_extensions>.

## Development
```sh
gleam test  # Run the tests
gleam dev   # Run the development example server
```

`gleam dev` runs a server with a main page and `entomologist_extensions` running on port `8080`. It exposes `/crash`, `/warn`, `/notice` and `/debug` routes to generate a log of that type, a `/long` route that crashes with a really long message to test wrapping and a default page for every other route.
