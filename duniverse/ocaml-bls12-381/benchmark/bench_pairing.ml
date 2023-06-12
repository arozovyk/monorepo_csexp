(*****************************************************************************)
(*                                                                           *)
(* Copyright (c) 2020-2021 Danny Willems <be.danny.willems@gmail.com>        *)
(*                                                                           *)
(* Permission is hereby granted, free of charge, to any person obtaining a   *)
(* copy of this software and associated documentation files (the "Software"),*)
(* to deal in the Software without restriction, including without limitation *)
(* the rights to use, copy, modify, merge, publish, distribute, sublicense,  *)
(* and/or sell copies of the Software, and to permit persons to whom the     *)
(* Software is furnished to do so, subject to the following conditions:      *)
(*                                                                           *)
(* The above copyright notice and this permission notice shall be included   *)
(* in all copies or substantial portions of the Software.                    *)
(*                                                                           *)
(* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR*)
(* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  *)
(* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL   *)
(* THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER*)
(* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING   *)
(* FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER       *)
(* DEALINGS IN THE SOFTWARE.                                                 *)
(*                                                                           *)
(*****************************************************************************)

open Core
open Core_bench

let t1 =
  let open Bls12_381 in
  let g1 = G1.random () in
  let g2 = G2.random () in
  Bench.Test.create ~name:"Pairing" (fun () ->
      ignore @@ Bls12_381.Pairing.pairing g1 g2)

let t2 =
  let open Bls12_381 in
  let g1 = G1.random () in
  let g2 = G2.random () in
  Bench.Test.create ~name:"Miller loop simple" (fun () ->
      ignore @@ Bls12_381.Pairing.miller_loop_simple g1 g2)

let t3 =
  let open Bls12_381 in
  let x = Fq12.random () in
  Bench.Test.create ~name:"Final exponentiation" (fun () ->
      ignore @@ Bls12_381.Pairing.final_exponentiation_exn x)

let miller_loop_benches =
  let open Bls12_381 in
  List.init 10 ~f:(fun i ->
      let p = List.init (1 + i) ~f:(fun _i -> (G1.random (), G2.random ())) in
      let name = Printf.sprintf "Miller loop on %d couples of points" (i + 1) in
      Bench.Test.create ~name (fun () ->
          ignore @@ Bls12_381.Pairing.miller_loop p))

let () =
  Command_unix.run (Bench.make_command ([t1; t2; t3] @ miller_loop_benches))
