\name{Jaatha.defaultSumStats}
\alias{Jaatha.defaultSumStats}
\title{These are the default summary statistics for Jaatha}
\usage{
  Jaatha.defaultSumStats(dm = NULL, jsfs)
}
\arguments{
  \item{jsfs}{The joint site frequency spectrum of two
  populations}

  \item{dm}{The corresponding demographic model. Not needed
  at the moment.}
}
\value{
  A vector with sums over different areas of the JSFS
}
\description{
  These are the default summary statistics for Jaatha
}
\examples{
jsfs <- matrix(rpois(26*26,5),26,26)
Jaatha.defaultSumStats(jsfs = jsfs)
}

