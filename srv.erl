-module(srv).

-export([srv_lookup/0, txt_lookup/0]).

% -define(FullURL, 'mongodb+srv://massivefermion:poincare-1992@mungo.r615xtc.mongodb.net/').
-define(URL, '_mongodb._tcp.mungo.r615xtc.mongodb.net').
% -define(URL, '_mongodb._tcp.localhost').

srv_lookup() ->
    inet_res:getbyname(?URL, srv).

txt_lookup() ->
    inet_res:getbyname(?URL, txt).
