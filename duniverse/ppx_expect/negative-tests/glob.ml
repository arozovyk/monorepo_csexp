let%expect_test _ =
  print_endline "foogle";
  print_endline "magoo";
  [%expect {|
    f*e   (glob)
    mag?o (glob)
  |}];
  print_endline "foobar";
  [%expect {|
    *baz  (glob)
  |}]
;;
