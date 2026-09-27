\name{Event}
\alias{Event}
\title{Create an event}
\description{
An \code{Event} is a quantity you make probability statements about.
Comparing it with a single value
(\code{==}, \code{!=}, \code{<}, \code{<=}, \code{>}, \code{>=}) gives a condition
such as \code{S_B == 0}, which is what you index a \code{\link{PrSpace}} with.
\code{!(X == 0)} is the complement \code{X != 0}.

The support says which values the event can take, which lets a \code{PrSpace} derive and
check more. For example, with \code{support = "count"}, \code{S_B >= 1} is the complement of
\code{S_B == 0} and \code{Pr[S_B < 0]} is 0.

If \code{name} is omitted, it is taken from the variable the event is bound to
the first time it is compared, so \code{S_B <- Event()} prints as \code{S_B}.
}
\usage{
Event(name = NULL, support = NULL)
}
\arguments{
  \item{name}{Optional label used when printing, a single string.}
  \item{support}{\code{"real"} (the default when \code{NULL}), \code{"integer"},
    \code{"count"} (0, 1, 2, ...), or a vector of the values the event can take, such as
    \code{c(1, 2, 3)} or \code{c("H", "T")}. Events with string values can only be compared
    with \code{==} and \code{!=}.}
}
\value{A \code{prspace_event} object.}
\seealso{\code{\link{PrSpace}}}
\examples{
X <- Event()
X == 0
!(X < 3)
Event("S_B", support = "count")
Event("Coin", support = c("H", "T"))
}
