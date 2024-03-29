calc_poisson_llh <- function(data, stat, loglambda, 
                             sim = 100, scaling_factor = 1) {

    if(length(loglambda) == 0) print("length(loglambda) == 0  in calc_poisson_llh")
    ## If mean was estimated to be 0, replace it with a small value instead
    ## (assume we would have observed a 1 in the next simulation)
    loglambda[!is.finite(loglambda)] <- log(1 / (sim + 1))
    
    ## Upscale predicted expectation value if we use scaling
    if (scaling_factor != 1) loglambda <- loglambda + log(scaling_factor)
    
    ## Calculate the log-likelihood

    assert_that(are_equal(length(loglambda), length(data$get_values(stat))))
    loglambda[loglambda > 700] <- 700
    llh <- sum(data$get_values(stat) * loglambda - 
               exp(loglambda) - data$get_log_factorial(stat))
    
    assert_that(is.finite(llh) && llh < 0)
    
    llh
}


approximate_llh <- function(x, data, param, glm_fitted, sim, scaling_factor, ...) {
  "approximates the log-likelihood using the fitted glms"
  UseMethod("approximate_llh")
}

#' @export
approximate_llh.default <- function(x, data, param, glm_fitted, sim, scaling_factor, ...) { #nolint 
  stop("Unknown Summary Statistic")
}


#' @export
approximate_llh.jaatha_model <- function(x, data, param, glm_fitted, sim, scaling_factor=NA, ...) {
  assert_that(is_jaatha_data(data))
  assert_that(is.numeric(param))
  assert_that(is.list(glm_fitted))
  if(is.na(scaling_factor)) scaling_factor <- x$get_scaling_factor()
  sum(vapply(x$get_sum_stats(), approximate_llh, numeric(1),
             data, param, glm_fitted, sim, scaling_factor))
}


#' @export
approximate_llh.jaatha_stat_basic  <- function(x, data, param, glm_fitted, #nolint
                                               sim, scaling_factor, ...) {
  
                                        # Calculate the predicted expectation values
    loglambda <- vapply(glm_fitted[[x$get_name()]], function(glm_obj) {
        glm_obj$coefficients %*% c(1, param)
    }, numeric(1))
    if(length(loglambda) == 0) {
        print("length(loglambda) == 0 in approximate_llh.jaatha_stat_basic")
        print(x$get_name())
        print(glm_fitted[[x$get_name()]])
        print(glm_fitted)
        print(glm_fitted[[x$get_name()]]$coefficients)
    }
    assert_that(all(is.finite(loglambda)))
    if(!are_equal(length(loglambda), 
                          length(glm_fitted[[x$get_name()]]))) browser()
    assert_that(are_equal(length(loglambda), 
                          length(glm_fitted[[x$get_name()]])))
    
                                        # Calculate the Poisson log-likelihood
    
    if(length(loglambda) == 0) print("length(loglambda) == 0  in approximate_llh.jaatha_stat_basic")
    
    calc_poisson_llh(data, x, loglambda, sim, scaling_factor)
}


optimize_llh <- function(block, model, data, glms, sim) {
  boundary <- block$get_interior(0.15)
  best_value <- stats::optim(block$get_middle(),
                             function(param) {
                               approximate_llh(model, data, param, glms, sim)
                             },
                             lower = boundary[, 1, drop = FALSE], 
                             upper = boundary[, 2, drop = FALSE],
                             method = "L-BFGS-B", 
                             control = list(fnscale = -1))
  
  assert_that(block$includes(best_value$par))
  best_value
}

estimate_local_ml <- function(block, model, data, sim, cores, sim_cache) {
    for (j in 1:50) {
        sim_data <- model$simulate(pars = block$sample_pars(sim, FALSE), 
                               data = data, 
                               cores = cores)
    # Cache simulation & load older simulations within this block
        sim_cache$add(sim_data)
        sim_data <- sim_cache$get_sim_data(block)
        assert_that(length(sim_data) >= sim)
    # Fit glms and find maximal likelihood value
        glms <- tryCatch(fit_glm(model, sim_data), error = identity)
  
        # Conduct more simulations if the glms did not converge
        if(class(glms)[1] == "simpleError") {
            converged  <- FALSE
        } else {
            converged <-  !(any(vapply(glms, inherits, logical(1), what = "simpleError")))
        }
        
##       if(converged) {
##            if(is.character(unlist(sapply(glms, function(x) x["converged"])))) {
##                browser()
##            } else {
##                if(is.na(all(unlist(sapply(glms, function(x) x["converged"]))))) browser()
##                if(!all(unlist(sapply(glms, function(x) x["converged"])))) {
##                    browser()
##                    stop("in estimate_local_ml: all(converged) is true but not all glms have converged\n")
##                }
##            }
##        }
        
        if (converged) break
    
        if (j %% 5 == 0) sim_cache$clear()
        if (j == 50) stop("GLMs failed to converge") else message("GLM convergence problem, trying again\n")
  }
  
  optimize_llh(block, model, data, glms, length(sim_data))
}


#' Estimate the Log-Likelihood for a given parameter combination
#' 
#' This function estimates the Log-likelihood value for a given
#' parameter combination. It conducts a number of simulations for
#' the parameter combination, averages the summary statistics to
#' esimate their expected values, and uses them to calculate the
#' likelihood. For a resonable number of simulation, this is more
#' accurate than the glm fitting used in the main algorithm.
#' 
#' @inheritParams jaatha
#' @param parameter The parameter combination for which the loglikelihood
#'          will be estimated.
#' @param sim The number of simulations that will be used for averaging the
#'          expectation values of the summary statistics.
#' @param normalized For internal use. Indicates whether the parameter
#'          combination is normalized to [0, 1]-scale, or on its natural
#'          scale.
#' @param sim_data For internal use. Use existing simulations.
#' @export
estimate_llh <- function(model, data, parameter, sim = 100, 
                         cores = 1, normalized = FALSE, sim_data = NULL) {
  
  assert_that(is_jaatha_model(model))
  assert_that(is_jaatha_data(data))
  assert_that(is.numeric(parameter))
  assert_that(is.count(sim))
  assert_that(is.count(cores))
  assert_that(is_single_logical(normalized))
  
  if (is.null(sim_data)) {
    if (!normalized) parameter <- model$get_par_ranges()$normalize(parameter)
    sim_pars <- matrix(parameter, sim, length(parameter), byrow = TRUE)
    sim_data <- model$simulate(sim_pars, data, cores)
  }

  llh <- sum(vapply(names(model$get_sum_stats()), function(stat){
    stat_values <- sapply(sim_data, function(x) x[[stat]])
    if (!is.matrix(stat_values)) stat_values <- matrix(stat_values, nrow = 1)
    log_means <- log(rowMeans(stat_values))
    assert_that(length(log_means) > 0)
    calc_poisson_llh(data, stat, log_means, sim, model$get_scaling_factor())
  }, numeric(1)))

  assert_that(is.finite(llh))
  list(param = parameter, value = llh)
}
