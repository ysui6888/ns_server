-module(cb_util).

-export([vbucket_from_id/2]).

%% Given a key, map it to a vbucket by hashing the key, then
%% lookup the server that owns the vbucket.
-spec vbucket_from_id(string(), binary()) -> {integer(), atom()}.
vbucket_from_id(Bucket, Id) ->

    {ok, Config} = ns_bucket:get_bucket(Bucket),
    Map = proplists:get_value(map, Config, []),
    NumVBuckets = proplists:get_value(num_vbuckets, Config, []),

    vbucket_from_id(Map, NumVBuckets, Id).


-spec vbucket_from_id(list(), integer(), binary()) -> {integer(), atom()}.
vbucket_from_id(Map, NumVBuckets, Id) ->

    Hashed = (erlang:crc32(Id) bsr 16) band 16#7fff,
    Index = Hashed band (NumVBuckets - 1),
    [Master | _ ] = lists:nth(Index, Map),

    {Index, Master}.


-include_lib("eunit/include/eunit.hrl").

%% Sanity checks against vbucket lookup, checks against results from
%% curl http://127.0.0.1:9000/pools/default/buckets/default
%%     | ../libvbucket/vbuckettool - test foo bar test%2Fing _design/test $
lookup_16_2(Bin) ->
    vbucket_from_id(map_16_2(), 16, Bin).


lookup_16_3(Bin) ->
    vbucket_from_id(map_16_3(), 16, Bin).


lookup_16_2_test_() ->
    [ ?_assertEqual({15,'n_1@192.168.1.66'}, lookup_16_2(<<"test">>)),
      ?_assertEqual({3,'n_0@192.168.1.66'}, lookup_16_2(<<"foo">>)),
      ?_assertEqual({15,'n_1@192.168.1.66'}, lookup_16_2(<<"bar">>)),
      ?_assertEqual({5,'n_0@192.168.1.66'}, lookup_16_2(<<"test%2Fing">>)),
      ?_assertEqual({6,'n_0@192.168.1.66'}, lookup_16_2(<<"_design/test">>)),
      ?_assertEqual({1,'n_0@192.168.1.66'}, lookup_16_2(<<"$">>)) %"
     ].


lookup_16_3_test_() ->
    [ ?_assertEqual({15,'n_2@192.168.1.66'}, lookup_16_3(<<"test">>)),
      ?_assertEqual({3,'n_0@192.168.1.66'}, lookup_16_3(<<"foo">>)),
      ?_assertEqual({15,'n_2@192.168.1.66'}, lookup_16_3(<<"bar">>)),
      ?_assertEqual({5,'n_0@192.168.1.66'}, lookup_16_3(<<"test%2Fing">>)),
      ?_assertEqual({6,'n_0@192.168.1.66'}, lookup_16_3(<<"_design/test">>)),
      ?_assertEqual({1,'n_0@192.168.1.66'}, lookup_16_3(<<"$">>)) %"
     ].


map_16_2() ->
    [['n_0@192.168.1.66'], ['n_0@192.168.1.66'],
     ['n_0@192.168.1.66'], ['n_0@192.168.1.66'],
     ['n_0@192.168.1.66'], ['n_0@192.168.1.66'],
     ['n_0@192.168.1.66'], ['n_0@192.168.1.66'],
     ['n_1@192.168.1.66'], ['n_1@192.168.1.66'],
     ['n_1@192.168.1.66'], ['n_1@192.168.1.66'],
     ['n_1@192.168.1.66'], ['n_1@192.168.1.66'],
     ['n_1@192.168.1.66'], ['n_1@192.168.1.66']].


map_16_3() ->
    [['n_0@192.168.1.66'], ['n_0@192.168.1.66'],
     ['n_0@192.168.1.66'], ['n_0@192.168.1.66'],
     ['n_0@192.168.1.66'], ['n_0@192.168.1.66'],
     ['n_1@192.168.1.66'], ['n_1@192.168.1.66'],
     ['n_1@192.168.1.66'], ['n_1@192.168.1.66'],
     ['n_1@192.168.1.66'], ['n_2@192.168.1.66'],
     ['n_2@192.168.1.66'], ['n_2@192.168.1.66'],
     ['n_2@192.168.1.66'], ['n_2@192.168.1.66']].

