(**************************************************************************)
(*                                                                        *)
(*  Copyright (C) 2010-                                                   *)
(*    Francois Bobot                                                      *)
(*    Jean-Christophe Filliatre                                           *)
(*    Johannes Kanig                                                      *)
(*    Andrei Paskevich                                                    *)
(*                                                                        *)
(*  This software is free software; you can redistribute it and/or        *)
(*  modify it under the terms of the GNU Library General Public           *)
(*  License version 2.1, with the special exception on linking            *)
(*  described in file LICENSE.                                            *)
(*                                                                        *)
(*  This software is distributed in the hope that it will be useful,      *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                  *)
(*                                                                        *)
(**************************************************************************)

open Format
open Why
open Whyconf

(******************************)
(* loading user configuration *)
(******************************)

(*
let autodetection () = 
  let alt_ergo = {
    name    = "Alt-Ergo";
    command = "alt-ergo %s";
    driver  = "drivers/alt_ergo.drv" }
  in
  let z3 = {
    name    = "Z3";
    command = "z3 -smt -in";
    driver  = "drivers/z3.drv" }
  in
  let cvc3 = {
    name    = "CVC3";
    command = "cvc3 -lang smt";
    driver  = "drivers/cvc3.drv" }
  in
  let coq = {
    name    = "Coq";
    command = "coqc %s";
    driver  = "drivers/coq.drv" }
  in
  let provers = Util.Mstr.empty in
  let provers = Util.Mstr.add "alt-ergo" alt_ergo provers in
  let provers = Util.Mstr.add "z3" z3 provers in
  let provers = Util.Mstr.add "cvc3" cvc3 provers in
  let provers = Util.Mstr.add "coq" coq provers in
  let config = {
    conf_file = "why.conf";
    loadpath  = ["theories"];
    timelimit = Some 2;
    memlimit  = None;
    provers   = provers }
  in
  save_config config
*)

let config = 
  try 
    Whyconf.read_config None
  with 
      Not_found -> 
        eprintf "No config file found.@.";
(* "Running autodetection of provers.@.";
        autodetection ();
*)
        exit 1
    | e ->
        eprintf "%a@." Exn_printer.exn_printer e;
        exit 1

let () = printf "Load path is: %a@." (Pp.print_list Pp.comma Pp.string) config.loadpath

let env = Env.create_env (Typing.retrieve config.loadpath)

let timelimit = 
  match config.timelimit with
    | None -> 2
    | Some n -> n

(********************)
(* opening database *)
(********************)

let fname = "tests/test-claude"

let () = Db.init_base (fname ^ ".db")

let get_driver name = 
  let pi = Util.Mstr.find name config.provers in
  Driver.load_driver env pi.Whyconf.driver

type prover_data =
    { prover : Db.prover;
      command : string;
      driver : Driver.driver;
    }

let provers_data =
  printf "===============================@\nProvers: ";
  let l = 
    Util.Mstr.fold
    (fun id conf acc ->
       let name = conf.Whyconf.name in
       printf " %s, " name;
       { prover = Db.get_prover name;
         command = conf.Whyconf.command;
         driver = get_driver id; } :: acc
    ) config.provers []
  in
  printf "@\n===============================@.";
  l 
   
let () = 
  printf "previously known goals:@\n";
  List.iter (fun s -> printf "%s@\n" (Db.goal_task_checksum s)) (Db.root_goals ());
  printf "@."

(***********************)
(* Parsing input file  *)
(***********************)

let m : Theory.theory Theory.Mnm.t =
  try
    let cin = open_in (fname ^ ".why") in
    let m = Env.read_channel env fname cin in
    close_in cin;
    eprintf "Parsing/Typing Ok@.";
    m
  with e -> 
    eprintf "%a@." Exn_printer.exn_printer e;
    exit 1

(***************************)
(* Process input theories  *)
(* add corresponding tasks *)
(***************************)

let add_task (tname : string) (task : Task.task) acc =
  let name = (Task.task_goal task).Decl.pr_name.Ident.id_string in
  eprintf "doing task: tname=%s, name=%s@." tname name;
  Db.add_or_replace_task ~tname ~name task :: acc

let do_theory tname th glist =
  let tasks = Task.split_theory th None None in
  List.fold_right (add_task tname) tasks glist


(***********************************)
(* back to the eighties:           *)
(* A good-old text-based interface *)
(***********************************)

let count = ref 0

let goal_menu g = 
  try
    while true do 
      printf "Choose a prover:@.";
      let _,menu = List.fold_left
        (fun (i,acc) p -> 
           let i = succ i in
           printf "%2d: try %s@." i (Db.prover_name p.prover);
           (i,(i,p)::acc)) (0,[]) provers_data
      in
      let s = read_line () in
      (try 
         let i = try int_of_string s with Failure _ -> raise Not_found in
         let p = List.assoc i menu in
         (* this was for calling db directly *)
         (**
         let call = 
	   try
             Db.try_prover ~debug:true ~timelimit ~memlimit:0 
               ~prover:p.prover ~command:p.command ~driver:p.driver g 
           with Db.AlreadyAttempted ->
             printf "Proof already attempted, no need to rerun@.";
             raise Exit
	 in
         call ();
         raise Exit
         **)
         (* this is for calling the scheduler *)
         incr count;
         let c = !count in
         printf "Scheduling task #%d@." c;
         let callback result =
           printf "Scheduled task #%d: status set to %a, you should update the view@." c Db.print_status result
         in
         Scheduler.schedule_proof_attempt
           ~debug:false ~timelimit ~memlimit:0 
           ~prover:p.prover ~command:p.command ~driver:p.driver 
           ~callback
           ~async:(fun f -> f ())
           g;
         raise Exit           
       with Not_found -> 
         printf "unknown choice@.");
    done
  with Exit -> ()
    
let main_loop goals =
  try
    while true do
      printf "======================@\nMenu:@.";
      printf " 0: exit@.";
      let _,menu = List.fold_left
        (fun (i,acc) g -> 
           let i = succ i in
           printf "%2d: name='%s', proved=%b@." i 
             (Db.goal_name g) (Db.goal_proved g);
           let e = Db.external_proofs g in
           List.iter 
             (fun e ->
                let p = Db.prover e in
                printf 
                  "    external proof: prover=%s, obsolete=%b\
                       , result=%a, time=%.2f@."
                  (Db.prover_name p) (Db.proof_obsolete e) 
                  Db.print_status (Db.status e)
                  (Db.result_time e))
             
             e;
           (i,(i,g)::acc)) (0,[]) goals
      in
      let s = read_line () in
      (try 
         let i = int_of_string s in
         if i=0 then raise Exit; 
         goal_menu (List.assoc i menu)
       with Not_found | Failure _ -> 
         printf "unknown choice@.");
    done
  with Exit -> ()
  

(****************)
(* Main program *)
(****************)

let () =
  eprintf "looking for goals@.";
  let add_th t th mi = 
    eprintf "adding theory %s, %s@." th.Theory.th_name.Ident.id_string t;
    Ident.Mid.add th.Theory.th_name (t,th) mi 
  in
  let do_th _ (t,th) glist = 
    eprintf "doing theory %s, %s@." th.Theory.th_name.Ident.id_string t;
    do_theory t th glist  
  in
  let goals = 
    Ident.Mid.fold do_th (Theory.Mnm.fold add_th m Ident.Mid.empty) []
  in
  eprintf "Production of goals done@.";
  try
    main_loop goals
  with Exit -> eprintf "Exiting...@."




(*
Local Variables: 
compile-command: "make -C ../.. bin/why-ide.byte"
End: 
*)




