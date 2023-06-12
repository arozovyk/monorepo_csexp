[@@@js.dummy "!! This code has been generated by gen_js_api !!"]
[@@@ocaml.warning "-7-32-39"]
open! Core
open! Import
open! Gen_js_api
type t =
  | MILLISECONDLY 
  | TWO_MILLISECONDLY 
  | FIVE_MILLISECONDLY 
  | TEN_MILLISECONDLY 
  | FIFTY_MILLISECONDLY 
  | HUNDRED_MILLISECONDLY 
  | FIVE_HUNDRED_MILLISECONDLY 
  | SECONDLY 
  | TWO_SECONDLY 
  | FIVE_SECONDLY 
  | TEN_SECONDLY 
  | THIRTY_SECONDLY 
  | MINUTELY 
  | TWO_MINUTELY 
  | FIVE_MINUTELY 
  | TEN_MINUTELY 
  | THIRTY_MINUTELY 
  | HOURLY 
  | TWO_HOURLY 
  | SIX_HOURLY 
  | DAILY 
  | TWO_DAILY 
  | WEEKLY 
  | MONTHLY 
  | QUARTERLY 
  | BIANNUAL 
  | ANNUAL 
  | DECADAL 
  | CENTENNIAL 
  | NUM_GRANULARITIES [@@deriving (compare, sexp)]
let rec t_of_js : Ojs.t -> t =
  fun (x2 : Ojs.t) ->
    let x3 = x2 in
    match Ojs.int_of_js x3 with
    | 0 -> MILLISECONDLY
    | 1 -> TWO_MILLISECONDLY
    | 2 -> FIVE_MILLISECONDLY
    | 3 -> TEN_MILLISECONDLY
    | 4 -> FIFTY_MILLISECONDLY
    | 5 -> HUNDRED_MILLISECONDLY
    | 6 -> FIVE_HUNDRED_MILLISECONDLY
    | 7 -> SECONDLY
    | 8 -> TWO_SECONDLY
    | 9 -> FIVE_SECONDLY
    | 10 -> TEN_SECONDLY
    | 11 -> THIRTY_SECONDLY
    | 12 -> MINUTELY
    | 13 -> TWO_MINUTELY
    | 14 -> FIVE_MINUTELY
    | 15 -> TEN_MINUTELY
    | 16 -> THIRTY_MINUTELY
    | 17 -> HOURLY
    | 18 -> TWO_HOURLY
    | 19 -> SIX_HOURLY
    | 20 -> DAILY
    | 21 -> TWO_DAILY
    | 22 -> WEEKLY
    | 23 -> MONTHLY
    | 24 -> QUARTERLY
    | 25 -> BIANNUAL
    | 26 -> ANNUAL
    | 27 -> DECADAL
    | 28 -> CENTENNIAL
    | 29 -> NUM_GRANULARITIES
    | _ -> assert false
and t_to_js : t -> Ojs.t =
  fun (x1 : t) ->
    match x1 with
    | MILLISECONDLY -> Ojs.int_to_js 0
    | TWO_MILLISECONDLY -> Ojs.int_to_js 1
    | FIVE_MILLISECONDLY -> Ojs.int_to_js 2
    | TEN_MILLISECONDLY -> Ojs.int_to_js 3
    | FIFTY_MILLISECONDLY -> Ojs.int_to_js 4
    | HUNDRED_MILLISECONDLY -> Ojs.int_to_js 5
    | FIVE_HUNDRED_MILLISECONDLY -> Ojs.int_to_js 6
    | SECONDLY -> Ojs.int_to_js 7
    | TWO_SECONDLY -> Ojs.int_to_js 8
    | FIVE_SECONDLY -> Ojs.int_to_js 9
    | TEN_SECONDLY -> Ojs.int_to_js 10
    | THIRTY_SECONDLY -> Ojs.int_to_js 11
    | MINUTELY -> Ojs.int_to_js 12
    | TWO_MINUTELY -> Ojs.int_to_js 13
    | FIVE_MINUTELY -> Ojs.int_to_js 14
    | TEN_MINUTELY -> Ojs.int_to_js 15
    | THIRTY_MINUTELY -> Ojs.int_to_js 16
    | HOURLY -> Ojs.int_to_js 17
    | TWO_HOURLY -> Ojs.int_to_js 18
    | SIX_HOURLY -> Ojs.int_to_js 19
    | DAILY -> Ojs.int_to_js 20
    | TWO_DAILY -> Ojs.int_to_js 21
    | WEEKLY -> Ojs.int_to_js 22
    | MONTHLY -> Ojs.int_to_js 23
    | QUARTERLY -> Ojs.int_to_js 24
    | BIANNUAL -> Ojs.int_to_js 25
    | ANNUAL -> Ojs.int_to_js 26
    | DECADAL -> Ojs.int_to_js 27
    | CENTENNIAL -> Ojs.int_to_js 28
    | NUM_GRANULARITIES -> Ojs.int_to_js 29
