# Keep these cases in sync with r/tests/testthat/test-prspace.R.
import math

import pytest

from prspace import (
    Event,
    InconsistentProbabilityError,
    InconsistentProbabilityWarning,
    PrSpace,
    UndefinedProbabilityError,
)


def test_readme_example():
    n_samples = math.comb(2 * 10 - 1, 10)
    Pr = PrSpace()
    S_B = Event()
    for B in (100, 1000):
        Pr[S_B == 0] = math.prod(1 - k / n_samples for k in range(B))
        Pr[S_B >= 1] = 1 - Pr[S_B == 0]
        assert Pr[S_B == 0] + Pr[S_B >= 1] == pytest.approx(1)
    assert Pr[S_B == 0] == pytest.approx(math.prod(1 - k / n_samples for k in range(1000)))


def test_assign_and_read():
    Pr = PrSpace()
    X = Event()
    Pr[X == 0] = 0.25
    assert Pr[X == 0] == 0.25
    assert len(Pr) == 1


def test_complements_are_derived():
    Pr = PrSpace()
    X = Event()
    Pr[X == 0] = 0.25
    assert Pr[X != 0] == 0.75
    assert Pr[~(X == 0)] == 0.75
    Pr[X < 3] = 0.4
    assert Pr[X >= 3] == pytest.approx(0.6)


def test_assigning_replaces_stored_complement():
    Pr = PrSpace()
    X = Event()
    Pr[X != 0] = 0.9
    Pr[X == 0] = 0.3
    assert len(Pr) == 1
    assert Pr[X != 0] == pytest.approx(0.7)


def test_reversed_comparisons():
    Pr = PrSpace()
    X = Event()
    Pr[1 <= X] = 0.4
    assert Pr[X >= 1] == 0.4
    Pr[0 == X] = 0.1
    assert Pr[X == 0] == 0.1


def test_values_are_part_of_the_key():
    Pr = PrSpace()
    X = Event()
    Pr[X == 0] = 0.1
    Pr[X == 1] = 0.2
    assert (Pr[X == 0], Pr[X == 1]) == (0.1, 0.2)
    Coin = Event(support=["H", "T"])
    Pr[Coin == "H"] = 0.5
    assert Pr[Coin == "H"] == 0.5


def test_events_are_distinct():
    Pr = PrSpace()
    X, Y = Event(), Event()
    Pr[X == 0] = 0.1
    with pytest.raises(UndefinedProbabilityError):
        Pr[Y == 0]


def test_undefined_probability_message():
    Pr = PrSpace()
    X = Event()
    with pytest.raises(UndefinedProbabilityError, match=r"Pr\[X >= 1\] has not been assigned"):
        Pr[X >= 1]


def test_names_are_inferred_or_given():
    X = Event()
    Z = Event("Z_total")
    assert str(X == 0) == "X == 0"
    assert str(Z > 2) == "Z_total > 2"


def test_rejects_bad_probabilities():
    Pr = PrSpace()
    X = Event()
    for bad in (-0.1, 1.5, float("nan")):
        with pytest.raises(ValueError):
            Pr[X == 0] = bad
    for bad in ("0.5", None, True):
        with pytest.raises(TypeError):
            Pr[X == 0] = bad


def test_rejects_bad_keys():
    Pr = PrSpace()
    X = Event()
    with pytest.raises(TypeError):
        Pr[X] = 0.5
    with pytest.raises(TypeError):
        Pr["X == 0"] = 0.5
    with pytest.raises(TypeError):
        X == [1, 2]


def test_condition_is_not_a_bool():
    X = Event()
    with pytest.raises(TypeError):
        if X == 0:
            pass


def test_delete():
    Pr = PrSpace()
    X = Event()
    Pr[X == 0] = 0.25
    del Pr[X != 0]  # deleting via the complement removes the stored value
    assert len(Pr) == 0
    with pytest.raises(UndefinedProbabilityError):
        del Pr[X == 0]


def test_print():
    Pr = PrSpace()
    S_B = Event()
    assert repr(Pr) == "PrSpace with no probabilities assigned"
    Pr[S_B == 0] = 0.25
    assert repr(Pr) == "PrSpace with 1 probability:\n  Pr[S_B == 0] = 0.25"


# ---- supports, derivation and consistency checks ----


def test_count_support_derives_complement():
    Pr = PrSpace()
    S_B = Event(support="count")
    Pr[S_B == 0] = 0.25
    assert Pr[S_B >= 1] == 0.75
    assert Pr[S_B > 0] == 0.75
    assert Pr[S_B < 0] == 0.0
    assert Pr[S_B >= 0] == 1.0
    assert Pr[S_B == 1.5] == 0.0


def test_readme_example_with_count_support_in_error_mode():
    n_samples = math.comb(2 * 10 - 1, 10)
    Pr = PrSpace(check="error")
    S_B = Event(support="count")
    for B in (1000, 100):  # probabilities go up and down; reassignment is never flagged
        Pr[S_B == 0] = math.prod(1 - k / n_samples for k in range(B))
        Pr[S_B >= 1] = 1 - Pr[S_B == 0]
    assert len(Pr) == 1  # on a count support these are complements, so one replaces the other
    assert Pr[S_B == 0] == pytest.approx(math.prod(1 - k / n_samples for k in range(100)))


def test_finite_support_derives_the_rest():
    Pr = PrSpace()
    X = Event(support=[1, 2, 3])
    Pr[X == 1] = 0.2
    Pr[X == 2] = 0.3
    assert Pr[X == 3] == pytest.approx(0.5)
    assert Pr[X >= 2] == pytest.approx(0.8)
    assert Pr[X == 7] == 0.0


def test_real_support_derives_point_mass():
    Pr = PrSpace()
    X = Event()
    Pr[X <= 0] = 0.5
    Pr[X < 0] = 0.2
    assert Pr[X == 0] == pytest.approx(0.3)
    assert Pr[X > 0] == 0.5


def test_undetermined_reports_bounds():
    Pr = PrSpace()
    X = Event()
    Pr[X < 3] = 0.4
    with pytest.raises(UndefinedProbabilityError, match="between 0.4 and 1") as info:
        Pr[X < 5]
    assert (info.value.lower, info.value.upper) == pytest.approx((0.4, 1.0))


def test_derive_off_only_uses_assigned_values_and_complements():
    Pr = PrSpace(derive=False)
    X = Event(support=[1, 2, 3])
    Pr[X == 1] = 0.2
    Pr[X == 2] = 0.3
    assert Pr[X != 1] == 0.8
    with pytest.raises(UndefinedProbabilityError):
        Pr[X == 3]


def test_same_event_written_differently_is_replaced():
    Pr = PrSpace(check="error")
    X = Event(support="count")
    Pr[X < 3] = 0.4
    Pr[X <= 2] = 0.5
    assert len(Pr) == 1
    assert Pr[X < 3] == 0.5


def test_monotonicity_is_checked():
    X = Event()
    Pr = PrSpace()
    Pr[X < 3] = 0.6
    with pytest.warns(InconsistentProbabilityWarning, match="between 0.6 and 1"):
        Pr[X < 5] = 0.4
    assert len(Pr) == 2  # "warn" still stores it

    Pr = PrSpace(check="error")
    Pr[X < 3] = 0.6
    with pytest.raises(InconsistentProbabilityError):
        Pr[X < 5] = 0.4
    assert len(Pr) == 1  # "error" does not


def test_total_probability_is_checked():
    Pr = PrSpace(check="error")
    X = Event(support=[1, 2, 3])
    Pr[X == 1] = 0.6
    with pytest.raises(InconsistentProbabilityError, match="between 0 and 0.4"):
        Pr[X == 2] = 0.6
    with pytest.raises(InconsistentProbabilityError, match="it must be 0$"):
        Pr[X == 9] = 0.1


def test_check_off_is_silent():
    import warnings

    Pr = PrSpace(check="off")
    X = Event()
    Pr[X < 3] = 0.6
    with warnings.catch_warnings():
        warnings.simplefilter("error")
        Pr[X < 5] = 0.4


def test_reading_an_inconsistent_space():
    Pr = PrSpace(check="off")
    X = Event()
    Pr[X < 3] = 0.6
    Pr[X < 5] = 0.4
    with pytest.raises(InconsistentProbabilityError):
        Pr[X == 4]


def test_supports_are_validated():
    with pytest.raises(ValueError):
        Event(support="bogus")
    with pytest.raises(TypeError):
        Event(support=[1, "H"])
    X = Event()
    with pytest.raises(TypeError, match="finite numbers"):
        X == "heads"
    Coin = Event(support=["H", "T"])
    with pytest.raises(TypeError):
        Coin < "H"
    with pytest.raises(TypeError):
        Coin == 1


def test_config_is_validated():
    with pytest.raises(ValueError):
        PrSpace(check="bogus")
    with pytest.raises(TypeError):
        PrSpace(derive="yes")


def test_event_repr():
    S_B = Event(support="count")
    Coin = Event("Coin", support=["H", "T"])
    assert repr(S_B == 0) == "<Condition S_B == 0>"
    assert repr(Coin) == "<Event Coin, support: {'H', 'T'}>"
