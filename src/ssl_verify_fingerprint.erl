%%% -*- erlang -*-
%%%
%%% MIT License
%%%
%%% Copyright (c) 2014-2016 Ilya Khaprov <ilya.khaprov@publitechs.com>

-module(ssl_verify_fingerprint).

-export([verify_fun/3,
         verify_cert_fingerprint/2]).

-import(ssl_verify_util, [hexstr_to_bin/1,
                          bin_to_hexstr/1]).

-include_lib("public_key/include/public_key.hrl").

-export_type([fingerprint/0,
              user_state/0]).

-type fingerprint() :: {atom(), ssl_verify_util:hexstr()}.
-type user_state() :: [{check_fingerprint, Fingerprint :: fingerprint()}] | [].

%%====================================================================
%% Public API
%%====================================================================

-spec verify_fun(Cert :: #'OTPCertificate'{},
                 Event :: {bad_cert, Reason :: atom() | {revoked, atom()}} |
                          {extension, #'Extension'{}}, InitialUserState :: term()) ->
                    {valid, ValidUserState :: term()} | {valid_peer, UserState :: user_state()} |
                    {fail, Reason :: term()} | {unknown, UnknownUserState :: term()}.
verify_fun(_, {extension, _}, UserState) ->
  {unknown, UserState};
verify_fun(Cert, _, UserState) ->
  maybe_verify_cert_fingerprint(Cert, UserState).

maybe_verify_cert_fingerprint(Cert, UserState) ->
  Fingerprint = proplists:get_value(check_fingerprint, UserState),
  case Fingerprint of
    undefined -> {valid, UserState};
    _ ->  verify_cert_fingerprint(Cert, Fingerprint)
  end.

-spec verify_cert_fingerprint(Cert :: #'OTPCertificate'{}, Fingerprint :: fingerprint()) ->
                                 {fail, any()} | {valid, string()}.
verify_cert_fingerprint(Cert, Fingerprint) ->
  {FingerprintAlgorithm, FingerprintHex} = Fingerprint,
  case hexstr_to_bin(FingerprintHex) of
    invalid -> {fail, invalid_fingerprint};
    FingerprintB -> verify_cert_fingerprint(Cert, FingerprintB, FingerprintAlgorithm)
  end.

%%====================================================================
%% Private Parts
%%====================================================================

verify_cert_fingerprint(Cert, Fingerprint, FingerprintAlgorithm) ->
  CertBinary = public_key:pkix_encode('OTPCertificate', Cert, 'otp'),
  Hash = crypto:hash(FingerprintAlgorithm, CertBinary),
  case Hash of
    Fingerprint ->
      {valid, bin_to_hexstr(Fingerprint)};
    _ ->
      {fail, fingerprint_no_match}
  end.
