# What values an Event can take. Mirrored in python/src/prspace/_support.py.
#
# A support splits into "atoms" given the constants an event is compared with: pieces on
# which every one of those comparisons is either all true or all false. Each atom is
# represented by one value inside it, so a condition's truth on the atom is just the
# comparison applied to that value. Internal for now; users pick one via Event(support = ...).

new_support <- function(kind, low = NULL, values = NULL) {
  structure(list(kind = kind, low = low, values = values), class = "prspace_support")
}

as_support <- function(x) {
  if (inherits(x, "prspace_support")) return(x)
  if (is.null(x)) return(new_support("real"))
  if (is.character(x) && length(x) == 1L) {
    return(switch(x,
      real = new_support("real"),
      count = new_support("integer", low = 0),
      integer = new_support("integer"),
      stop(sprintf('unknown support "%s"; use "real", "integer", "count", or a vector of values', x),
           call. = FALSE)
    ))
  }
  if (!is.atomic(x) || length(x) == 0L) {
    stop('support must be "real", "integer", "count", or a vector of values', call. = FALSE)
  }
  if (!(is.character(x) && !anyNA(x)) && !(is.numeric(x) && all(is.finite(x)))) {
    stop("a finite support must be all finite numbers or all strings", call. = FALSE)
  }
  new_support("finite", values = unique(x))
}

is_number <- function(x) is.numeric(x) && is.finite(x)

support_labels <- function(s) s$kind == "finite" && is.character(s$values)

support_check_value <- function(s, op, value, label) {
  if (!support_labels(s)) {
    if (!is_number(value)) {
      stop(sprintf('%s has support %s, so it can only be compared with finite numbers, not %s; for labels use e.g. Event(support = c("H", "T"))',
                   label, format(s), deparse(value)), call. = FALSE)
    }
    return(invisible())
  }
  if (!is.character(value)) {
    stop(sprintf("%s takes values in %s, so compare it with a string, not %s",
                 label, format(s), deparse(value)), call. = FALSE)
  }
  if (!op %in% c("==", "!=")) {
    stop(sprintf("%s takes unordered labels, so only == and != are supported", label), call. = FALSE)
  }
}

support_atoms <- function(s, values) {
  if (s$kind == "finite") return(s$values)
  values <- as.double(unlist(values))
  if (s$kind == "real") {
    crit <- sort(unique(values))
    if (!length(crit)) return(0)
    reps <- crit[1] - 1
    for (k in seq_len(length(crit) - 1L)) {
      reps <- c(reps, crit[k], (crit[k] + crit[k + 1L]) / 2)
    }
    return(c(reps, crit[length(crit)], crit[length(crit)] + 1))
  }
  low <- s$low
  crit <- sort(unique(c(floor(values), ceiling(values))))
  if (!is.null(low)) crit <- crit[crit >= low]
  if (!length(crit)) return(if (is.null(low)) 0 else low)
  reps <- numeric(0)
  if (is.null(low)) {
    reps <- crit[1] - 1
  } else if (crit[1] > low) {
    reps <- low
  }
  for (k in seq_len(length(crit) - 1L)) {
    reps <- c(reps, crit[k])
    if (crit[k + 1L] - crit[k] >= 2) reps <- c(reps, crit[k] + 1)
  }
  c(reps, crit[length(crit)], crit[length(crit)] + 1)
}

format.prspace_support <- function(x, ...) {
  switch(x$kind,
    real = "real",
    integer = if (identical(x$low, 0)) "count" else "integer",
    finite = {
      values <- if (is.character(x$values)) encodeString(x$values, quote = "\"") else vapply(x$values, format, "")
      paste0("{", paste(values, collapse = ", "), "}")
    }
  )
}
