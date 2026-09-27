\name{PrSpace}
\alias{PrSpace}
\title{Create a probability space}
\description{
A \code{PrSpace} stores probabilities of conditions built from \code{\link{Event}}s.
Assign with \code{Pr[X == 0] <- p} (or \code{=}) and read back with \code{Pr[X == 0]}.
Remove a value with \code{Pr[X == 0] <- NULL}.

Reading a condition returns, in order: the value assigned to it or to any condition describing
the same event; one minus the value assigned to its complement; 0 or 1 if the event's support
makes it impossible or certain; and, with \code{derive = TRUE}, any value the rules of probability
pin down given everything assigned to that event. Otherwise it signals an error of class
\code{prspace_undefined} whose fields \code{lower} and \code{upper} give the range the value is
known to lie in.

Assigning a condition replaces any stored value for the same event or its complement.
With \code{check} on, the new value is compared with the range consistent with the other stored
values, and a violation signals a condition of class \code{prspace_inconsistent}.

A \code{PrSpace} has reference semantics: modifying it inside a function modifies the caller's copy.
}
\usage{
PrSpace(check = "warn", derive = TRUE)
}
\arguments{
  \item{check}{What to do when an assignment is inconsistent with the others:
    \code{"warn"} (store it and warn), \code{"error"} (refuse it), or \code{"off"}.}
  \item{derive}{If \code{TRUE}, derive any value the assigned ones determine. If \code{FALSE},
    only assigned values, their complements, and impossible or certain events are returned.}
}
\value{A \code{prspace_space} object.}
\seealso{\code{\link{Event}}}
\examples{
Pr <- PrSpace()
S_B <- Event(support = "count")
n_samples <- choose(19, 10)
for (B in c(100, 1000)) {
  Pr[S_B == 0] <- prod(1 - (0:(B - 1) / n_samples))
  cat("B =", B, "  Pr[S_B >= 1] =", Pr[S_B >= 1], "\n")
}
Pr

X <- Event(support = c(1, 2, 3))
Pr[X == 1] <- 0.2
Pr[X == 2] <- 0.3
Pr[X == 3]

Y <- Event()
Pr[Y < 3] <- 0.6
tryCatch(Pr[Y < 5] <- 0.4, warning = function(w) conditionMessage(w))
}
