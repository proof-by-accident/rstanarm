#include "license.stan"

# GLM for a Gaussian, Gamma, or inverse Gaussian outcome
functions {
  #include "common_functions.stan"

  /** 
   * Apply inverse link function to linear predictor
   *
   * @param eta Linear predictor vector
   * @param link An integer indicating the link function
   * @return A vector, i.e. inverse-link(eta)
   */
  vector linkinv_gauss(vector eta, int link) {
    if (link < 1 || link > 3) reject("Invalid link");
    if (link < 3)  # link = identity or log 
      return eta; # return eta for log link too bc will use lognormal
    else {# link = inverse
      vector[rows(eta)] mu;
      for(n in 1:rows(eta)) mu[n] = inv(eta[n]); 
      return mu;
    }
  }
  
  /** 
  * Apply inverse link function to linear predictor
  *
  * @param eta Linear predictor vector
  * @param link An integer indicating the link function
  * @return A vector, i.e. inverse-link(eta)
  */
  vector linkinv_gamma(vector eta, int link) {
    if (link < 1 || link > 3) reject("Invalid link");
    if (link == 1)  return eta;
    else if (link == 2) return exp(eta);
    else {
      vector[rows(eta)] mu;
      for(n in 1:rows(eta)) mu[n] = inv(eta[n]); 
      return mu;
    }
  }
  
  /** 
  * Apply inverse link function to linear predictor
  *
  * @param eta Linear predictor vector
  * @param link An integer indicating the link function
  * @return A vector, i.e. inverse-link(eta)
  */
  vector linkinv_inv_gaussian(vector eta, int link) {
    if (link < 1 || link > 4) reject("Invalid link");
    if (link == 1)  return eta;
    else if (link == 2) return exp(eta);
    else {
      vector[rows(eta)] mu;
      if (link == 3) for( n in 1:rows(eta)) mu[n] = inv(eta[n]);
      else for (n in 1:rows(eta)) mu[n] = inv_sqrt(eta[n]);      
      return mu;
    }
  }
  
  /** 
  * Apply inverse link function to linear predictor
  *
  * @param eta Linear predictor vector
  * @param link An integer indicating the link function
  * @return A vector, i.e. inverse-link(eta)
  */
  vector linkinv_beta(vector eta, int link) {
    vector[rows(eta)] mu;
    if (link < 1 || link > 6) reject("Invalid link");
    if (link == 1)  // logit
      for(n in 1:rows(eta)) mu[n] = inv_logit(eta[n]);
    else if (link == 2)  // probit
      for(n in 1:rows(eta)) mu[n] = Phi(eta[n]);
    else if (link == 3)  // cloglog
      for(n in 1:rows(eta)) mu[n] = inv_cloglog(eta[n]);
    else if (link == 4) // cauchy
      for(n in 1:rows(eta)) mu[n] = cauchy_cdf(eta[n], 0.0, 1.0);
    else if (link == 5)  // log 
      for(n in 1:rows(eta)) mu[n] = exp(eta[n]);
    else if (link == 6) // loglog
      for(n in 1:rows(eta)) mu[n] = 1-inv_cloglog(eta[n]);
    return mu;
  }
  
    /** 
  * Apply inverse link function to linear predictor for dispersion (beta regression)
  *
  * @param eta Linear predictor vector
  * @param link An integer indicating the link function
  * @return A vector, i.e. inverse-link(eta)
  */
  vector linkinv_beta_z(vector eta, int link) {
    vector[rows(eta)] mu;
    if (link < 1 || link > 3) reject("Invalid link");
    if (link == 1)        // log
      for(n in 1:rows(eta)) mu[n] = exp(eta[n]);
    else if (link == 2)   // identity
      return eta;
    else if (link == 3)   // sqrt
      for(n in 1:rows(eta)) mu[n] = square(eta[n]);
    return mu;
  }
  
  /** 
  * Pointwise (pw) log-likelihood vector
  *
  * @param y The integer array corresponding to the outcome variable.
  * @param link An integer indicating the link function
  * @return A vector
  */
  vector pw_gauss(vector y, vector eta, real sigma, int link) {
    vector[rows(eta)] ll;
    if (link < 1 || link > 3) reject("Invalid link");
    if (link == 2) # link = log
      for (n in 1:rows(eta)) ll[n] = lognormal_lpdf(y[n] | eta[n], sigma);
    else { # link = idenity or inverse
      vector[rows(eta)] mu;
      mu = linkinv_gauss(eta, link);
      for (n in 1:rows(eta)) ll[n] = normal_lpdf(y[n] | mu[n], sigma);
    }
    return ll;
  }
  
  real GammaReg(vector y, vector eta, real shape, 
                int link, real sum_log_y) {
    real ret;
    if (link < 1 || link > 3) reject("Invalid link");
    ret = rows(y) * (shape * log(shape) - lgamma(shape)) +
      (shape - 1) * sum_log_y;
    if (link == 2)      # link is log
      ret = ret - shape * sum(eta) - shape * sum(y ./ exp(eta));
    else if (link == 1) # link is identity
      ret = ret - shape * sum(log(eta)) - shape * sum(y ./ eta);
    else                # link is inverse
      ret = ret + shape * sum(log(eta)) - shape * dot_product(eta, y);
    return ret;
  }
  
  /** 
  * Pointwise (pw) log-likelihood vector
  *
  * @param y The integer array corresponding to the outcome variable.
  * @param link An integer indicating the link function
  * @return A vector
  */
  vector pw_gamma(vector y, vector eta, real shape, int link) {
    vector[rows(eta)] ll;
    if (link < 1 || link > 3) reject("Invalid link");
    if (link == 3) { # link = inverse
      for (n in 1:rows(eta)) {
        ll[n] = gamma_lpdf(y[n] | shape, shape * eta[n]);
      }
    }
    else if (link == 2) { # link = log
      for (n in 1:rows(eta)) {
        ll[n] = gamma_lpdf(y[n] | shape, shape / exp(eta[n]));
      }
    }
    else { # link = identity
      for (n in 1:rows(eta)) {
        ll[n] = gamma_lpdf(y[n] | shape, shape / eta[n]);
      }
    }
    return ll;
  }
  
  /** 
  * inverse Gaussian log-PDF (for data only, excludes constants)
  *
  * @param y The vector of outcomes
  * @param eta The vector of linear predictors
  * @param lambda A positive scalar nuisance parameter
  * @param link An integer indicating the link function
  * @return A scalar
  */
  real inv_gaussian(vector y, vector mu, real lambda, 
                    real sum_log_y, vector sqrt_y) {
    return 0.5 * rows(y) * log(lambda / (2 * pi())) - 
      1.5 * sum_log_y - 
      0.5 * lambda * dot_self( (y - mu) ./ (mu .* sqrt_y) );
  }
  
  /** 
  * Pointwise (pw) log-likelihood vector
  *
  * @param y The integer array corresponding to the outcome variable.
  * @param eta The linear predictors
  * @param lamba A positive scalar nuisance parameter
  * @param link An integer indicating the link function
  * @param log_y A precalculated vector of the log of y
  * @param sqrt_y A precalculated vector of the square root of y
  * @return A vector of log-likelihoods
  */
  vector pw_inv_gaussian(vector y, vector eta, real lambda, 
                         int link, vector log_y, vector sqrt_y) {
    vector[rows(y)] ll;
    vector[rows(y)] mu;
    if (link < 1 || link > 4) reject("Invalid link");
    mu = linkinv_inv_gaussian(eta, link);
    for (n in 1:rows(y))
      ll[n] = -0.5 * lambda * square( (y[n] - mu[n]) / (mu[n] * sqrt_y[n]) );
    ll = ll + 0.5 * log(lambda / (2 * pi())) - 1.5 * log_y;
    return ll;
  }
  
  vector pw_beta(vector y, vector eta, real dispersion, int link) {
    vector[rows(y)] ll;
    vector[rows(y)] mu;
    vector[rows(y)] shape1;
    vector[rows(y)] shape2;
    if (link < 1 || link > 6) reject("Invalid link");
    mu = linkinv_beta(eta, link);
    shape1 = mu * dispersion;
    shape2 = (1 - mu) * dispersion;
    for (n in 1:rows(y)) {
      ll[n] = beta_lpdf(y[n] | shape1[n], shape2[n]);
    }
    return ll;
  }

  
  vector pw_beta_z(vector y, vector eta, vector eta_z, int link, int link_phi) {
    vector[rows(y)] ll;
    vector[rows(y)] mu;
    vector[rows(y)] mu_z;
    if (link < 1 || link > 6) reject("Invalid link");
    if (link_phi < 1 || link_phi > 3) reject("Invalid link");
    mu = linkinv_beta(eta, link);
    mu_z = linkinv_beta_z(eta_z, link_phi);
    for (n in 1:rows(y)) {
      ll[n] = beta_lpdf(y[n] | mu[n] * mu_z[n], (1-mu[n]) * mu_z[n]);
    }
    return ll;
  }
  
  /** 
  * PRNG for the inverse Gaussian distribution
  *
  * Algorithm from wikipedia 
  *
  * @param mu The expectation
  * @param lambda The dispersion
  * @return A draw from the inverse Gaussian distribution
  */
  real inv_gaussian_rng(real mu, real lambda) {
    real z;
    real y;
    real x;
    real mu2;
    mu2 = square(mu);
    y = square(normal_rng(0,1));
    z = uniform_rng(0,1);
    x = mu + ( mu2 * y - mu * sqrt(4 * mu * lambda * y + mu2 * square(y)) )
      / (2 * lambda);
    if (z <= (mu / (mu + x))) return x;
    else return mu2 / x;
  }

  /** 
  * test function for csr_matrix_times_vector
  *
  * @param m Integer number of rows
  * @param n Integer number of columns
  * @param w Vector (see reference manual)
  * @param v Integer array (see reference manual)
  * @param u Integer array (see reference manual)
  * @param b Vector that is multiplied from the left by the CSR matrix
  * @return A vector that is the product of the CSR matrix and b
  */
  vector test_csr_matrix_times_vector(int m, int n, vector w, 
                                      int[] v, int[] u, vector b) {
    return csr_matrix_times_vector(m, n, w, v, u, b); 
  }
  
}
data {
  #include "NKX.stan"
  vector[N] y; // continuous outcome
  #include "data_glm.stan"
  #include "weights_offset.stan"
  #include "hyperparameters.stan"
  #include "glmer_stuff.stan"
  #include "glmer_stuff2.stan"
  int<lower=0, upper=1> has_intercept_z;  // presence of z intercept
  int<lower=0> link_phi;                  // link transformation for eta_z (0 => no z in model)
  int<lower=0> z_dim;                     // dimensions of z vars
  matrix[N, z_dim] betareg_z;             // matrix of z vars
  row_vector[z_dim] zbar;                 // mean of predictors
  int<lower=0,upper=4> prior_dist_z;      // betareg hyperparameters follow
  int<lower=0,upper=2> prior_dist_for_intercept_z;
  vector<lower=0>[z_dim] prior_scale_z;
  real<lower=0> prior_scale_for_intercept_z;
  vector[z_dim] prior_mean_z;
  real prior_mean_for_intercept_z;
  vector<lower=0>[z_dim] prior_df_z;
  real<lower=0> prior_df_for_intercept_z;
}
transformed data {
  vector[N * (family == 3)] sqrt_y;
  vector[N * (family == 3)] log_y;
  real sum_log_y;
  #include "tdata_glm.stan"
  if      (family == 1) sum_log_y = not_a_number();
  else if (family == 2) sum_log_y = sum(log(y));
  else if (family == 3) {
    for (n in 1:N) sqrt_y[n] = sqrt(y[n]);
    log_y = log(y);
    sum_log_y = sum(log_y);
  }
  else if (family == 4) {
    // do nothing
  }
  else reject("unknown family");
}
parameters {
  real<lower=((family == 1 || link == 2) || (family) ? negative_infinity() : 0.0),
       upper=((family == 4 && link == 5) ? 0.0 : positive_infinity())> gamma[has_intercept];
  #include "parameters_glm.stan"
  real<lower=0> dispersion_unscaled; # interpretation depends on family!
  vector[z_dim] omega;              // betareg parameters
  real gamma_z[has_intercept_z];   // betareg intercept
}
transformed parameters {
  real dispersion;
  #include "tparameters_glm.stan"
  if (prior_scale_for_dispersion > 0)
    dispersion =  prior_scale_for_dispersion * dispersion_unscaled; 
  else dispersion = dispersion_unscaled; 
  if (t > 0) {
    theta_L = make_theta_L(len_theta_L, p, 
                            dispersion, tau, scale, zeta, rho, z_T);
    b = make_b(z_b, theta_L, p, l);
  }
}
model {
  vector[N] eta_z; // beta regression dispersion (linear) predictor
  #include "make_eta.stan"
  if (t > 0) eta = eta + csr_matrix_times_vector(N, q, w, v, u, b);
  if (has_intercept == 1) {
    if ((family == 1 || link == 2) || (family == 4 && link != 5)) eta = eta + gamma[1];
    else if (family == 4 && link == 5) eta = eta - max(eta) + gamma[1];
    else eta = eta - min(eta) + gamma[1];
  }
  else {
    #include "eta_no_intercept.stan"
  }
  // make eta_z
  if (family == 4 && z_dim > 0 && link_phi > 0) {
    eta_z = betareg_z * omega;
  }
  else if (family == 4 && z_dim == 0 && has_intercept_z == 1){
    eta_z = rep_vector(0.0, N); 
  }
  // adjust eta_z according to links
  if (has_intercept_z == 1) {
    if (link_phi > 1) {
      eta_z = eta_z - min(eta_z) + gamma_z[1];
    }
    else {
      eta_z = eta_z + gamma_z[1];
    }
  }
  else { // has_intercept_z == 0
    if (link_phi > 1) {
      eta_z = eta_z - min(eta_z) + dot_product(zbar, omega);
    }
    else {
      eta_z = eta_z + dot_product(zbar, omega);
    }
  }

  // Log-likelihood 
  if (has_weights == 0 && prior_PD == 0) { # unweighted log-likelihoods
    if (family == 1) {
      if (link == 1)      target += normal_lpdf(y | eta, dispersion);
      else if (link == 2) target += lognormal_lpdf(y | eta, dispersion);
      else target += normal_lpdf(y | divide_real_by_vector(1, eta), dispersion);
      // divide_real_by_vector() is defined in common_functions.stan
    }
    else if (family == 2) {
      target += GammaReg(y, eta, dispersion, link, sum_log_y);
    }
    else if (family == 3) {
      target += inv_gaussian(y, linkinv_inv_gaussian(eta, link), 
                             dispersion, sum_log_y, sqrt_y);
    }
    else if (family == 4 && link_phi == 0) {
      vector[N] mu;
      mu = linkinv_beta(eta, link);
      target += beta_lpdf(y | mu * dispersion, (1 - mu) * dispersion);
    }
    else if (family == 4 && link_phi > 0) {
      vector[N] mu;
      vector[N] mu_z;
      mu = linkinv_beta(eta, link);
      mu_z = linkinv_beta_z(eta_z, link_phi);
      target += beta_lpdf(y | rows_dot_product(mu, mu_z), rows_dot_product((1 - mu) , mu_z));
    }
  }
  else if (prior_PD == 0) { # weighted log-likelihoods
    vector[N] summands;
    if (family == 1) summands = pw_gauss(y, eta, dispersion, link);
    else if (family == 2) summands = pw_gamma(y, eta, dispersion, link);
    else if (family == 3) summands = pw_inv_gaussian(y, eta, dispersion, link, log_y, sqrt_y);
    else if (family == 4 && link_phi == 0) summands = pw_beta(y, eta, dispersion, link);
    else if (family == 4 && link_phi > 0) summands = pw_beta_z(y, eta, eta_z, link, link_phi);
    target += dot_product(weights, summands);
  }
  // priors on omega and gamma_z for betareg
  if (family == 4 && link_phi > 0) {
    if (has_intercept_z == 1) {
      if (prior_dist_for_intercept_z == 1)        // normal
        target += normal_lpdf(gamma_z[1] | prior_mean_for_intercept_z, prior_scale_for_intercept_z);
      else if (prior_dist_for_intercept_z == 2)   // student_t (cauchy if prior_df_z = 1)
        target += student_t_lpdf(gamma_z[1] | prior_df_for_intercept_z, prior_mean_for_intercept_z, 
                                 prior_scale_for_intercept_z);
    }
    if (prior_dist_z == 1) {                    // normal
      target += normal_lpdf(omega | prior_mean_z, prior_scale_z);
    }
    else if (prior_dist_z == 2) {               // student_t (cauchy if prior_df_z = 1)
      target += student_t_lpdf(omega | prior_df_z, prior_mean_z, prior_scale_z);
    }
  }

  // Log-prior for scale
  if (prior_scale_for_dispersion > 0) 
    target += cauchy_lpdf(dispersion_unscaled | 0, 1);
  #include "priors_glm.stan"
  if (t > 0) decov_lp(z_b, z_T, rho, zeta, tau, 
                      regularization, delta, shape, t, p);
}
generated quantities {
  real alpha[has_intercept];
  real omega_int[has_intercept_z];
  real mean_PPD;
  vector[N] eta_z;
  mean_PPD = 0;
  // adjust betareg intercept 
  if (has_intercept_z == 1) {
    omega_int[1] = gamma_z[1] - dot_product(zbar, omega);
  }
  // make eta_z
  if (family == 4 && z_dim > 0 && link_phi > 0) {
    eta_z = betareg_z * omega;
  }
  else if (family == 4 && z_dim == 0 && has_intercept_z == 1){
    eta_z = rep_vector(0.0, N); 
  }
  // adjust eta_z according to links
  if (has_intercept_z == 1) {
    if (link_phi > 1) {
      omega_int[1] = omega_int[1] - min(eta_z);
      eta_z = eta_z - min(eta_z) + gamma_z[1];
    }
    else {
      eta_z = eta_z + gamma_z[1];
    }
  }
  else { // has_intercept_z == 0
    if (link_phi > 1) {
      eta_z = eta_z - min(eta_z) + dot_product(zbar, omega);
    }
    else {
      eta_z = eta_z + dot_product(zbar, omega);
    }
  }
  if (has_intercept == 1)
    if (dense_X) alpha[1] = gamma[1] - dot_product(xbar, beta);
    else alpha[1] = gamma[1];
  {
    #include "make_eta.stan"
    if (t > 0) eta = eta + csr_matrix_times_vector(N, q, w, v, u, b);
    if (has_intercept == 1) {
      if ((family == 1 || link == 2) || (family == 4 && link != 5)) eta = eta + gamma[1];
      else if (family == 4 && link == 5) {
        real max_eta;
        max_eta = max(eta);
        alpha[1] = alpha[1] + max_eta;
        eta = eta - max_eta + gamma[1];
      }
      else {
        real min_eta;
        min_eta = min(eta);
        alpha[1] = alpha[1] - min_eta;
        eta = eta - min_eta + gamma[1];
      }
    }
    else {
      #include "eta_no_intercept.stan"
    }
    
    if (family == 1) {
      if (link > 1) eta = linkinv_gauss(eta, link);
      for (n in 1:N) mean_PPD = mean_PPD + normal_rng(eta[n], dispersion);
    }
    else if (family == 2) {
      if (link > 1) eta = linkinv_gamma(eta, link);
      for (n in 1:N) mean_PPD = mean_PPD + gamma_rng(dispersion, dispersion / eta[n]);
    }
    else if (family == 3) {
      if (link > 1) eta = linkinv_inv_gaussian(eta, link);
      for (n in 1:N) mean_PPD = mean_PPD + inv_gaussian_rng(eta[n], dispersion);
    }
    else if (family == 4 && link_phi == 0) { 
      eta = linkinv_beta(eta, link);
      for (n in 1:N) 
        mean_PPD = mean_PPD + beta_rng(eta[n] * dispersion, (1 - eta[n]) * dispersion);
    }
    else if (family == 4 && link_phi > 0) {
      eta = linkinv_beta(eta, link);
      eta_z = linkinv_beta_z(eta_z, link_phi);
      for (n in 1:N) 
        mean_PPD = mean_PPD + beta_rng(eta[n] * eta_z[n], (1 - eta[n]) * eta_z[n]);
    }
    mean_PPD = mean_PPD / N;
  }
}
