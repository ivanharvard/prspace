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
  Pr[X == "heads"] <- 0.5
  expect_identical(c(Pr[X == 0L], Pr[X == 1], Pr[X == "heads"]), c(0.1, 0.2, 0.5))
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
