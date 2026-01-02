open! Hardcaml
open! Hardcaml_waveterm
open! Hardcaml_test_harness
module Password_analyser = Advent_of_hardware.Password_analyser
module Harness = Cyclesim_harness.Make (Password_analyser.I) (Password_analyser.O)

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
  let n_passes = ref 0 in
  List.iter
    (fun n ->
      let s = !position + n in
       
      let new_position = (!position + n) mod 100 in
      let new_position = if new_position < 0 then new_position + 100 else new_position
      in
      position := new_position;
      if !position = 0 then n_matches := !n_matches + 1;

      let passes = if n >= 0 then
          (* Positive n -- easy *)
          let passes = s / 100 in
          if !position = 0 then passes - 1 else passes
        else
          (* Negative n -- bit harder *)
          let prev_position = s - n in
          if (abs n) <= prev_position then 0 else
            let past_zero = (abs n) - prev_position in
            let base_passes = past_zero / 100 in
            let passes = if !position = 0 then base_passes - 1 else base_passes
            in
            if prev_position = 0 then passes else passes + 1
      in
      n_passes := !n_passes + passes
    )
    data;
  (!n_matches, !n_passes)

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
  List.iter feed_input data;
  inputs.finish := Bits.vdd;
  cycle ();
  inputs.finish := Bits.gnd;
  cycle ();
  cycle ();
  cycle ();
  sim


let run_on_aoc_data =
  fun _ ->
  let read_data =
    let data_file_path = try
        Sys.argv.(1)
      with _ -> failwith "Please provide the path to the input data file as the first argument." in
    In_channel.with_open_bin data_file_path In_channel.input_lines
  in
  let parsed_numbers = List.map parse_string read_data in
  let ocaml_n_matches = fst (ocaml_solution parsed_numbers) in
  let ocaml_n_passes = snd (ocaml_solution parsed_numbers) in
  let waves_config = Waves_config.no_waves in
  let b = testbench ~data:parsed_numbers in
  let sim = Harness.run_advanced ~waves_config ~create:Password_analyser.hierarchical b in
  let outputs = Cyclesim.outputs sim in
  
  let sim_n_matches = Bits.to_unsigned_int !(outputs.n_matches.value) in
  Printf.printf "OCaml n_matches: %d\n" ocaml_n_matches;
  Printf.printf "Hardcaml n_matches: %d\n" sim_n_matches;
  
  let sim_n_passes = Bits.to_unsigned_int !(outputs.n_passes.value) in
  Printf.printf "OCaml n_passes: %d\n" ocaml_n_passes;
  Printf.printf "Hardcaml n_passes: %d\n" sim_n_passes;

  Printf.printf "Total OCaml result: %d\n" (ocaml_n_matches + ocaml_n_passes);
  Printf.printf "Total Hardcaml result: %d\n" (sim_n_matches + sim_n_passes);
  assert ((sim_n_matches + sim_n_passes) = 6106)

let run_on_random_data =
  fun _ ->
  Printf.printf "No data file passed: running tests on random data...\n";
  for _ = 1 to 10 do
    let parsed_numbers = List.init 10000 (fun _ -> Random.int_in_range ~min:(-1000) ~max:1000) in
    let ocaml_n_matches = fst (ocaml_solution parsed_numbers) in
    let ocaml_n_passes = snd (ocaml_solution parsed_numbers) in
    let waves_config = Waves_config.no_waves in
    let b = testbench ~data:parsed_numbers in
    let sim = Harness.run_advanced ~waves_config ~create:Password_analyser.hierarchical b in
    let outputs = Cyclesim.outputs sim in
    let cpu_result = ocaml_n_matches + ocaml_n_passes in
    let sim_result =
      (Bits.to_unsigned_int !(outputs.n_matches.value)) +
      (Bits.to_unsigned_int !(outputs.n_passes.value))
    in
    if (cpu_result = sim_result)
    then Printf.printf "Test passed: OCaml total clicks: %d, Hardcaml total clicks: %d\n"
        cpu_result sim_result
      else
        Printf.printf
          "Test FAILED: OCaml Result: %d, Sim Result: %d\n"
          cpu_result sim_result
  done

let _ =
  if Array.length Sys.argv > 1
  then run_on_aoc_data ()
  else run_on_random_data ()
