"""prspace: probability spaces with the same syntax in Python and R."""

from ._core import (
    Condition,
    Event,
    InconsistentProbabilityError,
    InconsistentProbabilityWarning,
    PrSpace,
    UndefinedProbabilityError,
)

__all__ = [
    "PrSpace",
    "Event",
    "Condition",
    "UndefinedProbabilityError",
    "InconsistentProbabilityError",
    "InconsistentProbabilityWarning",
]
__version__ = "0.2.0"
