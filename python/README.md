# prspace

Probability spaces with the same syntax in Python and R: `Pr[X == 0] = 0.25`.

> **Alpha.** The API may change between 0.x releases.

```python
import math
from prspace import PrSpace, Event

n_samples = math.comb(19, 10)
Pr = PrSpace()
S_B = Event(support="count")  # 0, 1, 2, ...

for B in (100, 1000):
    Pr[S_B == 0] = math.prod(1 - k / n_samples for k in range(B))
    print("Pr[S_B >= 1] =", Pr[S_B >= 1])  # derived: S_B is a count

print(Pr)
# PrSpace with 1 probability:
#   Pr[S_B == 0] = 0.004397413
```

- Complements are derived: after `Pr[X == 0] = 0.25`, `Pr[X != 0]` and `Pr[~(X == 0)]` are `0.75`.
- `Event(support=...)` takes `"real"` (default), `"integer"`, `"count"`, or a list like `[1, 2, 3]` or
  `["H", "T"]`, and anything the rules of probability then pin down is derived.
- `PrSpace(check="warn" | "error" | "off", derive=True)`: assignments that contradict earlier ones
  warn or raise `InconsistentProbabilityError`, saying which values would have been consistent.
- Reading a value that can't be determined raises `UndefinedProbabilityError` (a `KeyError`) with the
  known bounds in `.lower` and `.upper`.
- Event names are inferred from the variable they're bound to, or pass `Event("name")`.

The R package has the same syntax. See the [repository](https://github.com/ivanharvard/prspace)
for both.
