-module(connection_server).

-behaviour(gen_server).

-export([start_link/1, init/1, handle_call/3, handle_cast/2]).

start_link(Conn) ->
    gen_server:start_link({local, connection_server}, connection_server, Conn, []).

init(Conn) ->
    {ok, Conn}.

handle_call(get, _From, State) ->
    {reply, State, State}.

handle_cast(_, State) ->
    {noreply, State}.
