open! Hardcaml
open! Hardcaml_waveterm
open! Hardcaml_test_harness
module Password_analyser = Advent_of_hardware.Password_analyser
module Harness = Cyclesim_harness.Make (Password_analyser.I) (Password_analyser.O)

let read_data = In_channel.with_open_bin "data/input.txt" In_channel.input_lines

let parse_string s =
  let sign_ch = String.get s 0 in
  let number_str = String.sub s 1 (String.length s - 1) in
  let number = int_of_string number_str in
  match sign_ch with
  | 'R' -> number
  | 'L' -> -number
  | _ -> failwith "Invalid sign character"

let ocaml_solution data =
  let position = ref 50 in
  let n_matches = ref 0 in
  List.iter
    (fun n ->
      let new_position = (!position + n) mod 100
      in
      position := new_position;
      if !position = 0 then n_matches := !n_matches + 1)
    data;
  !n_matches

let testbench (sim : Harness.Sim.t) ~data =
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in
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
  List.iter feed_input data;
  inputs.finish := Bits.vdd;
  cycle ();
  inputs.finish := Bits.gnd;
  cycle ();
  cycle ();
  cycle ();
  (* while not (Bits.to_bool !(outputs.n_matches.valid)) do
    cycle ()
  done; *)
  let n_matches = Bits.to_unsigned_int !(outputs.n_matches.value) in
  Printf.printf "Result: %d\n" n_matches;
  sim

let _run_real_thing =
  let lines = read_data in
  let parsed_numbers = List.map parse_string lines in
  let cpu_result = ocaml_solution parsed_numbers in
  let waves_config = Waves_config.no_waves in
  let b = testbench ~data:parsed_numbers in
  let sim = Harness.run_advanced ~waves_config ~create:Password_analyser.hierarchical b in
  let outputs = Cyclesim.outputs sim in
  let sim_result = Bits.to_unsigned_int !(outputs.n_matches.value) in
  Printf.printf "CPU Result: %d\n" cpu_result;
  Printf.printf "Sim Result: %d\n" sim_result;
  let sim_n_passes = Bits.to_unsigned_int !(outputs.n_passes.value) in
  Printf.printf "Sim N Passes: %d\n" sim_n_passes;
  Printf.printf "Total result: %d\n" (sim_result + sim_n_passes);
  assert ((sim_result + sim_n_passes) = 6106)
(* 
let _ =
  for _ = 1 to 10 do
    let parsed_numbers = List.init 10000 (fun _ -> Random.int_in_range ~min:(-1000) ~max:1000) in
    let cpu_result = ocaml_solution parsed_numbers in
    let waves_config = Waves_config.no_waves in
    let b = testbench ~data:parsed_numbers in
    let sim = Harness.run_advanced ~waves_config ~create:Password_analyser.hierarchical b in
    let outputs = Cyclesim.outputs sim in
    let sim_result = Bits.to_unsigned_int !(outputs.n_matches.value) in
    if (cpu_result = sim_result)
      then Printf.printf "Test passed: OCaml Result: %d, Sim Result: %d\n" cpu_result sim_result
      else
        Printf.printf
          "Test FAILED: OCaml Result: %d, Sim Result: %d\n"
          cpu_result
          sim_result
  done; *)
