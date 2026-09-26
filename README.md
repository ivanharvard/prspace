# prspace

Probability spaces with the same syntax in **P**ython and **R**: `Pr[X == 0] = 0.25`.

> **Alpha.** The API may change between 0.x releases.

<table>
<tr><th>R</th><th>Python</th></tr>
<tr><td>

```r
library(prspace)

Pr = PrSpace()
S_B = Event()

for (B in c(100, 1000)) {
  Pr[S_B == 0] = prod(1 - (0:(B - 1) / n_samples))
  Pr[S_B >= 1] = 1 - Pr[S_B == 0]
  cat("Pr[S_B >= 1] =", Pr[S_B >= 1], "\n")
}
```

</td><td>

```python
from prspace import PrSpace, Event

Pr = PrSpace()
S_B = Event()

for B in (100, 1000):
    Pr[S_B == 0] = math.prod(1 - k / n_samples for k in range(B))
    Pr[S_B >= 1] = 1 - Pr[S_B == 0]
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
| New space | `Pr = PrSpace()` | `Pr = PrSpace()` |
| New event | `X = Event()` or `Event("X")` | `X = Event()` or `Event("X")` |
| Condition | `X == 0`, `X != 0`, `X < 3`, `X >= 1`, … | same |
| Complement | `!(X == 0)` | `~(X == 0)` |
| Assign | `Pr[X == 0] = 0.25` | `Pr[X == 0] = 0.25` |
| Read | `Pr[X == 0]` | `Pr[X == 0]` |
| Remove | `Pr[X == 0] = NULL` | `del Pr[X == 0]` |
| Count | `length(Pr)` | `len(Pr)` |
| Unassigned read | error of class `prspace_undefined` | `UndefinedProbabilityError` (a `KeyError`) |

Behaviour, identical in both languages:

- **Complements are derived.** After `Pr[X == 0] = 0.25`, `Pr[X != 0]` is `0.75`. The complement
  pairs are `==`/`!=`, `<`/`>=` and `>`/`<=`. Nothing else is inferred: `Pr[X >= 1]` is *not*
  derived from `Pr[X == 0]`, because prspace does not know `X` is a non-negative integer.
- **Assigning a condition replaces its stored complement**, so the space never holds two values that
  contradict each other.
- **Probabilities must be single numbers in [0, 1].**
- **Event names are inferred** from the variable an event is bound to the first time it is compared,
  so `S_B = Event()` prints as `S_B`. Pass `Event("name")` to set one explicitly.
- **Reversed comparisons work.** `0 < X` is the same condition as `X > 0`.
- `PrSpace` has reference semantics in both languages: a function that modifies it modifies the
  caller's space.

## Repository layout

```
python/   Python package (PyPI: prspace)
r/        R package (r-universe: ivanharvard/prspace)
```

The two implementations are kept in lockstep. Any change to behaviour goes into both, and
`python/tests/test_prspace.py` and `r/tests/testthat/test-prspace.R` mirror each other case for case.

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
