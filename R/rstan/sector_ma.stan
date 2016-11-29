data {
  int<lower=0> N; // number of points
  vector[N] vti; // outcome, full market
}
parameters {
  real alpha;
  real beta;
  real<lower=0> sigma;
}
model {
  for (n in 2:N)
    vti[n] ~ normal(alpha + beta * vti[n-1], sigma);
}
