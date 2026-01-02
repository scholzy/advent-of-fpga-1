open! Core
open! Hardcaml

val n_bits : int

module I : sig
  type 'a t =
    { clock : 'a
    ; clear : 'a
    ; start : 'a
    ; finish : 'a
    ; data_in_valid : 'a
    ; data_in : 'a
    ; sig_polarity : 'a
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t = { n_matches : 'a With_valid.t; n_passes : 'a With_valid.t }
  [@@deriving hardcaml]
end

val hierarchical : Scope.t -> Signal.t I.t -> Signal.t O.t
