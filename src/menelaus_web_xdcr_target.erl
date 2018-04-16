%% @author Couchbase <info@couchbase.com>
%% @copyright 2018 Couchbase, Inc.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%      http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%

-module(menelaus_web_xdcr_target).

-include("cut.hrl").
-include("couch_db.hrl").
-include("ns_common.hrl").
-include_lib("eunit/include/eunit.hrl").


-export([handle_pre_replicate/2,

         %% support of pre Vulcan xdcr sources, executed on ns_couchdb node
         handle_pre_replicate_legacy/3]).

validators() ->
    [validator:required(vb, _),
     validator:integer(vb, _),
     validate_commitopaque(commitopaque, _)].

validate_commitopaque(Name, State) ->
    validator:validate(
      fun ([X, Y]) when is_integer(X), is_integer(Y) ->
              ok;
          (_) ->
              {error, "Must be a pair of integers"}
      end, Name, State).

handle_pre_replicate(Bucket, Req) ->
    menelaus_util:assert_is_vulcan(),
    validator:handle(do_handle_pre_replicate(Req, _, Bucket), Req, json,
                     validators()).

handle_pre_replicate_legacy(#httpd{mochi_req = Req}, Body, Bucket) ->
    {ok,  menelaus_util:reply_json(Req, {[{vbopaque, 0}]}, 200)}.

reply_error(Req, Code, Error, Reason) ->
    menelaus_util:reply_json(Req,
                             {[{error,  Error},
                               {reason, Reason}]}, Code).


do_handle_pre_replicate(Req, Props, Bucket) ->
    VB = proplists:get_value(vb, Props),

    case xdcr_dcp_streamer:get_failover_log(Bucket, VB) of
        {memcached_error, not_my_vbucket} ->
            reply_error(Req, 404, not_found, not_my_vbucket);
        FailoverLog when is_list(FailoverLog) ->
            do_handle_pre_replicate(Req, Props, Bucket, VB, FailoverLog)
    end.

do_handle_pre_replicate(Req, Props, Bucket, VB, FailoverLog) ->
    CommitOpaque = proplists:get_value(commitopaque, Props),
    {VBUUID, _} = lists:last(FailoverLog),

    Code =
        case validate_commit(FailoverLog, CommitOpaque) of
            true ->
                200;
            false ->
                400
        end,

    ?xdcr_debug(
       "Bucket: ~p, VB: ~p, Return Code: ~p, CommitOpaque: ~p, FailoverLog: ~p",
       [Bucket, VB, Code, CommitOpaque, FailoverLog]),

    menelaus_util:reply_json(Req, {[{vbopaque, VBUUID}]}, Code).


validate_commit(_FailoverLog, undefined) ->
    true;
validate_commit(FailoverLog, [CommitUUID, CommitSeq]) ->
    {FailoverUUIDs, FailoverSeqs} = lists:unzip(FailoverLog),

    [SeqnosStart | FailoverSeqs1] = FailoverSeqs,

    %% validness failover log is where each uuid entry has seqno where
    %% it _ends_ rather than where it begins. It makes validness
    %% checking simpler
    ValidnessFailoverLog = lists:zip(FailoverUUIDs, FailoverSeqs1 ++
                                         [16#ffffffffffffffff]),

    case SeqnosStart > CommitSeq of
        true -> false;
        _ ->
            lists:any(fun ({U, EndSeq}) ->
                              U =:= CommitUUID andalso CommitSeq =< EndSeq
                      end, ValidnessFailoverLog)
    end.

validate_commit_test() ->
    FailoverLog = [{13685158163256569856, 0},
                   {4598340681889701145, 48}],
    CommitUUID = 13685158163256569445,
    CommitSeq = 27,
    false = validate_commit(FailoverLog, [CommitUUID, CommitSeq]),
    true = validate_commit(FailoverLog, [13685158163256569856, CommitSeq]).
