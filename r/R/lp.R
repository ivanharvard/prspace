# A tiny two-phase simplex: bound one probability given the ones already assigned.
# Dependency-free and mirrored step for step in python/src/prspace/_lp.py, so both
# languages derive the same values and flag the same inconsistencies.

.eps <- 1e-9

# min and max of q.x subject to A x = b and x >= 0, or NULL if that is infeasible.
lp_bounds <- function(A, b, q) {
  lo <- lp_minimize(A, b, q)
  if (is.null(lo)) return(NULL)
  c(lo, -lp_minimize(A, b, -q))
}

lp_minimize <- function(A, b, cost) {
  m <- nrow(A)
  n <- length(cost)
  # Phase 1: add one artificial variable per row and drive their sum to zero.
  tab <- cbind(A, diag(1, m), b)
  basis <- n + seq_len(m)
  res <- lp_solve(tab, basis, c(rep(0, n), rep(1, m)))
  tab <- res$tab
  basis <- res$basis
  rhs <- ncol(tab)
  if (sum(tab[basis > n, rhs]) > .eps) return(NULL)
  for (i in seq_len(m)) {
    if (basis[i] > n) {
      j <- which(abs(tab[i, seq_len(n)]) > .eps)
      if (length(j)) {
        res <- lp_pivot(tab, basis, i, j[1])
        tab <- res$tab
        basis <- res$basis
      }
    }
  }
  # Rows whose artificial is still basic are redundant; drop them with the artificials.
  keep <- basis <= n
  tab <- tab[keep, c(seq_len(n), rhs), drop = FALSE]
  basis <- basis[keep]
  # Phase 2: minimize the real cost from the feasible basis found above.
  res <- lp_solve(tab, basis, cost)
  sum(cost[res$basis] * res$tab[, ncol(res$tab)])
}

lp_solve <- function(tab, basis, cost) {
  rhs <- ncol(tab)
  repeat {
    # Bland's rule (lowest index enters and leaves) rules out cycling.
    entering <- NA
    for (j in seq_len(rhs - 1L)) {
      if (j %in% basis) next
      if (cost[j] - sum(cost[basis] * tab[, j]) < -.eps) {
        entering <- j
        break
      }
    }
    if (is.na(entering)) break
    leave <- NA
    best <- Inf
    for (i in seq_len(nrow(tab))) {
      if (tab[i, entering] > .eps) {
        ratio <- tab[i, rhs] / tab[i, entering]
        if (ratio < best - .eps || (abs(ratio - best) <= .eps && basis[i] < basis[leave])) {
          leave <- i
          best <- ratio
        }
      }
    }
    if (is.na(leave)) break  # unbounded; cannot happen when the variables sum to 1
    res <- lp_pivot(tab, basis, leave, entering)
    tab <- res$tab
    basis <- res$basis
  }
  list(tab = tab, basis = basis)
}

lp_pivot <- function(tab, basis, r, j) {
  rhs <- ncol(tab)
  tab[r, ] <- tab[r, ] / tab[r, j]
  for (i in seq_len(nrow(tab))) {
    if (i != r && tab[i, j] != 0) {
      tab[i, ] <- tab[i, ] - tab[i, j] * tab[r, ]
      if (tab[i, rhs] < 0 && tab[i, rhs] > -.eps) tab[i, rhs] <- 0
    }
  }
  basis[r] <- j
  list(tab = tab, basis = basis)
}
