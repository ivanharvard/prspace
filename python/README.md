# prspace

Probability spaces with the same syntax in Python and R: `Pr[X == 0] = 0.25`.

> **Alpha.** The API may change between 0.x releases.

```python
import math
from prspace import PrSpace, Event

n_samples = math.comb(19, 10)
Pr = PrSpace()
S_B = Event()

for B in (100, 1000):
    Pr[S_B == 0] = math.prod(1 - k / n_samples for k in range(B))
    Pr[S_B >= 1] = 1 - Pr[S_B == 0]
    print("Pr[S_B >= 1] =", Pr[S_B >= 1])

print(Pr)
# PrSpace with 2 probabilities:
#   Pr[S_B == 0] = 0.004397413
#   Pr[S_B >= 1] = 0.9956026
```

- Complements are derived: after `Pr[X == 0] = 0.25`, `Pr[X != 0]` and `Pr[~(X == 0)]` are `0.75`.
- Reading a condition that was never assigned raises `UndefinedProbabilityError` (a `KeyError`).
- Event names are inferred from the variable they're bound to, or pass `Event("name")`.

The R package has the same syntax. See the [repository](https://github.com/ivanharvard/prspace)
for both.
