# Timed sequence type guard diagnostic

The public signature declares independent abstract
`measured_rule_sequence` and `timed_rule_sequence` types.  The implementation
defines `timed_rule_sequence` as a nominal datatype wrapping the shared
private measured state and its timing state.  Positive typed consumers in
`classical/selftest.sml`, all production consumers, and both complete
directory builds compile against that API.

`timed-api-good.sml` and `timed-api-bad.sml` were an attempted additional
external negative compile probe.  The retained logs show that the temporary
Holmake invocations only scanned dependencies and returned without analysing
either temporary client, including the intentionally ill-typed client.
Therefore those invocations are unreliable diagnostics and are **not**
claimed as compile-guard evidence.  They are retained rather than rewritten
as a false success.  Static distinction is established by the checked
abstract signature, nominal implementation datatype and the positive typed
consumers; no negative Holmake-client claim is made.
