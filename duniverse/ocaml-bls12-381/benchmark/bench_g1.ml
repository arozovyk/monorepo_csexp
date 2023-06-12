open Core
open Core_bench

let t1 =
  let open Bls12_381 in
  let s = G1.Scalar.random () in
  let p = G1.random () in
  Bench.Test.create ~name:"Multiplication on G1" (fun () -> ignore (G1.mul p s))

let t2 =
  let open Bls12_381 in
  let p = G1.random () in
  Bench.Test.create ~name:"Double on G1" (fun () -> ignore (G1.double p))

let t3 =
  let open Bls12_381 in
  let p1 = G1.random () in
  let p2 = G1.random () in
  Bench.Test.create ~name:"Addition on G1" (fun () -> ignore (G1.add p1 p2))

let t4 =
  let open Bls12_381 in
  let p = G1.random () in
  Bench.Test.create ~name:"Negate on G1" (fun () -> ignore (G1.negate p))

let t5 =
  let open Bls12_381 in
  let p = G1.random () in
  let p_bytes = G1.to_bytes p in
  Bench.Test.create ~name:"of_bytes_exn on G1" (fun () ->
      ignore (G1.of_bytes_exn p_bytes))

let t6 =
  let open Bls12_381 in
  let p = G1.random () in
  Bench.Test.create ~name:"to_bytes on G1" (fun () -> ignore (G1.to_bytes p))

let t7 =
  let open Bls12_381 in
  let p = G1.random () in
  let p_bytes = G1.to_compressed_bytes p in
  Bench.Test.create ~name:"of_compressed_bytes_exn on G1" (fun () ->
      ignore (G1.of_compressed_bytes_exn p_bytes))

let t8 =
  let open Bls12_381 in
  let p = G1.random () in
  Bench.Test.create ~name:"to_compressed_bytes on G1" (fun () ->
      ignore (G1.to_compressed_bytes p))

let t9 =
  let open Bls12_381 in
  let message_length = Random.int 512 in
  let dst_length = Random.int 48 in
  let message =
    Bytes.init message_length ~f:(fun _i -> char_of_int (Random.int 256))
  in
  let dst = Bytes.init dst_length ~f:(fun _i -> char_of_int (Random.int 48)) in
  Bench.Test.create ~name:"hash_to_curve on G1" (fun () ->
      ignore (G1.hash_to_curve message dst))

let t10 =
  let p_jacobian = Bls12_381.G1.random () in
  let p_affine = Bls12_381.G1.affine_of_jacobian p_jacobian in
  Bench.Test.create ~name:"Affine to jacobian" (fun () ->
      ignore (Bls12_381.G1.jacobian_of_affine p_affine))

let t11 =
  let p_jacobian = Bls12_381.G1.random () in
  Bench.Test.create ~name:"Jacobian to affine" (fun () ->
      ignore (Bls12_381.G1.affine_of_jacobian p_jacobian))

let command = Bench.make_command [t1; t2; t3; t4; t5; t6; t7; t8; t9; t10; t11]

let () = Command_unix.run command
