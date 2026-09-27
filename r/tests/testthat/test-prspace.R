# Keep these cases in sync with python/tests/test_prspace.py.

test_that("readme example", {
  n_samples <- choose(2 * 10 - 1, 10)
  Pr <- PrSpace()
  S_B <- Event()
  for (B in c(100, 1000)) {
    Pr[S_B == 0] <- prod(1 - (0:(B - 1) / n_samples))
    Pr[S_B >= 1] <- 1 - Pr[S_B == 0]
    expect_equal(Pr[S_B == 0] + Pr[S_B >= 1], 1)
  }
  expect_equal(Pr[S_B == 0], prod(1 - (0:999 / n_samples)))
})

test_that("assign and read", {
  Pr <- PrSpace()
  X <- Event()
  Pr[X == 0] <- 0.25
  expect_identical(Pr[X == 0], 0.25)
  expect_identical(length(Pr), 1L)
})

test_that("complements are derived", {
  Pr <- PrSpace()
  X <- Event()
  Pr[X == 0] <- 0.25
  expect_identical(Pr[X != 0], 0.75)
  expect_identical(Pr[!(X == 0)], 0.75)
  Pr[X < 3] <- 0.4
  expect_equal(Pr[X >= 3], 0.6)
})

test_that("assigning replaces stored complement", {
  Pr <- PrSpace()
  X <- Event()
  Pr[X != 0] <- 0.9
  Pr[X == 0] <- 0.3
  expect_identical(length(Pr), 1L)
  expect_equal(Pr[X != 0], 0.7)
})

test_that("reversed comparisons", {
  Pr <- PrSpace()
  X <- Event()
  Pr[1 <= X] <- 0.4
  expect_identical(Pr[X >= 1], 0.4)
  Pr[0 == X] <- 0.1
  expect_identical(Pr[X == 0], 0.1)
})

test_that("values are part of the key", {
  Pr <- PrSpace()
  X <- Event()
  Pr[X == 0] <- 0.1
  Pr[X == 1L] <- 0.2
  expect_identical(c(Pr[X == 0L], Pr[X == 1]), c(0.1, 0.2))
  Coin <- Event(support = c("H", "T"))
  Pr[Coin == "H"] <- 0.5
  expect_identical(Pr[Coin == "H"], 0.5)
})

test_that("events are distinct", {
  Pr <- PrSpace()
  X <- Event()
  Y <- Event()
  Pr[X == 0] <- 0.1
  expect_error(Pr[Y == 0], class = "prspace_undefined")
})

test_that("undefined probability message", {
  Pr <- PrSpace()
  X <- Event()
  expect_error(Pr[X >= 1], "Pr[X >= 1] has not been assigned", fixed = TRUE, class = "prspace_undefined")
})

test_that("names are inferred or given", {
  X <- Event()
  Z <- Event("Z_total")
  expect_identical(format(X == 0), "X == 0")
  expect_identical(format(Z > 2), "Z_total > 2")
})

test_that("rejects bad probabilities", {
  Pr <- PrSpace()
  X <- Event()
  for (bad in list(-0.1, 1.5, NaN, NA_real_, "0.5", TRUE, c(0.1, 0.2))) {
    expect_error(Pr[X == 0] <- bad)
  }
})

test_that("rejects bad keys", {
  Pr <- PrSpace()
  X <- Event()
  expect_error(Pr[X] <- 0.5, "bare Event")
  expect_error(Pr["X == 0"] <- 0.5, "condition")
  expect_error(X == c(1, 2), "single")
})

test_that("condition is not a logical", {
  X <- Event()
  expect_error(if (X == 0) NULL)
})

test_that("delete", {
  Pr <- PrSpace()
  X <- Event()
  Pr[X == 0] <- 0.25
  Pr[X != 0] <- NULL
  expect_identical(length(Pr), 0L)
  expect_error(Pr[X == 0] <- NULL, class = "prspace_undefined")
})

test_that("print", {
  Pr <- PrSpace()
  S_B <- Event()
  expect_output(print(Pr), "^PrSpace with no probabilities assigned$")
  Pr[S_B == 0] <- 0.25
  expect_identical(capture.output(print(Pr)), c("PrSpace with 1 probability:", "  Pr[S_B == 0] = 0.25"))
})

# ---- supports, derivation and consistency checks ----

test_that("count support derives complement", {
  Pr <- PrSpace()
  S_B <- Event(support = "count")
  Pr[S_B == 0] <- 0.25
  expect_identical(Pr[S_B >= 1], 0.75)
  expect_identical(Pr[S_B > 0], 0.75)
  expect_identical(Pr[S_B < 0], 0)
  expect_identical(Pr[S_B >= 0], 1)
  expect_identical(Pr[S_B == 1.5], 0)
})

test_that("readme example with count support in error mode", {
  n_samples <- choose(2 * 10 - 1, 10)
  Pr <- PrSpace(check = "error")
  S_B <- Event(support = "count")
  for (B in c(1000, 100)) {  # probabilities go up and down; reassignment is never flagged
    Pr[S_B == 0] <- prod(1 - (0:(B - 1) / n_samples))
    Pr[S_B >= 1] <- 1 - Pr[S_B == 0]
  }
  expect_identical(length(Pr), 1L)  # on a count support these are complements, so one replaces the other
  expect_equal(Pr[S_B == 0], prod(1 - (0:99 / n_samples)))
})

test_that("finite support derives the rest", {
  Pr <- PrSpace()
  X <- Event(support = c(1, 2, 3))
  Pr[X == 1] <- 0.2
  Pr[X == 2] <- 0.3
  expect_equal(Pr[X == 3], 0.5)
  expect_equal(Pr[X >= 2], 0.8)
  expect_identical(Pr[X == 7], 0)
})

test_that("real support derives point mass", {
  Pr <- PrSpace()
  X <- Event()
  Pr[X <= 0] <- 0.5
  Pr[X < 0] <- 0.2
  expect_equal(Pr[X == 0], 0.3)
  expect_identical(Pr[X > 0], 0.5)
})

test_that("undetermined reports bounds", {
  Pr <- PrSpace()
  X <- Event()
  Pr[X < 3] <- 0.4
  err <- expect_error(Pr[X < 5], "between 0.4 and 1", class = "prspace_undefined")
  expect_equal(c(err$lower, err$upper), c(0.4, 1))
})

test_that("derive off only uses assigned values and complements", {
  Pr <- PrSpace(derive = FALSE)
  X <- Event(support = c(1, 2, 3))
  Pr[X == 1] <- 0.2
  Pr[X == 2] <- 0.3
  expect_identical(Pr[X != 1], 0.8)
  expect_error(Pr[X == 3], class = "prspace_undefined")
})

test_that("same event written differently is replaced", {
  Pr <- PrSpace(check = "error")
  X <- Event(support = "count")
  Pr[X < 3] <- 0.4
  Pr[X <= 2] <- 0.5
  expect_identical(length(Pr), 1L)
  expect_identical(Pr[X < 3], 0.5)
})

test_that("monotonicity is checked", {
  X <- Event()
  Pr <- PrSpace()
  Pr[X < 3] <- 0.6
  expect_warning(Pr[X < 5] <- 0.4, "between 0.6 and 1", class = "prspace_inconsistent")
  expect_identical(length(Pr), 2L)  # "warn" still stores it

  Pr <- PrSpace(check = "error")
  Pr[X < 3] <- 0.6
  expect_error(Pr[X < 5] <- 0.4, class = "prspace_inconsistent")
  expect_identical(length(Pr), 1L)  # "error" does not
})

test_that("total probability is checked", {
  Pr <- PrSpace(check = "error")
  X <- Event(support = c(1, 2, 3))
  Pr[X == 1] <- 0.6
  expect_error(Pr[X == 2] <- 0.6, "between 0 and 0.4", class = "prspace_inconsistent")
  expect_error(Pr[X == 9] <- 0.1, "it must be 0$", class = "prspace_inconsistent")
})

test_that("check off is silent", {
  Pr <- PrSpace(check = "off")
  X <- Event()
  Pr[X < 3] <- 0.6
  expect_no_warning(Pr[X < 5] <- 0.4)
})

test_that("reading an inconsistent space", {
  Pr <- PrSpace(check = "off")
  X <- Event()
  Pr[X < 3] <- 0.6
  Pr[X < 5] <- 0.4
  expect_error(Pr[X == 4], class = "prspace_inconsistent")
})

test_that("supports are validated", {
  expect_error(Event(support = "bogus"), "unknown support")
  expect_error(Event(support = list(1, "H")))
  X <- Event()
  expect_error(X == "heads", "finite numbers")
  Coin <- Event(support = c("H", "T"))
  expect_error(Coin < "H", "unordered")
  expect_error(Coin == 1, "string")
})

test_that("config is validated", {
  expect_error(PrSpace(check = "bogus"))
  expect_error(PrSpace(derive = "yes"))
})

test_that("event print", {
  S_B <- Event(support = "count")
  Coin <- Event("Coin", support = c("H", "T"))
  expect_output(print(S_B == 0), "^<Condition S_B == 0>$")
  expect_output(print(Coin), '^<Event Coin, support: \\{"H", "T"\\}>$')
})
