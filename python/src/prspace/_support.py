"""What values an Event can take. Mirrored in r/R/support.R.

A support splits into "atoms" given the constants an event is compared with: pieces on
which every one of those comparisons is either all true or all false. Each atom is
represented by one value inside it, so a condition's truth on the atom is just the
comparison applied to that value. Internal for now; users pick one via Event(support=...).
"""

from __future__ import annotations

import math
import numbers
from typing import Any


def _is_number(x: Any) -> bool:
    return isinstance(x, numbers.Real) and not isinstance(x, bool) and math.isfinite(x)


class Support:
    def check_value(self, op: str, value: Any, label: str) -> None:
        if not _is_number(value):
            raise TypeError(
                f"{label} has support {self}, so it can only be compared with finite numbers, "
                f"not {value!r}; for labels use e.g. Event(support=['H', 'T'])"
            )

    def atoms(self, values: list[Any]) -> list[Any]:
        raise NotImplementedError


class Real(Support):
    def atoms(self, values: list[Any]) -> list[Any]:
        crit = sorted(set(values))
        if not crit:
            return [0.0]
        reps: list[Any] = [crit[0] - 1]
        for a, b in zip(crit, crit[1:]):
            reps += [a, (a + b) / 2]
        return reps + [crit[-1], crit[-1] + 1]

    def __str__(self) -> str:
        return "real"


class Integers(Support):
    def __init__(self, low: int | None = None):
        self.low = low

    def atoms(self, values: list[Any]) -> list[Any]:
        crit = sorted({f(v) for v in values for f in (math.floor, math.ceil)})
        if self.low is not None:
            crit = [c for c in crit if c >= self.low]
        if not crit:
            return [self.low if self.low is not None else 0]
        reps: list[Any] = []
        if self.low is None:
            reps.append(crit[0] - 1)
        elif crit[0] > self.low:
            reps.append(self.low)
        for a, b in zip(crit, crit[1:]):
            reps.append(a)
            if b - a >= 2:
                reps.append(a + 1)
        return reps + [crit[-1], crit[-1] + 1]

    def __str__(self) -> str:
        return "count" if self.low == 0 else "integer"


class Finite(Support):
    def __init__(self, values: list[Any]):
        values = list(dict.fromkeys(values))
        if not values:
            raise ValueError("a finite support needs at least one value")
        self.labels = all(isinstance(v, str) for v in values)
        if not self.labels and not all(_is_number(v) for v in values):
            raise TypeError("a finite support must be all finite numbers or all strings")
        self.values = values

    def check_value(self, op: str, value: Any, label: str) -> None:
        if not self.labels:
            return super().check_value(op, value, label)
        if not isinstance(value, str):
            raise TypeError(f"{label} takes values in {self}, so compare it with a string, not {value!r}")
        if op not in ("==", "!="):
            raise TypeError(f"{label} takes unordered labels, so only == and != are supported")

    def atoms(self, values: list[Any]) -> list[Any]:
        return list(self.values)

    def __str__(self) -> str:
        return "{" + ", ".join(repr(v) for v in self.values) + "}"


def as_support(x: Any) -> Support:
    if isinstance(x, Support):
        return x
    if x is None:
        return Real()
    if isinstance(x, str):
        if x == "real":
            return Real()
        if x == "count":
            return Integers(0)
        if x == "integer":
            return Integers()
        raise ValueError(f"unknown support {x!r}; use 'real', 'integer', 'count', or a list of values")
    try:
        values = list(x)
    except TypeError:
        raise TypeError(
            f"support must be 'real', 'integer', 'count', or a list of values, not {type(x).__name__}"
        ) from None
    return Finite(values)
