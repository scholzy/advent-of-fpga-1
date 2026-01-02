# Advent of FPGA (in Hardcaml) -- day 1

As a software engineer working in low-latency hardware integration, this was my first attempt at writing RTL rather than working with Python/C++ drivers to FPGAs.

Debugging my logic using the cycle-accurate simulator visualisation felt a lot like debugging physics lab experiments during my PhD and postdoc, which was a fun discovery.

## Installation and building

This project requires OxCaml 5.2.0 and Hardcaml, as well as Core and some other small libraries.

You should be able to build the project with:
```bash
opam switch create 5.2.0+ox --repos ox=git+https://github.com/oxcaml/opam-repository.git,default
eval $(opam env --switch 5.2.0+ox)
 
opam install -y ocamlformat merlin ocaml-lsp-server utop parallel core_unix
opam install -y hardcaml hardcaml_test_harness hardcaml_waveterm ppx_hardcaml hardcaml_circuits
opam install -y core core_unix ppx_jane rope re dune
```

There's also a `Dockerfile` which should set up a working environment reproducibly.

## Hardware description

The implementation is a simple state machine in a single Hardcaml module. The interface to it is:

- `clock`, `clear`, `start`, and `finish`: digital logic signals to clock, clear, and trigger the state machine's processing.

- `data_in`: 16-bit (by default) unsigned integer input.

- `data_in_valid`: set to high when the state machine should read in and process an integer from the inputs.

- `sig_polarity`: high if the integer should be interpreted as positive, low if negative -- i.e., sets the "rotation" direction for the lock (as per the Advent of Code puzzle instructions).

There are two outputs:

- `n_matches`: the number of times the "lock" stops at zero.

- `n_passes`: the number of times the dial clicks at zero but doesn't stop there.

By summing these two outputs, you can retrieve the final output to the problem.

### State machine

The core of the circuit is a state machine that reads in steps and direction (as unsigned integers and digital logic signals, respectively) and tracks the current position, the number of times the position is at zero, and the number of times we pass by zero while moving.

I'm using `Modulo.unsigned_by_constant` and `Div.divide` from `hardcaml_circuits` to avoid needing to implement the modular arithmetic myself. Since we're only dividing by (the constant) 100 here, we can use these circuits to cheaply compute the quotients and remainders.

The slightly tricky logic happens outside the `Always` state machine, where we compute the number of times the lock passes by (but doesn't land on) zero. On one hand, being able to write this in reasonably simple OCaml-like code made development straightforward, but being limited to unsigned integers made some parts a bit tricker, like needing two functions to step by positive (right) and negative (left) values.

## Testing and simulation

The Hardcaml implementation is tested in three ways:

- Simple test cases: handwritten tests to check behaviour on inputs that are assumed to be edge cases *a priori*.

These two test suites can be run via `dune build @runtest`. This will also display an example waveform in the terminal.

- Automated testing on randomised test cases: tests to ensure correct behaviour on e.g. long input streams, large integers, etc.

This test can be run using `dune build && ./bin/main.exe`.

- Testing on the Advent of Code problem input: the most important test, checking that behaviour is definitively correct as far as we care for solving the AoC problem.

To run the real deal (i.e. solve day 1 of Advent of Code), use  `dune build && ./bin/main.exe <path_to_input_file>`.

The latter two test sets use an OCaml implementation for verification, while the first batch uses manually-verified answers.

### Data input

The Advent of Code data comes as newline-separated strings of format "L99", "R1", etc., indicating turning direction and magnitude. We transform this in OCaml into signed integers like -99 and 1, before turning these into pairs like `(99, gnd)`, `(1, vdd)`, etc. for testing.

The input magnitudes were encoded as unsigned 16-bit integers, to make sure that the rolling position tracking never overflowed. For this simple design, efficiency wasn't a particular consideration, but if it were (or we needed to fit into a very small FPGA), I would have measured the convergence of tests passing as a function of integer bit size. I suspect 14 or even 12 bits would have been sufficient here.

## Synthesis

In principle, we can synthesise this design for something like a Lattice iCE40 FPGA with a yosys script like:
```
read -vlog95 aoh.v
hierarchy
proc; opt; techmap; opt
synth_ice40;
stat;
write_verilog synth_ice40.v
write_json synth_ice40.json
```
where `aoh.v` has been generated using `bin/generate.exe > aoh.v`.

The design uses ~40 flip-flops and ~1300 LUTs, which should fit into a low-cost part like an LP4K or HX4K.

## Solution efficiency

This design takes 1 clock cycle to compute `n_passes` and 2 clock cycles per input to compute `n_matches`, in parallel.

The second cycle when computing `n_matches` was required to simplify the state machine logic. It would probably be straightforward to pipeline incrementing `n_matches` to achieve 1 clock cycle per input integer, but I chose to emphasise readability here.

In terms of logic cells, the biggest usage here is presumably in the widespread use of unsigned integer divides and modulos. Since the divisors are constant (100, in this example), we can perform the division in combinatorial logic within a cycle at the cost of logic cells.

To improve gate efficiency, we could probably pipeline the modular arithmetic through single modulo and division subcircuits, but at this stage, there was no point since the whole circuit fits inside any realistic FPGA I care about.
