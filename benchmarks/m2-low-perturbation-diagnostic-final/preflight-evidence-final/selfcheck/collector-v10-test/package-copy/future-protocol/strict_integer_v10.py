#!/usr/bin/env python3
"""One strict JSON-integer contract for future protocol v10."""


def require(value, where, minimum=None, literal=None):
    """Require an actual JSON integer, then optional range/literal rules."""
    if type(value) is not int:
        raise ValueError("%s must be strict JSON integer" % where)
    if minimum is not None and value < minimum:
        raise ValueError("%s must be at least %d" % (where, minimum))
    if literal is not None and value != literal:
        raise ValueError("%s must equal %d" % (where, literal))
    return value
