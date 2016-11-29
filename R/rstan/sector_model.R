setwd("~/GitHub/guyrt.github.com/R/rstan")

library(rstan)
library(readr)

rstan_options(auto_write=TRUE)
options(mc.cores=parallel::detectCores())

sector_dat <- read_csv("data/sectors.csv")

sector_dat_stan <- list(
  N=nrow(sector_dat),
  vti=c(sector_dat$VTI)
)

fit <- stan(file='sector_ma.stan', data=sector_dat_stan, iter=1000, chains = 4)
stan_trace(fit)
stan_hist(fit, bins=100)
