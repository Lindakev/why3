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

type error = 
  | IllegalCharacter of char
  | UnterminatedComment
  | UnterminatedString

exception Error of error

val newline : Lexing.lexbuf -> unit

val comment : Lexing.lexbuf -> unit

val string : Lexing.lexbuf -> string

val report : Format.formatter -> error -> unit

val parse_logic_file : Lexing.lexbuf -> Ptree.logic_file
