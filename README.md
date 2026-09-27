# prspace

Probability spaces with the same syntax in **P**ython and **R**: `Pr[X == 0] = 0.25`.

> **Alpha.** The API may change between 0.x releases.

<table>
<tr><th>R</th><th>Python</th></tr>
<tr><td>

```r
library(prspace)

Pr = PrSpace()
S_B = Event(support = "count")

for (B in c(100, 1000)) {
  Pr[S_B == 0] = prod(1 - (0:(B - 1) / n_samples))
  # S_B is a count, so this is derived:
  cat("Pr[S_B >= 1] =", Pr[S_B >= 1], "\n")
}
```

</td><td>

```python
from prspace import PrSpace, Event

Pr = PrSpace()
S_B = Event(support="count")

for B in (100, 1000):
    Pr[S_B == 0] = math.prod(1 - k / n_samples for k in range(B))
    # S_B is a count, so this is derived:
    print("Pr[S_B >= 1] =", Pr[S_B >= 1])
```

</td></tr>
</table>

## Install

```sh
pip install prspace
```

```r
install.packages("prspace", repos = c("https://ivanharvard.r-universe.dev", "https://cloud.r-project.org"))
```

## API

| | R | Python |
|---|---|---|
| New space | `Pr = PrSpace(check = "warn", derive = TRUE)` | `Pr = PrSpace(check="warn", derive=True)` |
| New event | `X = Event(name = NULL, support = NULL)` | `X = Event(name=None, support=None)` |
| Condition | `X == 0`, `X != 0`, `X < 3`, `X >= 1`, … | same |
| Complement | `!(X == 0)` | `~(X == 0)` |
| Assign | `Pr[X == 0] = 0.25` | `Pr[X == 0] = 0.25` |
| Read | `Pr[X == 0]` | `Pr[X == 0]` |
| Remove | `Pr[X == 0] = NULL` | `del Pr[X == 0]` |
| Count | `length(Pr)` | `len(Pr)` |
| Not determined | error of class `prspace_undefined` (fields `lower`, `upper`) | `UndefinedProbabilityError` (a `KeyError`; attributes `lower`, `upper`) |
| Inconsistent | error or warning of class `prspace_inconsistent` | `InconsistentProbabilityError` (a `ValueError`) or `InconsistentProbabilityWarning` |

### Supports

`support` says which values an event can take. The more prspace knows, the more it can derive and check.

| `support` | Values | Example |
|---|---|---|
| `"real"` (default) | any real number | a measurement |
| `"integer"` | …, -1, 0, 1, … | a net change |
| `"count"` | 0, 1, 2, … | number of successes |
| a vector / list | exactly those values | `c(1, 2, 3)`, `c("H", "T")` / `[1, 2, 3]`, `["H", "T"]` |

Only a finite support of strings can be compared with strings, and only with `==` and `!=`.

### Deriving

Reading `Pr[cond]` returns:

1. the value assigned to `cond`, or to any condition describing the same event
   (`X < 3` and `X <= 2` are the same event when `X` is a count);
2. one minus the value assigned to its complement (`X >= 1` is the complement of `X == 0` for a count);
3. 0 or 1 if the support makes the event impossible or certain (`Pr[X < 0]` for a count);
4. with `derive = TRUE`, any value the rules of probability pin down, e.g. `Pr[X == 3]` from
   `Pr[X == 1]` and `Pr[X == 2]` when the support is `{1, 2, 3}`, or `Pr[X == 0]` from `Pr[X <= 0]`
   and `Pr[X < 0]`.

Otherwise it's an error that includes the range the value is known to lie in, if any:
`Pr[X < 5] is not determined by the probabilities assigned so far; it is between 0.4 and 1`.

Derivation happens when you read a value, never ahead of time.

### Checking

With `check = "warn"` (the default) or `"error"`, each assignment is checked against the others
on the same event. prspace works out the range of values that would be consistent, so the
message says what was expected:

```
Pr[X < 5] = 0.4 is inconsistent with the probabilities already assigned to X; it must be between 0.6 and 1
```

This catches monotonicity violations, probabilities that sum past 1, and positive probability on
impossible events. `"warn"` stores the value anyway; `"error"` does not. `"off"` skips checking.

Assigning a condition replaces any stored value for the same event or its complement, so
reassigning it in a loop is never checked against its own old value.

### Other behaviour

- **Event names are inferred** from the variable an event is bound to the first time it is compared,
  so `S_B = Event()` prints as `S_B`. Pass `Event("name")` to set one explicitly.
- **Reversed comparisons work.** `0 < X` is the same condition as `X > 0`.
- `PrSpace` has reference semantics in both languages: a function that modifies it modifies the
  caller's space.
- Each event is reasoned about separately; joint and conditional probabilities are not supported yet.

## Repository layout

```
python/   Python package (PyPI: prspace)
r/        R package (r-universe: ivanharvard/prspace)
```

The two implementations are kept in lockstep. Any change to behaviour goes into both, and
`python/tests/test_prspace.py` and `r/tests/testthat/test-prspace.R` mirror each other case for case.
Derivation and checking share one small linear-programming solver (`python/src/prspace/_lp.py`,
`r/R/lp.R`) written without dependencies and kept step-for-step identical.

## Development

```sh
cd python && uv run pytest              # Python tests
R CMD INSTALL r && Rscript -e 'testthat::test_local("r")'   # R tests
```

## Releasing

1. Bump the version in `python/pyproject.toml`, `python/src/prspace/__init__.py` and `r/DESCRIPTION`
   (they must match).
2. Commit, then tag and push: `git tag v0.1.1 && git push origin main v0.1.1`.
3. The tag triggers `.github/workflows/release.yml`, which checks the three versions match, publishes
   to PyPI and creates a GitHub release. r-universe rebuilds the R package from `main` on its own.

## License

MIT
