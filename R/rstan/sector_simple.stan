data {
  int<lower=0> N; // number of points
  int<lower=0> S; // number of sectors
  vector[N] vti; // outcome, full market
  matrix[N, S] sectors; // explanatory
}
parameters {
  vector[S] beta; // sector weights
  real alpha; // intercept
  real<lower=0> sigma;
}
model {
  for (n in 2:N) {
    sigma ~ cauchy(0, 2.5);
    alpha ~ cauchy(0, 2.5);
    vti[n] ~ normal(alpha + sectors[n, :] * beta, sigma);
  }
}
