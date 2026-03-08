-module(dev_ffi).
-export([woah/0]).

woah() ->
  {ok, #{config := #{connection := Connection}}} = logger:get_handler_config(entomologist),

  % elp:ignore W0017 (undefined_function)
  entomologist@internal@logger_api:save_to_db(#{
      msg_str => ~"Boom",
      level => "info",
      meta => #{ time => 1009843200 },
      rest => ~"{}"
  },
  Connection).
