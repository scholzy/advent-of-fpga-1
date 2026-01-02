open! Core
open! Hardcaml
open! Hardcaml_waveterm
open! Hardcaml_test_harness
module Password_analyser = Advent_of_hardware.Password_analyser
module Harness = Cyclesim_harness.Make (Password_analyser.I) (Password_analyser.O)

let sample_input_values_l = [
  (* The example test case from AoC's puzzle input. *)
  ([ -68; -30; 48; -5; 60; -55; -1; -99; 14; -82 ], 6);
  (* Large (negative) steps, bigger than the modulus divisor *)
  ([ -500; -500 ], 10);
  (* No clicks should happen here. *)
  ([ 1; 1; 1 ], 0);
  (* Checking stopping at zero twice but not passing. *)
  ([ -50; 100 ], 2);
  (* Lots of very large negative steps. *)
  ([ -1000; -1000; -1000; -1000 ], 40);
  (* Large positive steps. *)
  ([ 1000; 1000 ], 20);
  (* Mixed negative steps *)
  ([ -50; -100; -1000 ], 12);
  (* Mixed (inclugind very large) positive steps *)
  ([ 50; 100; 1000; 10000 ], 112);
]

(* Wraps a cyclesim testbench to allow passing List data into it. *)
let testbench (sim : Harness.Sim.t) ~data =
  let inputs = Cyclesim.inputs sim in
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

let%expect_test "Run all the manually-written tests" =
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
  [%expect {| |}]
;;

let%expect_test "One manual test, visualising the waveform in the terminal" =
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
        ~signals_width:38
        ~display_width:85
        ~wave_width:1
        (* [wave_width] configures how many chars wide each clock cycle is *)
        waves)
    simple_testbench
in
();
  [%expect {|
    ┌Signals─────────────────────────────┐┌Waves────────────────────────────────────────┐
    │password_analyser$i$clear           ││────┐                                        │
    │                                    ││    └────────────────────────────────────────│
    │password_analyser$i$clock           ││┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌│
    │                                    ││  └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘│
    │                                    ││────────────┬───────┬───────┬────────────────│
    │password_analyser$i$data_in         ││ 0          │50     │100    │1000            │
    │                                    ││────────────┴───────┴───────┴────────────────│
    │password_analyser$i$data_in_valid   ││            ┌───┐   ┌───┐   ┌───┐            │
    │                                    ││────────────┘   └───┘   └───┘   └────────────│
    │password_analyser$i$finish          ││                                    ┌───┐    │
    │                                    ││────────────────────────────────────┘   └────│
    │password_analyser$i$sig_polarity    ││                                             │
    │                                    ││─────────────────────────────────────────────│
    │password_analyser$i$start           ││        ┌───┐                                │
    │                                    ││────────┘   └────────────────────────────────│
    │                                    ││────────────────────┬───────┬───────┬────────│
    │password_analyser$n_matches         ││ 0                  │1      │2      │3       │
    │                                    ││────────────────────┴───────┴───────┴────────│
    │                                    ││────────────────────────────────┬────────────│
    │password_analyser$n_passes          ││ 0                              │9           │
    │                                    ││────────────────────────────────┴────────────│
    │password_analyser$o$n_matches$valid ││                                             │
    │                                    ││─────────────────────────────────────────────│
    │                                    ││────────────────────┬───────┬───────┬────────│
    │password_analyser$o$n_matches$value ││ 0                  │1      │2      │3       │
    │                                    ││────────────────────┴───────┴───────┴────────│
    │password_analyser$o$n_passes$valid  ││                                             │
    │                                    ││─────────────────────────────────────────────│
    │                                    ││────────────────────────────────┬────────────│
    │password_analyser$o$n_passes$value  ││ 0                              │9           │
    │                                    ││────────────────────────────────┴────────────│
    │                                    ││────────────┬───┬────────────────────────────│
    │password_analyser$position          ││ 0          │50 │0                           │
    │                                    ││────────────┴───┴────────────────────────────│
    └────────────────────────────────────┘└─────────────────────────────────────────────┘
    |}]
;;
