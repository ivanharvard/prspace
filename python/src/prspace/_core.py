"""Core objects: PrSpace, Event, and the Condition you get by comparing an Event."""

from __future__ import annotations

import itertools
import math
import numbers
import sys
from types import FrameType
from typing import Any

_ids = itertools.count(1)

# The complement of each comparison, e.g. not (X == 0) is (X != 0).
_NEGATE = {"==": "!=", "!=": "==", "<": ">=", ">=": "<", ">": "<=", "<=": ">"}


class UndefinedProbabilityError(KeyError):
    """Raised when reading ``Pr[cond]`` that was never assigned (directly or via its complement)."""

    def __init__(self, condition: Condition):
        super().__init__(condition)
        self.condition = condition

    def __str__(self) -> str:
        return (
            f"Pr[{self.condition}] has not been assigned "
            f"(nor has its complement Pr[{~self.condition}])"
        )


class Event:
    """A quantity you can make probability statements about.

    Comparing an Event with a value (``S_B == 0``, ``S_B >= 1``) gives a
    :class:`Condition`, which is what you index a :class:`PrSpace` with.

    If ``name`` is omitted, it is taken from the variable the Event is bound to
    the first time it is compared, so ``S_B = Event()`` prints as ``S_B``.
    """

    def __init__(self, name: str | None = None):
        if name is not None and not isinstance(name, str):
            raise TypeError("`name` must be a string")
        self._id = next(_ids)
        self.name = name

    @property
    def label(self) -> str:
        return self.name if self.name is not None else f"E{self._id}"

    def _compare(self, op: str, value: Any, frame: FrameType | None) -> Condition:
        if isinstance(value, Event):
            raise TypeError("comparing two Events is not supported yet")
        try:
            hash(value)
        except TypeError:
            raise TypeError(
                f"an Event can only be compared with a single value, not {type(value).__name__}"
            ) from None
        if self.name is None and frame is not None:
            self.name = _infer_name(self, frame)
        return Condition(self, op, value)

    # Python reflects `0 == S_B` to `S_B == 0` (and `1 <= S_B` to `S_B >= 1`) on its own.
    def __eq__(self, value: Any) -> Condition:  # type: ignore[override]
        return self._compare("==", value, sys._getframe(1))

    def __ne__(self, value: Any) -> Condition:  # type: ignore[override]
        return self._compare("!=", value, sys._getframe(1))

    def __lt__(self, value: Any) -> Condition:
        return self._compare("<", value, sys._getframe(1))

    def __le__(self, value: Any) -> Condition:
        return self._compare("<=", value, sys._getframe(1))

    def __gt__(self, value: Any) -> Condition:
        return self._compare(">", value, sys._getframe(1))

    def __ge__(self, value: Any) -> Condition:
        return self._compare(">=", value, sys._getframe(1))

    def __hash__(self) -> int:
        return hash(("prspace.Event", self._id))

    def __repr__(self) -> str:
        return f"<Event {self.label}>"


class Condition:
    """An event such as ``S_B == 0``. Use it as a key: ``Pr[S_B == 0]``.

    ``~cond`` is the complement (``~(S_B == 0)`` is ``S_B != 0``).
    """

    __slots__ = ("event", "op", "value")

    def __init__(self, event: Event, op: str, value: Any):
        self.event = event
        self.op = op
        self.value = value

    @property
    def _key(self) -> tuple:
        return (self.event._id, self.op, self.value)

    def __invert__(self) -> Condition:
        return Condition(self.event, _NEGATE[self.op], self.value)

    def __eq__(self, other: object) -> bool:
        return isinstance(other, Condition) and self._key == other._key

    def __hash__(self) -> int:
        return hash(self._key)

    def __bool__(self) -> bool:
        raise TypeError(
            f"`{self}` is an event, not True/False; use it as a key, e.g. Pr[{self}]"
        )

    def __str__(self) -> str:
        return f"{self.event.label} {self.op} {self.value!r}"

    def __repr__(self) -> str:
        return f"<Condition {self}>"


class PrSpace:
    """A probability space: assign ``Pr[cond] = p`` and read back ``Pr[cond]``.

    Complements are derived: after ``Pr[X == 0] = 0.3``, ``Pr[X != 0]`` is 0.7.
    Assigning a condition replaces any stored value for its complement.
    """

    def __init__(self) -> None:
        self._store: dict[tuple, tuple[Condition, float]] = {}

    def __setitem__(self, condition: Condition, p: Any) -> None:
        condition = _as_condition(condition)
        p = _as_probability(p, condition)
        self._store.pop((~condition)._key, None)
        self._store[condition._key] = (condition, p)

    def __getitem__(self, condition: Condition) -> float:
        condition = _as_condition(condition)
        if condition._key in self._store:
            return self._store[condition._key][1]
        complement = (~condition)._key
        if complement in self._store:
            return 1.0 - self._store[complement][1]
        raise UndefinedProbabilityError(condition)

    def __delitem__(self, condition: Condition) -> None:
        condition = _as_condition(condition)
        for key in (condition._key, (~condition)._key):
            if key in self._store:
                del self._store[key]
                return
        raise UndefinedProbabilityError(condition)

    def __len__(self) -> int:
        return len(self._store)

    def __repr__(self) -> str:
        if not self._store:
            return "PrSpace with no probabilities assigned"
        lines = [f"PrSpace with {len(self._store)} probabilit{'y' if len(self._store) == 1 else 'ies'}:"]
        lines += [f"  Pr[{c}] = {p:.7g}" for c, p in self._store.values()]
        return "\n".join(lines)


def _as_condition(x: Any) -> Condition:
    if isinstance(x, Condition):
        return x
    if isinstance(x, Event):
        raise TypeError(f"index a PrSpace with a condition such as Pr[{x.label} == 0], not a bare Event")
    raise TypeError(f"index a PrSpace with a condition such as Pr[X == 0], not {type(x).__name__}")


def _as_probability(p: Any, condition: Condition) -> float:
    if isinstance(p, bool) or not isinstance(p, numbers.Real):
        raise TypeError(f"Pr[{condition}] must be a number, not {type(p).__name__}")
    p = float(p)
    if math.isnan(p) or not 0.0 <= p <= 1.0:
        raise ValueError(f"Pr[{condition}] must be between 0 and 1, got {p}")
    return p


def _infer_name(event: Event, frame: FrameType) -> str | None:
    for scope in (frame.f_locals, frame.f_globals):
        for name, value in list(scope.items()):
            if value is event:
                return name
    return None
