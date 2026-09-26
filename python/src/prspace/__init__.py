"""prspace: probability spaces with the same syntax in Python and R."""

from ._core import Condition, Event, PrSpace, UndefinedProbabilityError

__all__ = ["PrSpace", "Event", "Condition", "UndefinedProbabilityError"]
__version__ = "0.1.0"
