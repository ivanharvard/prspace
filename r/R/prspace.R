# Core objects: PrSpace, Event, and the condition you get by comparing an Event.
# Keep behaviour in sync with python/src/prspace/_core.py.

.state <- new.env(parent = emptyenv())
.state$next_id <- 0L

# The complement of each comparison, e.g. !(X == 0) is (X != 0).
.negate <- c("==" = "!=", "!=" = "==", "<" = ">=", ">=" = "<", ">" = "<=", "<=" = ">")
# `0 < X` is `X > 0`.
.flip <- c("==" = "==", "!=" = "!=", "<" = ">", ">=" = "<=", ">" = "<", "<=" = ">=")

# ---- Event -------------------------------------------------------------------

Event <- function(name = NULL) {
  if (!is.null(name) && !(is.character(name) && length(name) == 1L && !is.na(name))) {
    stop("`name` must be a single string", call. = FALSE)
  }
  .state$next_id <- .state$next_id + 1L
  event <- new.env(parent = emptyenv())
  event$id <- .state$next_id
  event$name <- name
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
  if (!(is.atomic(value) && length(value) == 1L && !is.na(value) &&
        (is.numeric(value) || is.character(value) || is.logical(value)))) {
    stop("an Event can only be compared with a single number, string, or logical", call. = FALSE)
  }
  if (is.null(event$name)) {
    event$name <- infer_name(event, parent.frame())
  }
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
  cat("<Event ", event_label(x), ">\n", sep = "")
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

# ---- PrSpace -----------------------------------------------------------------

PrSpace <- function() {
  space <- new.env(parent = emptyenv())
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

undefined_probability <- function(cond) {
  msg <- sprintf("Pr[%s] has not been assigned (nor has its complement Pr[%s])",
                 format(cond), format(!cond))
  structure(class = c("prspace_undefined", "error", "condition"),
            list(message = msg, call = NULL, condition = cond))
}

`[.prspace_space` <- function(x, i, ...) {
  cond <- as_condition(i)
  store <- x$store
  hit <- store[[condition_key(cond)]]
  if (!is.null(hit)) return(hit$p)
  hit <- store[[condition_key(!cond)]]
  if (!is.null(hit)) return(1 - hit$p)
  stop(undefined_probability(cond))
}

`[<-.prspace_space` <- function(x, i, ..., value) {
  cond <- as_condition(i)
  key <- condition_key(cond)
  complement <- condition_key(!cond)
  if (is.null(value)) {
    if (!is.null(x$store[[key]])) {
      x$store[[key]] <- NULL
    } else if (!is.null(x$store[[complement]])) {
      x$store[[complement]] <- NULL
    } else {
      stop(undefined_probability(cond))
    }
    return(x)
  }
  if (!(is.numeric(value) && length(value) == 1L)) {
    stop(sprintf("Pr[%s] must be a single number", format(cond)), call. = FALSE)
  }
  if (is.na(value) || value < 0 || value > 1) {
    stop(sprintf("Pr[%s] must be between 0 and 1, got %s", format(cond), format(value)), call. = FALSE)
  }
  x$store[[complement]] <- NULL
  x$store[[key]] <- list(condition = cond, p = as.double(value))
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
