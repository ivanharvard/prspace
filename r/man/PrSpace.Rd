\name{PrSpace}
\alias{PrSpace}
\title{Create a probability space}
\description{
A \code{PrSpace} stores probabilities of conditions built from \code{\link{Event}}s.
Assign with \code{Pr[X == 0] <- p} (or \code{=}) and read back with \code{Pr[X == 0]}.

Complements are derived: after \code{Pr[X == 0] <- 0.25}, \code{Pr[X != 0]} is 0.75.
Assigning a condition replaces any stored value for its complement.
Remove a value with \code{Pr[X == 0] <- NULL}.
Reading a condition that was never assigned (directly or through its complement)
signals an error of class \code{prspace_undefined}.

A \code{PrSpace} has reference semantics: modifying it inside a function modifies the caller's copy.
}
\usage{
PrSpace()
}
\value{A \code{prspace_space} object.}
\seealso{\code{\link{Event}}}
\examples{
Pr <- PrSpace()
S_B <- Event()
n_samples <- choose(19, 10)
for (B in c(100, 1000)) {
  Pr[S_B == 0] <- prod(1 - (0:(B - 1) / n_samples))
  Pr[S_B >= 1] <- 1 - Pr[S_B == 0]
  cat("B =", B, "  Pr[S_B == 0] =", Pr[S_B == 0], "  Pr[S_B >= 1] =", Pr[S_B >= 1], "\n")
}
Pr
Pr[S_B != 0]
}
