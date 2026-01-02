open! Core
open! Hardcaml
open! Hardcaml_waveterm
open! Hardcaml_test_harness
module Password_analyser = Advent_of_hardware.Password_analyser
module Harness = Cyclesim_harness.Make (Password_analyser.I) (Password_analyser.O)

(* let ( <--. ) = Bits.( <--. ) *)
(* let sample_input_values = [ -68; -30; 48; -5; 60; -55; -1; -99; 14; -82 ] *)
(* let sample_input_values = [ -500; -500 ] *)
(* let sample_input_values = [ 1; 1; 1 ] *)
(* let sample_input_values = [ -50; 200 ] *)

let sample_input_values_l = [
  ([ -68; -30; 48; -5; 60; -55; -1; -99; 14; -82 ], 6);
  ([ -500; -500 ], 10);
  ([ 1; 1; 1 ], 0);
  ([ -50; 100 ], 2);
  ([ -1000; -1000; -1000; -1000 ], 40);
  ([ 1000; 1000 ], 20);
  ([ -50; -100; -1000 ], 12);
  ([ 50; 100; 1000; 10000 ], 112);
]

let testbench (sim : Harness.Sim.t) ~data =
  let inputs = Cyclesim.inputs sim in
  (* let outputs = Cyclesim.outputs sim in *)
  let cycle ?n () = Cyclesim.cycle ?n sim in
  let feed_input n =
    let input_number = Bits.of_unsigned_int ~width:Password_analyser.n_bits (Int.abs n) in
    inputs.data_in := input_number;
    inputs.data_in_valid := Bits.vdd;
    let polarity = if n >= 0 then Bits.vdd else Bits.gnd in
    inputs.sig_polarity := polarity;
    cycle ();
    inputs.data_in_valid := Bits.gnd;
    cycle ();
  in
  inputs.clear := Bits.vdd;
  cycle ();
  inputs.clear := Bits.gnd;
  cycle ();
  inputs.start := Bits.vdd;
  cycle ();
  inputs.start := Bits.gnd;
  List.iter ~f:feed_input data;
  inputs.finish := Bits.vdd;
  cycle ();
  inputs.finish := Bits.gnd;
  cycle ();
  cycle ();
  cycle ();
  sim
;;

let waves_config = Waves_config.no_waves

let%expect_test "Simple test, optionally saving waveforms to disk" =
  List.iter sample_input_values_l ~f:(fun (sample_input_values, expected_result) ->
    let simple_testbench = testbench ~data:(sample_input_values) in
    let sim = Harness.run_advanced ~waves_config ~create:Password_analyser.hierarchical simple_testbench in
    let outputs = Cyclesim.outputs sim in
    let n_matches = Bits.to_unsigned_int !(outputs.n_matches.value) in
    let n_passes = Bits.to_unsigned_int !(outputs.n_passes.value) in
    let n_zeroes = n_matches + n_passes in
    if n_zeroes <> expected_result then (
      List.iter sample_input_values ~f:(Printf.printf "%d\n");
      Printf.printf "Test failed: expected %d but got %d\n" expected_result n_zeroes;
      Printf.printf "n_matches: %d, n_passes: %d\n" n_matches n_passes;
    );
  );
;;

let%expect_test "foo" =
  let data = List.nth sample_input_values_l 6 in
  let data =
    match data with
    | Some (data, _expected) -> data
    | None -> []
  in  
  let simple_testbench = testbench ~data:data in
  let display_rules =
    [ Display_rule.port_name_matches
        ~wave_format:(Bit_or Unsigned_int)
        (Re.Glob.glob "password_analyser*" |> Re.compile)
    ]
  in
  let _sim = Harness.run_advanced
    ~create:Password_analyser.hierarchical
    ~trace:`All_named
    ~print_waves_after_test:(fun waves ->
      Waveform.print
        ~display_rules
          (* [display_rules] is optional, if not specified, it will print all named
             signals in the design. *)
        ~signals_width:50
        ~display_width:150
        ~wave_width:1
        (* [wave_width] configures how many chars wide each clock cycle is *)
        waves)
    simple_testbench
in
()