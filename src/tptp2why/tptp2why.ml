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

(** this is a tool to convert tptp files (.p files) to .why files *)

open TptpTree

open Why

open Lexing

open TptpTranslate


(** module to process a single file *)
module Process : sig
  val printFile : Format.formatter -> string -> string -> string -> unit
end= struct

  let fromInclude = function | Include x -> x | _ -> assert false
  (** for a given file, returns the list of declarations
  for this file and all the files it includes, recursively *)
  let rec getAllDecls ?first:(first=false) include_dir filename =
    let rec myparse chan =
      let lb = Lexing.from_channel chan in
      try TptpParser.tptp TptpLexer.token lb
      with
      | TptpLexer.LexicalError s -> report lb;
        Format.eprintf "lexical error: %s@." s; exit 1
      | TptpParser.Error -> report lb; Format.eprintf "syntax error@."; exit 1
    and report lb = let pos = lexeme_start_p lb in
      Format.eprintf "file %s, line %d, char %d@."
      filename (pos.pos_lnum) (pos.pos_cnum-pos.pos_bol) in
    try
      let filename = if first then filename else include_dir^"/"^filename in
      let input = if filename = "-" then stdin else open_in filename in
      let decls = myparse input in
      (* Format.eprintf "parsing done (%d decls)@." (List.length decls); *)
      let isInclude = function | Include _ -> true | _ -> false in
      close_in input;
      let (to_include, real_decl) = List.partition isInclude decls in
      let to_include = List.map fromInclude to_include in (* remove Include *)
      let all_decls = List.concat
        (List.map (getAllDecls include_dir) to_include) in
      all_decls @ real_decl
    with (Sys_error _) as e ->
      print_endline ("error : unable to open "^filename);
      raise e


  (** process a single file and all includes inside *)
  let printFile fmter include_dir theoryName filename =
    let decls = getAllDecls ~first:true include_dir filename in
    let theory = TptpTranslate.theory_of_decls theoryName decls in
    (* Format.eprintf "translation done@."; *)
    Pretty.print_theory fmter theory

end



(*s main function and arg parsing *)

open Arg

(** module for options processing *)
module Init = struct

  let input_files = ref []
  let output_chan = ref (Format.formatter_of_out_channel stdout)
  let include_dir = ref "."

  let output_updater filename = if filename <> "-"
    then output_chan := Format.formatter_of_out_channel (open_out filename)
    else ()

  let include_updater s = include_dir := s

  let options = [
    ("-o", String output_updater, "outputs to a file");
    ("-I", String include_updater, "search for included files in this dir");
    ("-", Unit (fun () -> input_files := "-" :: !input_files), "reads from stdin")
  ]

  let usage = "tptp2why [file1|-] [file2...] [-o file] [-I dir]
  It parses tptp files (fof or cnf format) and prints a why file
  with one theory per input file."

end

open Init

(** read options, and process each input file accordingly *)
let _ =
  parse options (fun file -> input_files := file :: (!input_files)) usage;
  input_files := List.rev !input_files;
  let theoryCounter = ref 0 in
  List.iter
    (fun x -> let theoryName = "Theory"^(string_of_int !theoryCounter) in
              incr theoryCounter;
              Process.printFile !output_chan !include_dir theoryName x)
    !input_files
