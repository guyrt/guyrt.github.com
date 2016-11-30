data {
  int<lower=0> N; // number of points
  int<lower=0> S; // number of sectors
  vector[N] vti; // outcome, full market
  matrix[N, S] sectors; // explanatory
}
parameters {
  matrix[N, S] beta; // sector weights
  vector[N] alpha;
  real<lower=0> sigma;
  
  real alpha1;
  real<lower=0> sigma1;
  
  real alpha2;
  real<lower=0> sigma2;
}
model {
  beta[0, :] ~ normal(1, 2.5);
  alpha[0] ~ normal(0, 1);
  for (n in 2:N) {
    beta[n, :] ~ normal(alpha1 * beta[n-1, :], sigma1);
    alpha[n] ~ normal(alpha2 * alpha[n-1], sigma2);
    
    vti[n] ~ normal(alpha[n] + sectors[n, :] * beta[n, :]', sigma);
  }
}
