setwd("~/GitHub/guyrt.github.com/R/rstan")

library(rstan)
library(readr)
library(dplyr)
library(lubridate)

rstan_options(auto_write=TRUE)
options(mc.cores=parallel::detectCores())
rstan_options(adapt_delta=.9)

sector_dat <- read_csv("data/sectors.csv")

first_day_per_period <- sector_dat %>% mutate(payperiod=floor_date(Date, '15 days')) %>% 
  group_by(payperiod) %>% summarise(firstDate=min(Date)) %>% select(firstDate)


biweekly_sector <- sector_dat %>% semi_join(first_day_per_period, by=c('Date' = 'firstDate'))

# compute lag



sector_dat_stan <- list(
  N=nrow(sector_dat),
  S=10,
  vti=c(sector_dat$VTI),
  sectors=sector_dat[,2:11]
)

fit <- stan(file='sector_simple.stan', data=sector_dat_stan, iter=1000, chains = 4)
stan_trace(fit, pars=c('beta'))
stan_hist(fit, bins=100, pars = c('alpha', 'beta'))

pairs(fit, pars = c('beta'))


# ideas: 
# - filter to first day of every month. 
# - normalize: compute monthly returns?
