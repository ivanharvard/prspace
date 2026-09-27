"""Core objects: PrSpace, Event, and the Condition you get by comparing an Event."""

from __future__ import annotations

import itertools
import math
import numbers
import operator
import sys
import warnings
from types import FrameType
from typing import Any

from . import _lp
from ._support import Support, as_support

_ids = itertools.count(1)

# The complement of each comparison, e.g. not (X == 0) is (X != 0).
_NEGATE = {"==": "!=", "!=": "==", "<": ">=", ">=": "<", ">": "<=", "<=": ">"}
_OPS = {
    "==": operator.eq, "!=": operator.ne, "<": operator.lt,
    "<=": operator.le, ">": operator.gt, ">=": operator.ge,
}
_CHECK_MODES = ("off", "warn", "error")


class UndefinedProbabilityError(KeyError):
    """Raised when ``Pr[cond]`` was never assigned and cannot be derived.

    ``lower`` and ``upper`` bound the value when the assigned probabilities narrow it down.
    """

    def __init__(self, condition: Condition, lower: float | None = None, upper: float | None = None):
        super().__init__(condition)
        self.condition = condition
        self.lower = lower
        self.upper = upper

    def __str__(self) -> str:
        if self.lower is None or self.upper is None or (self.lower <= 0 and self.upper >= 1):
            return (
                f"Pr[{self.condition}] has not been assigned "
                f"(nor has its complement Pr[{~self.condition}])"
            )
        return (
            f"Pr[{self.condition}] is not determined by the probabilities assigned so far; "
            f"it is between {self.lower:.7g} and {self.upper:.7g}"
        )


class InconsistentProbabilityError(ValueError):
    """Raised by a ``PrSpace(check="error")`` when an assignment breaks the rules of probability."""


class InconsistentProbabilityWarning(UserWarning):
    """Warned by a ``PrSpace(check="warn")`` when an assignment breaks the rules of probability."""


class Event:
    """A quantity you can make probability statements about.

    Comparing an Event with a value (``S_B == 0``, ``S_B >= 1``) gives a
    :class:`Condition`, which is what you index a :class:`PrSpace` with.

    ``support`` says which values the Event can take, which lets a PrSpace derive and
    check more: ``"real"`` (the default), ``"integer"``, ``"count"`` (0, 1, 2, ...), or a
    list of values such as ``[1, 2, 3]`` or ``["H", "T"]``.

    If ``name`` is omitted, it is taken from the variable the Event is bound to
    the first time it is compared, so ``S_B = Event()`` prints as ``S_B``.
    """

    def __init__(self, name: str | None = None, support: Any = None):
        if name is not None and not isinstance(name, str):
            raise TypeError("`name` must be a string")
        self._id = next(_ids)
        self.name = name
        self.support: Support = as_support(support)

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
        self.support.check_value(op, value, self.label)
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
        return f"<Event {self.label}, support: {self.support}>"


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

    Reading a condition that was not assigned returns its value if the assigned ones pin
    it down: complements (``Pr[X != 0]`` from ``Pr[X == 0]``), and with ``derive=True`` any
    consequence of the rules of probability and the Events' supports. Otherwise it raises
    :class:`UndefinedProbabilityError`, with the bounds that are known.

    ``check`` ("off", "warn" or "error") controls what happens when an assignment is
    inconsistent with the ones already made. Assigning a condition replaces any stored
    value for the same event or its complement, so reassigning it in a loop is never checked
    against its own old value.
    """

    def __init__(self, check: str = "warn", derive: bool = True) -> None:
        if check not in _CHECK_MODES:
            raise ValueError(f"`check` must be one of {', '.join(map(repr, _CHECK_MODES))}, not {check!r}")
        if not isinstance(derive, bool):
            raise TypeError("`derive` must be True or False")
        self.check = check
        self.derive = derive
        self._store: dict[tuple, tuple[Condition, float]] = {}

    def _rows(self, condition: Condition) -> tuple[list[tuple[Condition, float]], list[list[bool]], list[bool]]:
        """Stored rows on the condition's Event, their indicators, and the condition's indicator."""
        rows = [(c, p) for c, p in self._store.values() if c.event is condition.event]
        vecs = _indicators([condition] + [c for c, _ in rows])
        return rows, vecs[1:], vecs[0]

    def __setitem__(self, condition: Condition, p: Any) -> None:
        condition = _as_condition(condition)
        p = _as_probability(p, condition)
        rows, vecs, q = self._rows(condition)
        replaced = [c for (c, _), v in zip(rows, vecs) if v == q or _complementary(v, q)]
        if self.check != "off":
            others = [(row, v) for row, v in zip(rows, vecs) if row[0] not in replaced]
            problem = _inconsistency(condition, p, q, others)
            if problem is not None:
                if self.check == "error":
                    raise InconsistentProbabilityError(problem)
                warnings.warn(problem, InconsistentProbabilityWarning, stacklevel=2)
        for c in replaced:
            if c._key != condition._key:
                del self._store[c._key]
        self._store[condition._key] = (condition, p)

    def __getitem__(self, condition: Condition) -> float:
        condition = _as_condition(condition)
        rows, vecs, q = self._rows(condition)
        for (_, p), v in zip(rows, vecs):
            if v == q:
                return p
        for (_, p), v in zip(rows, vecs):
            if _complementary(v, q):
                return 1.0 - p
        if not any(q):
            return 0.0
        if all(q):
            return 1.0
        if not self.derive:
            raise UndefinedProbabilityError(condition)
        b = _lp.bounds(
            [[1.0] * len(q)] + [[float(x) for x in v] for v in vecs],
            [1.0] + [p for _, p in rows],
            [float(x) for x in q],
        )
        if b is None:
            raise InconsistentProbabilityError(
                f"cannot derive Pr[{condition}]: the probabilities assigned to "
                f"{condition.event.label} are inconsistent"
            )
        lo, hi = max(b[0], 0.0), min(b[1], 1.0)
        if hi - lo <= _lp.EPS:
            return lo
        raise UndefinedProbabilityError(condition, lo, hi)

    def __delitem__(self, condition: Condition) -> None:
        condition = _as_condition(condition)
        rows, vecs, q = self._rows(condition)
        hits = [c for (c, _), v in zip(rows, vecs) if v == q or _complementary(v, q)]
        if not hits:
            raise UndefinedProbabilityError(condition)
        for c in hits:
            del self._store[c._key]

    def __len__(self) -> int:
        return len(self._store)

    def __repr__(self) -> str:
        if not self._store:
            return "PrSpace with no probabilities assigned"
        lines = [f"PrSpace with {len(self._store)} probabilit{'y' if len(self._store) == 1 else 'ies'}:"]
        lines += [f"  Pr[{c}] = {p:.7g}" for c, p in self._store.values()]
        return "\n".join(lines)


def _indicators(conditions: list[Condition]) -> list[list[bool]]:
    """Which atoms of the Event's support each condition covers, over one shared set of atoms."""
    reps = conditions[0].event.support.atoms([c.value for c in conditions])
    return [[_OPS[c.op](r, c.value) for r in reps] for c in conditions]


def _complementary(v: list[bool], q: list[bool]) -> bool:
    return all(a != b for a, b in zip(v, q))


def _inconsistency(condition: Condition, p: float, q: list[bool], others: list) -> str | None:
    """Why assigning Pr[condition] = p contradicts the other stored rows, or None if it doesn't."""
    b = _lp.bounds(
        [[1.0] * len(q)] + [[float(x) for x in v] for _, v in others],
        [1.0] + [row[1] for row, _ in others],
        [float(x) for x in q],
    )
    label = condition.event.label
    if b is None:
        return f"the probabilities already assigned to {label} are inconsistent"
    lo, hi = b
    if lo - _lp.EPS <= p <= hi + _lp.EPS:
        return None
    allowed = f"{lo:.7g}" if hi - lo <= _lp.EPS else f"between {lo:.7g} and {hi:.7g}"
    return (
        f"Pr[{condition}] = {p:.7g} is inconsistent with the probabilities already "
        f"assigned to {label}; it must be {allowed}"
    )


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
