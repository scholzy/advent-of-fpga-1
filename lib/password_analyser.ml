open! Core
open! Hardcaml
open! Hardcaml_circuits
open! Signal

module Div = Hardcaml_circuits.Divide_by_constant.Make (Signal)

let n_bits : int = 16
let modulus : int = 100

module I = struct
  type 'a t =
    { clock : 'a
    ; clear : 'a
    ; start : 'a
    ; finish : 'a
    ; data_in_valid : 'a
    ; data_in : 'a [@bits n_bits]
    ; sig_polarity : 'a
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t = { n_matches : 'a With_valid.t [@bits n_bits]
              ; n_passes : 'a With_valid.t [@bits n_bits]
              }
  [@@deriving hardcaml]
end

module States = struct
  type t =
    | Idle
    | Receiving
    | Checking
    | Done
  [@@deriving sexp_of, compare ~localize, enumerate]
end

(*
  These appear a few times so just defining them for ease of reuse here.
  I should probably check if this decreases resource usage?
*)
let modulo_with_resize a b = Modulo.unsigned_by_constant (module Signal) a b |> Signal.uresize ~width:n_bits

let divide_with_resize a b = Div.divide ~divisor:(Bigint.of_int b) a |> Signal.uresize ~width:n_bits

let modulo_p a b =
  let d = a +: b in
  modulo_with_resize d modulus

let modulo_m a b =
  let m = Signal.of_unsigned_int ~width:n_bits modulus in
  let a_m = modulo_with_resize a modulus in
  let b_m = modulo_with_resize b modulus in
  let d = mux2 (b_m >: a_m) (m -: (b_m -: a_m)) (a_m -: b_m) in
  modulo_with_resize d modulus

let passed_zero_p position increment =
  let s = position +: increment in
  let passes = divide_with_resize s modulus in

  (* Avoid double counting if we land on zero -- this is accounted for elsewhere *)
  let final_position = modulo_p position increment in
  let passes = mux2 (final_position ==: zero n_bits)
    (passes -: one n_bits)
    passes
  in

  Signal.uresize ~width:n_bits passes

  let passed_zero_m position decrement =
  let passes = mux2 (decrement <=: position)
    (zero n_bits) (
      (* Work out how far past zero we are *)
      let past_zero = decrement -: position in
      let n_passes = divide_with_resize past_zero modulus in

      (* Remove one "pass" if we land on zero -- this is accounted for elsewhere *)
      let final_position = modulo_m position decrement in
      let n_passes = mux2 (final_position ==: zero n_bits)
        (n_passes -: one n_bits)
        n_passes
      in

      (* If we started at zero and went down by less than our modulo,
      we need to add one pass here -- this only applies for subtraction though *)
      let n_passes = n_passes +: (mux2 (position ==: (zero n_bits)) (zero n_bits) (one n_bits)) in

      n_passes
   ) in
  passes

let create scope ({ clock; clear; start; finish; data_in_valid; data_in; sig_polarity } : _ I.t) : _ O.t =
  let spec = Reg_spec.create ~clock ~clear () in
  let open Always in
  let sm = State_machine.create (module States) spec
  in
  let%hw_var position = Variable.reg spec ~width:n_bits in
  let%hw_var n_matches = Variable.reg spec ~width:n_bits in
  let%hw_var n_passes = Variable.reg spec ~width:n_bits in
  let n_matches_valid = Variable.wire ~default:gnd () in
  compile
    [ sm.switch
        [ (Idle
          , [ when_ start
                [ position <-- Signal.of_unsigned_int ~width:n_bits 50
                ; sm.set_next Receiving
                ]
            ]
          );
          (Receiving
          , [ when_ data_in_valid
                [ when_ (sig_polarity ==: vdd) [
                      n_passes <-- n_passes.value +: (passed_zero_p position.value data_in)
                    ; position <-- modulo_p position.value data_in
                    ]
                ; when_ (sig_polarity ==: gnd) [
                      n_passes <-- n_passes.value +: (passed_zero_m position.value data_in)
                    ; position <-- modulo_m position.value data_in
                    ]
                ; when_ finish [ sm.set_next Done ]
                ; sm.set_next Checking
                ]
            ]
          );
          (Checking
          , [ when_ (position.value ==: zero n_bits)
                    [ n_matches <-- (n_matches.value +: one n_bits) ]
            ; when_ finish [ sm.set_next Done ]
            ; sm.set_next Receiving
            ]
          );
          (Done
          , [ n_matches_valid <-- vdd
            ; when_ finish [ sm.set_next Receiving ]
          ]
          );
        ]
  ];
  { n_matches = { value = n_matches.value; valid = n_matches_valid.value }
  ; n_passes = { value = n_passes.value; valid = gnd }
  }
;;

let hierarchical scope =
  let module Scoped = Hierarchy.In_scope (I) (O) in
  Scoped.hierarchical ~scope ~name:"password_analyser" create
;;
