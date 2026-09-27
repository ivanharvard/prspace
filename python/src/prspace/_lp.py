"""A tiny two-phase simplex: bound one probability given the ones already assigned.

Dependency-free and mirrored step for step in r/R/lp.R, so both languages derive the
same values and flag the same inconsistencies.
"""

from __future__ import annotations

EPS = 1e-9


def bounds(A: list[list[float]], b: list[float], q: list[float]) -> tuple[float, float] | None:
    """Return (min, max) of q.x subject to A x = b and x >= 0, or None if that is infeasible."""
    lo = _minimize(A, b, q)
    if lo is None:
        return None
    hi = -_minimize(A, b, [-v for v in q])  # type: ignore[operator]
    return lo, hi


def _minimize(A: list[list[float]], b: list[float], cost: list[float]) -> float | None:
    m, n = len(A), len(cost)
    # Phase 1: add one artificial variable per row and drive their sum to zero.
    T = [
        [float(v) for v in A[i]] + [1.0 if k == i else 0.0 for k in range(m)] + [float(b[i])]
        for i in range(m)
    ]
    basis = list(range(n, n + m))
    _solve(T, basis, [0.0] * n + [1.0] * m)
    if sum(T[i][-1] for i in range(m) if basis[i] >= n) > EPS:
        return None
    for i in range(m):
        if basis[i] >= n:
            j = next((j for j in range(n) if abs(T[i][j]) > EPS), None)
            if j is not None:
                _pivot(T, basis, i, j)
    # Rows whose artificial is still basic are redundant; drop them with the artificials.
    keep = [i for i in range(m) if basis[i] < n]
    T = [T[i][:n] + [T[i][-1]] for i in keep]
    basis = [basis[i] for i in keep]
    # Phase 2: minimize the real cost from the feasible basis found above.
    _solve(T, basis, cost)
    return sum(cost[basis[i]] * T[i][-1] for i in range(len(T)))


def _solve(T: list[list[float]], basis: list[int], cost: list[float]) -> None:
    ncols = len(T[0]) - 1
    while True:
        # Bland's rule (lowest index enters and leaves) rules out cycling.
        entering = None
        for j in range(ncols):
            if j in basis:
                continue
            if cost[j] - sum(cost[basis[i]] * T[i][j] for i in range(len(T))) < -EPS:
                entering = j
                break
        if entering is None:
            return
        leave, best = None, float("inf")
        for i in range(len(T)):
            if T[i][entering] > EPS:
                ratio = T[i][-1] / T[i][entering]
                if ratio < best - EPS or (abs(ratio - best) <= EPS and basis[i] < basis[leave]):
                    leave, best = i, ratio
        if leave is None:
            return  # unbounded; cannot happen when the variables sum to 1
        _pivot(T, basis, leave, entering)


def _pivot(T: list[list[float]], basis: list[int], r: int, j: int) -> None:
    p = T[r][j]
    T[r] = [v / p for v in T[r]]
    for i in range(len(T)):
        if i != r and T[i][j] != 0.0:
            f = T[i][j]
            T[i] = [a - f * b for a, b in zip(T[i], T[r])]
            if -EPS < T[i][-1] < 0.0:
                T[i][-1] = 0.0
    basis[r] = j
