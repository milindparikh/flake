-module (persistent_timer).
-behaviour (gen_server).
-export ([start_link/1]).
-export ([write_timestamp/1,read_timestamp/1,get_last_timestamp/0]).
-export ([init/1,handle_call/3,handle_cast/2,handle_info/2,terminate/2,code_change/3]).
-record (state, {table,timer}).

-include_lib("eunit/include/eunit.hrl").

%% ----------------------------------------------------------
%% API
%% ----------------------------------------------------------

% start and link to a new flake id generator
start_link(Config) ->
  gen_server:start_link({local,?MODULE},?MODULE,Config,[]).

get_last_timestamp() ->
  gen_server:call(?MODULE,get_last_timestamp).

%% ----------------------------------------------------------
%% gen_server callbacks
%% ----------------------------------------------------------

init(Config) ->
  Table = proplists:get_value(table,Config),
  Interval = proplists:get_value(interval,Config,1000),
  {ok,TimerRef} = timer:send_interval(Interval,save),
  {ok,#state{table=Table,timer=TimerRef}}.

handle_call(get_last_timestamp, _From, State = #state{table=Table}) ->
  {reply,read_timestamp(Table),State}.

handle_cast(_, State) -> {noreply, State}.

handle_info(save, State = #state{table=Table}) ->
  {ok,_} = write_timestamp(Table),
  {noreply, State}.

terminate(_Reason, _State) -> ok.

code_change(_, State, _) -> {ok, State}.

%% ----------------------------------------------------------
%% utils
%% ----------------------------------------------------------

% write the current time stamp to disk
% {ok,Timestamp=int()} | {error,Reason}
write_timestamp(Table) ->
  TS = flake_util:curr_time_millis(),
  ok = dets:insert(Table,{last_timestamp,TS}),
  {ok,TS}.

% read the timestamp from the given file. will write the current timestamp to disk if the file does not exist
% {ok,Timestamp=int()} | {error,Reason}
read_timestamp(Table) ->
  case dets:lookup(Table,last_timestamp) of
    [{last_timestamp,TS}] when is_integer(TS) ->
      {ok,TS};
    _ ->
      write_timestamp(Table)
  end.

%% ----------------------------------------------------------
%% tests
%% ----------------------------------------------------------

persistent_clock_test() ->
  {ok,Table} =
    dets:open_file(timestamp_table,[
      {estimated_no_objects,10},
      {type,set},
      {file,"/tmp/timestamp-dets"}
    ]),
  {ok,TS0} = write_timestamp(Table),
  {ok,TS1} = read_timestamp(Table),
  ?assert(?debugVal(TS0) =:= ?debugVal(TS1)).