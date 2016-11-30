data {
  int<lower=0> N; // number of points
  int<lower=0> S; // number of sectors
  vector[N] vti; // outcome, full market
  matrix[N, S] sectors; // explanatory
}
parameters {
  matrix[N, S] beta; // sector weights
  real alpha; // intercept
  real<lower=0> sigma;
  
  real alpha1;
  real<lower=0> sigma1;
  
  real alpha2;
  real<lower=0> sigma2;

}
model {
  real vmult;
  
  beta[1, :] ~ normal(1, 2.5);

  for (n in 2:N) {
    beta[n, :] ~ normal(alpha1 * beta[n-1, :], sigma1);

    // vector mult
    vmult = 0;
    for (k in 1:S) {
      vmult = vmult + sectors[n, k] * beta[n, k];
    }
    
    vti[n] ~ normal(alpha + vmult, sigma);
  }
}
