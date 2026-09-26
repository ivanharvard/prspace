# Keep these cases in sync with r/tests/testthat/test-prspace.R.
import math

import pytest

from prspace import Event, PrSpace, UndefinedProbabilityError


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
    Pr[X == "heads"] = 0.5
    assert (Pr[X == 0], Pr[X == 1], Pr[X == "heads"]) == (0.1, 0.2, 0.5)


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
