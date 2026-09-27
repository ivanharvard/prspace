# Core objects: PrSpace, Event, and the condition you get by comparing an Event.
# Keep behaviour in sync with python/src/prspace/_core.py.

.state <- new.env(parent = emptyenv())
.state$next_id <- 0L

# The complement of each comparison, e.g. !(X == 0) is (X != 0).
.negate <- c("==" = "!=", "!=" = "==", "<" = ">=", ">=" = "<", ">" = "<=", "<=" = ">")
# `0 < X` is `X > 0`.
.flip <- c("==" = "==", "!=" = "!=", "<" = ">", ">=" = "<=", ">" = "<", "<=" = ">=")
.check_modes <- c("off", "warn", "error")

# ---- Event -------------------------------------------------------------------

Event <- function(name = NULL, support = NULL) {
  if (!is.null(name) && !(is.character(name) && length(name) == 1L && !is.na(name))) {
    stop("`name` must be a single string", call. = FALSE)
  }
  support <- as_support(support)
  .state$next_id <- .state$next_id + 1L
  event <- new.env(parent = emptyenv())
  event$id <- .state$next_id
  event$name <- name
  event$support <- support
  class(event) <- "prspace_event"
  event
}

event_label <- function(event) {
  if (is.null(event$name)) paste0("E", event$id) else event$name
}

Ops.prspace_event <- function(e1, e2) {
  op <- .Generic
  if (missing(e2) || !op %in% names(.negate)) {
    stop(sprintf("`%s` is not supported on an Event; compare it instead, e.g. X == 0", op), call. = FALSE)
  }
  if (inherits(e1, "prspace_event") && inherits(e2, "prspace_event")) {
    stop("comparing two Events is not supported yet", call. = FALSE)
  }
  if (inherits(e1, "prspace_event")) {
    event <- e1
    value <- e2
  } else {
    event <- e2
    value <- e1
    op <- .flip[[op]]
  }
  if (!(is.atomic(value) && length(value) == 1L && !is.na(value))) {
    stop("an Event can only be compared with a single value", call. = FALSE)
  }
  if (is.null(event$name)) {
    event$name <- infer_name(event, parent.frame())
  }
  support_check_value(event$support, op, value, event_label(event))
  new_condition(event, op, value)
}

infer_name <- function(event, env) {
  for (scope in unique(list(env, globalenv()))) {
    for (name in ls(scope, all.names = TRUE)) {
      value <- tryCatch(get(name, envir = scope, inherits = FALSE), error = function(e) NULL)
      if (identical(value, event)) return(name)
    }
  }
  NULL
}

print.prspace_event <- function(x, ...) {
  cat("<Event ", event_label(x), ", support: ", format(x$support), ">\n", sep = "")
  invisible(x)
}

# ---- Condition ---------------------------------------------------------------

new_condition <- function(event, op, value) {
  structure(list(event = event, op = op, value = value), class = "prspace_condition")
}

condition_key <- function(cond) {
  value <- cond$value
  value <- if (is.numeric(value)) sprintf("n:%.17g", as.double(value)) else paste0(typeof(value), ":", value)
  paste(cond$event$id, cond$op, value, sep = "\r")
}

format.prspace_condition <- function(x, ...) {
  value <- x$value
  value <- if (is.character(value)) encodeString(value, quote = "\"") else format(value)
  paste(event_label(x$event), x$op, value)
}

print.prspace_condition <- function(x, ...) {
  cat("<Condition ", format(x), ">\n", sep = "")
  invisible(x)
}

Ops.prspace_condition <- function(e1, e2) {
  if (.Generic == "!" && missing(e2)) {
    return(new_condition(e1$event, .negate[[e1$op]], e1$value))
  }
  stop(sprintf("`%s` is not supported on conditions yet", .Generic), call. = FALSE)
}

# Which atoms of the Event's support each condition covers, over one shared set of atoms.
indicators <- function(conds) {
  reps <- support_atoms(conds[[1]]$event$support, lapply(conds, `[[`, "value"))
  lapply(conds, function(cond) as.vector(match.fun(cond$op)(reps, cond$value)))
}

complementary <- function(v, q) all(v != q)

# ---- PrSpace -----------------------------------------------------------------

PrSpace <- function(check = "warn", derive = TRUE) {
  if (!(is.character(check) && length(check) == 1L && check %in% .check_modes)) {
    stop('`check` must be one of "off", "warn", "error"', call. = FALSE)
  }
  if (!(isTRUE(derive) || isFALSE(derive))) {
    stop("`derive` must be TRUE or FALSE", call. = FALSE)
  }
  space <- new.env(parent = emptyenv())
  space$check <- check
  space$derive <- derive
  space$store <- list()
  class(space) <- "prspace_space"
  space
}

as_condition <- function(i) {
  if (inherits(i, "prspace_condition")) return(i)
  if (inherits(i, "prspace_event")) {
    stop(sprintf("index a PrSpace with a condition such as Pr[%s == 0], not a bare Event",
                 event_label(i)), call. = FALSE)
  }
  stop("index a PrSpace with a condition such as Pr[X == 0]", call. = FALSE)
}

undefined_probability <- function(cond, lower = NULL, upper = NULL) {
  if (is.null(lower) || is.null(upper) || (lower <= 0 && upper >= 1)) {
    msg <- sprintf("Pr[%s] has not been assigned (nor has its complement Pr[%s])",
                   format(cond), format(!cond))
  } else {
    msg <- sprintf("Pr[%s] is not determined by the probabilities assigned so far; it is between %s and %s",
                   format(cond), format(lower, digits = 7), format(upper, digits = 7))
  }
  structure(class = c("prspace_undefined", "error", "condition"),
            list(message = msg, call = NULL, condition = cond, lower = lower, upper = upper))
}

inconsistent_probability <- function(msg, type = "error") {
  structure(class = c("prspace_inconsistent", type, "condition"), list(message = msg, call = NULL))
}

# Stored rows on the condition's Event, their indicators, and the condition's indicator.
space_rows <- function(space, cond) {
  rows <- Filter(function(row) identical(row$condition$event, cond$event), space$store)
  vecs <- indicators(c(list(cond), lapply(rows, `[[`, "condition")))
  list(rows = rows, vecs = vecs[-1], q = vecs[[1]])
}

bounds_given <- function(rows, vecs, q) {
  A <- rbind(rep(1, length(q)), do.call(rbind, vecs)) * 1
  lp_bounds(A, c(1, vapply(rows, `[[`, numeric(1), "p")), q * 1)
}

# Why assigning Pr[cond] = p contradicts the other stored rows, or NULL if it doesn't.
inconsistency <- function(cond, p, q, rows, vecs) {
  b <- bounds_given(rows, vecs, q)
  label <- event_label(cond$event)
  if (is.null(b)) {
    return(sprintf("the probabilities already assigned to %s are inconsistent", label))
  }
  if (p >= b[1] - .eps && p <= b[2] + .eps) return(NULL)
  allowed <- if (b[2] - b[1] <= .eps) format(b[1], digits = 7) else
    sprintf("between %s and %s", format(b[1], digits = 7), format(b[2], digits = 7))
  sprintf("Pr[%s] = %s is inconsistent with the probabilities already assigned to %s; it must be %s",
          format(cond), format(p, digits = 7), label, allowed)
}

`[.prspace_space` <- function(x, i, ...) {
  cond <- as_condition(i)
  r <- space_rows(x, cond)
  for (k in seq_along(r$rows)) if (identical(r$vecs[[k]], r$q)) return(r$rows[[k]]$p)
  for (k in seq_along(r$rows)) if (complementary(r$vecs[[k]], r$q)) return(1 - r$rows[[k]]$p)
  if (!any(r$q)) return(0)
  if (all(r$q)) return(1)
  if (!x$derive) stop(undefined_probability(cond))
  b <- bounds_given(r$rows, r$vecs, r$q)
  if (is.null(b)) {
    stop(inconsistent_probability(sprintf(
      "cannot derive Pr[%s]: the probabilities assigned to %s are inconsistent",
      format(cond), event_label(cond$event))))
  }
  lo <- max(b[1], 0)
  hi <- min(b[2], 1)
  if (hi - lo <= .eps) return(lo)
  stop(undefined_probability(cond, lo, hi))
}

`[<-.prspace_space` <- function(x, i, ..., value) {
  cond <- as_condition(i)
  r <- space_rows(x, cond)
  hit <- vapply(r$vecs, function(v) identical(v, r$q) || complementary(v, r$q), logical(1))
  if (is.null(value)) {
    if (!any(hit)) stop(undefined_probability(cond))
    for (key in names(r$rows)[hit]) x$store[[key]] <- NULL
    return(x)
  }
  if (!(is.numeric(value) && length(value) == 1L)) {
    stop(sprintf("Pr[%s] must be a single number", format(cond)), call. = FALSE)
  }
  if (is.na(value) || value < 0 || value > 1) {
    stop(sprintf("Pr[%s] must be between 0 and 1, got %s", format(cond), format(value)), call. = FALSE)
  }
  value <- as.double(value)
  if (x$check != "off") {
    problem <- inconsistency(cond, value, r$q, r$rows[!hit], r$vecs[!hit])
    if (!is.null(problem)) {
      if (x$check == "error") stop(inconsistent_probability(problem))
      warning(inconsistent_probability(problem, "warning"))
    }
  }
  key <- condition_key(cond)
  for (old in setdiff(names(r$rows)[hit], key)) x$store[[old]] <- NULL
  x$store[[key]] <- list(condition = cond, p = value)
  x
}

length.prspace_space <- function(x) {
  length(x$store)
}

print.prspace_space <- function(x, ...) {
  n <- length(x$store)
  if (n == 0L) {
    cat("PrSpace with no probabilities assigned\n")
  } else {
    cat("PrSpace with ", n, if (n == 1L) " probability:\n" else " probabilities:\n", sep = "")
    for (entry in x$store) {
      cat("  Pr[", format(entry$condition), "] = ", format(entry$p, digits = 7), "\n", sep = "")
    }
  }
  invisible(x)
}
