\name{Event}
\alias{Event}
\title{Create an event}
\description{
An \code{Event} is a quantity you make probability statements about.
Comparing it with a single number, string or logical
(\code{==}, \code{!=}, \code{<}, \code{<=}, \code{>}, \code{>=}) gives a condition
such as \code{S_B == 0}, which is what you index a \code{\link{PrSpace}} with.
\code{!(X == 0)} is the complement \code{X != 0}.

If \code{name} is omitted, it is taken from the variable the event is bound to
the first time it is compared, so \code{S_B <- Event()} prints as \code{S_B}.
}
\usage{
Event(name = NULL)
}
\arguments{
  \item{name}{Optional label used when printing, a single string.}
}
\value{A \code{prspace_event} object.}
\seealso{\code{\link{PrSpace}}}
\examples{
X <- Event()
X == 0
!(X < 3)
Event("heads")
}
