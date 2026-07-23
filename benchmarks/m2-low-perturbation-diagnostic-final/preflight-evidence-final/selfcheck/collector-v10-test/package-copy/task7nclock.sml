(* Standalone exact-count clock microcalibration with a load-only branch. *)
fun required name =
  case OS.Process.getEnv name of
      SOME value => value
    | NONE => raise Fail ("missing " ^ name)

val run_kind = required "T7N_RUN_KIND"

val _ =
  if run_kind = "load-only" then
    print "LOAD_OK\n"
  else if run_kind = "calibration" then
    let
      fun integer name =
        case Int.fromString (required name) of
            SOME value => value
          | NONE => raise Fail ("invalid " ^ name)
      val sequence = integer "T7N_SEQUENCE"
      val repetition = integer "T7N_REPETITION"
      val mode = required "T7N_MODE"
      val exact_count = 61486260
      val calls = ref 0
      val sink = ref Time.zeroTime
      fun zero_clock () =
        (calls := !calls + 1; Time.zeroTime)
      fun now_clock () =
        (calls := !calls + 1; Time.now ())
      val clock =
        if mode = "Z" then zero_clock
        else if mode = "N" then now_clock
        else raise Fail "unknown mode"
      fun loop 0 = ()
        | loop remaining =
            (sink := clock (); loop (remaining - 1))
      val _ = loop exact_count
      val _ =
        if !calls = exact_count then ()
        else raise Fail "exact count mismatch"
      val sink_class =
        if Time.< (!sink, Time.zeroTime) then "negative" else "nonnegative"
    in
      print (String.concatWith "\t"
        ["V10CLOCK", Int.toString sequence, Int.toString repetition,
         mode, Int.toString exact_count, Int.toString (!calls), sink_class]
         ^ "\n")
    end
  else raise Fail "unknown T7N_RUN_KIND"

