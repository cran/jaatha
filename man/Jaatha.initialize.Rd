\name{Jaatha.initialize}
\alias{Jaatha.initialize}
\title{Basic initialization of a Jaatha estimation}
\usage{
  Jaatha.initialize(demographic.model, summary.statistics,
    jsfs, folded = FALSE, seed = numeric(), log.level = 1,
    log.file = "", sim.package.size = 10, cores = 1,
    scaling.factor = 1, use.shm = FALSE)
}
\arguments{
  \item{demographic.model}{The demographic model to use}

  \item{summary.statistics}{The summary statistics
  calculated from the real data}

  \item{jsfs}{Instead of summary.statistics, you can also
  input the joint site fequency spectrum of your data.
  Jaatha will then automatically calulate summary
  statistics out of it.}

  \item{folded}{If 'TRUE', Jaatha will assume that the JSFS
  is folded.}

  \item{seed}{An integer used as seed for both Jaatha and
  the simulation software}

  \item{log.level}{An integer from 0 to 3 indicating
  Jaatha's verbosity. 0 is (almost) no output, 1 is normal
  output, and 2 and 3 are some and heavy debug output
  respectively}

  \item{log.file}{If specified, the output will be
  redirected to this file}

  \item{sim.package.size}{When running Jaatha on multiple
  cores, a singe core will always execute a whole "package"
  of simulations the reduce the inter thread communication
  overhead. This gives the number of simulations in such a
  package. Choose a number such that the execution of the
  simulations takes at least 15 seconds.}

  \item{cores}{The number of cores to use in parallel. If
  0, it tries to guess the number of available cores and
  use them all.}

  \item{scaling.factor}{You can use this option if you have
  a large dataset. If so, Jaatha only simulates only a
  fraction 1/scaling.factor of the dataset and interpolates
  the missing data.}

  \item{use.shm}{Logical. Many modern linux distributions
  have a shared memory ramdisk available under /dev/shm.
  Set this to TRUE to use it for temporary files. Usually
  gives a huge performance boost.}
}
\value{
  A S4-Object of type jaatha containing the settings
}
\description{
  This function sets the basic parameters for an analysis
  with Jaatha and is the first step for each application of
  it.
}

