type 'a bench_result = { res : 'a; time : float }

let print_bench results n =
  let times = List.map (fun x -> x.time) results in
  let min_time = List.fold_left min (List.hd times) times in
  let max_time = List.fold_left max 0. times in
  let nb_bench = List.length results in
  let f_nb_bench = float_of_int nb_bench in
  let mean = List.fold_left ( +. ) 0. times /. f_nb_bench in
  let sum_square =
    List.fold_left ( +. ) 0. (List.map (fun x -> x *. x) times)
  in
  let var = (sum_square /. f_nb_bench) -. (mean *. mean) in
  let std = sqrt var in
  Printf.printf
    "\n\
     Benchmark for pippenger %d points: var = %.2f, std = %.2f [%.2fms, \
     %.2fms, %.2fms] (%d instances)\n"
    n
    var
    std
    min_time
    mean
    max_time
    nb_bench

let get_time () = Sys.time ()

let bench logn f =
  let m = 10 in
  let rec aux i bench_results =
    if i = m then bench_results
    else
      let () = Gc.full_major () in
      let n = 1 lsl logn in
      let scalars = Array.init n (fun _ -> Bls12_381.Fr.random ()) in
      let points =
        Bls12_381.G1.to_affine_array
        @@ Array.init n (fun _ -> Bls12_381.G1.random ())
      in
      let start_time = get_time () in
      let res = f points scalars in
      let end_time = get_time () in
      let bench_res = { res; time = (end_time -. start_time) *. 1000. } in
      aux (i + 1) (bench_res :: bench_results)
  in
  aux 0 []

let bench_pippenger logn =
  let benches = bench logn Bls12_381.G1.pippenger_with_affine_array in
  print_bench benches (1 lsl logn)

let () = bench_pippenger 12
