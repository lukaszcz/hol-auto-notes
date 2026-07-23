#!/usr/bin/env python3
"""Pure shared v9 supervisor classification and status derivation."""
from __future__ import annotations


def derive(record):
    """Return the sole classification/status implied by a complete record.

    Syntactic and type validation belongs to the closed-schema validator.
    This function deliberately performs only the ordered semantic derivation
    shared with the supervisor.
    """
    degraded = bool(record["cleanup_errors"])
    events = record["requested_outer_signals"]
    first_status = None if not events else events[0]["requested_status"]

    if not record["containment_cleared"]:
        return "failure_containment_uncleared", 125
    if degraded:
        return "failure_cleanup_degraded_contained", 125
    if events:
        boundary = "post_go" if record["go_committed"] else "pre_go"
        return ("cancelled_%s_%s_contained" %
                (boundary, events[0]["signal"]), first_status)
    if record["primary_exception"] is not None:
        return "failure_exception_contained", 125
    if record["timed_out"]:
        return "timeout_contained", 124

    wrapper_status = record["wrapper_returncode"]
    if wrapper_status is None:
        return "failure_missing_wrapper_status", 125
    if wrapper_status == 0:
        return "completed_exit_0", 0
    return ("completed_exit_nonzero",
            wrapper_status if wrapper_status >= 0
            else 128 + (-wrapper_status))
