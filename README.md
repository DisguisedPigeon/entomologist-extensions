# Entomologist extensions

[![Package Version](https://img.shields.io/hexpm/v/entomologist_extensions)](https://hex.pm/packages/entomologist_extensions)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/entomologist_extensions/)

# Installation
```sh
gleam add entomologist_extensions@1
```

# Usage
Usage documentation can be found at <https://hexdocs.pm/entomologist_extensions>.

## Development
```sh
gleam test  # Run the tests
gleam dev   # Run the development example server
```

`gleam dev` runs a server with a main page and `entomologist_extensions` running on port `8080`. It exposes `/crash`, `/warn`, `/notice` and `/debug` routes to generate a log of that type, a `/long` route that crashes with a really long message to test wrapping and a default page for every other route.
