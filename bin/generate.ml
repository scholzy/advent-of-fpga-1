open! Core
open! Hardcaml
open! Advent_of_hardware

let generate_password_analyser_rtl () =
  let module C = Circuit.With_interface (Password_analyser.I) (Password_analyser.O) in
  let scope = Scope.create ~auto_label_hierarchical_ports:true () in
  let circuit = C.create_exn ~name:"password_analyser_top" (Password_analyser.hierarchical scope) in
  let rtl_circuits =
    Rtl.create ~database:(Scope.circuit_database scope) Verilog [ circuit ]
  in
  let rtl = Rtl.full_hierarchy rtl_circuits |> Rope.to_string in
  print_endline rtl
;;

let password_analyser_rtl_command =
  Command.basic
    ~summary:""
    [%map_open.Command
      let () = return () in
      fun () -> generate_password_analyser_rtl ()]
;;

let () =
  Command_unix.run
    (Command.group ~summary:"" [ "password-analyser", password_analyser_rtl_command ])
;;
