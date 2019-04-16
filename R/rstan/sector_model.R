setwd("~/GitHub/guyrt.github.com/R/rstan")

library(rstan)
library(readr)
library(dplyr)
library(tidyr)
library(lubridate)
library(ggplot2)

rstan_options(auto_write=TRUE)
options(mc.cores=parallel::detectCores())

sector_dat <- read_csv("data/sectors.csv")

sector_for_plot <- sector_dat %>% gather(Symbol, Price, -Date)
ggplot(sector_for_plot, aes(x=Date, y=Price, colour=Symbol)) + geom_point(alpha=.3)

first_day_per_period <- sector_dat %>% mutate(payperiod=floor_date(Date, '15 days')) %>% 
  filter(day(payperiod) < 30) %>%
  group_by(payperiod) %>% summarise(firstDate=min(Date)) %>% select(firstDate)


biweekly_sector <- sector_dat %>% semi_join(first_day_per_period, by=c('Date' = 'firstDate'))

# compute lag
biweekly_returns <- biweekly_sector %>% select(-Date)
biweekly_returns <- (tail(biweekly_returns, -1) - head(biweekly_returns, -1)) / head(biweekly_returns, -1)
biweekly_returns$Date <- tail(biweekly_sector$Date, -1)

head(biweekly_returns)
head(biweekly_sector)

sector_dat_stan <- list(
  N=nrow(biweekly_returns),
  S=10,
  vti=c(biweekly_returns$VTI),
  sectors=biweekly_returns[,1:10]
)

fit <- stan(file='sector_simple.stan', data=sector_dat_stan, iter=1000, chains = 4)
la <- extract(fit, permuted = TRUE)
stan_trace(fit, pars=c('beta'))
stan_hist(fit, bins=100, pars = c('alpha', 'beta'))

pairs(fit, pars = c('beta'))

# full model
full_fit <- stan(file='sector_ma.stan', data=sector_dat_stan, iter=2000, chains = 4)
print(full_fit)
full_la <- extract(full_fit, permuted = TRUE)
stan_trace(full_fit, pars=c('alpha'))
stan_hist(full_fit, pars = c('alpha'))

vaw_beta = full_la$beta[,,1]

mean_beta <- as.data.frame(colMeans(full_la$beta, dims=1))
names(mean_beta) <- names(sector_dat)[2:11]
mean_beta$Date <- biweekly_returns$Date
head(mean_beta)

for_plot <- mean_beta %>% gather(key=Date)
names(for_plot) <- c("Date", "Symbol", "beta")

ggplot(for_plot, aes(x=Date, y=beta, colour=Symbol)) + geom_point()

ggplot(biweekly_returns, aes(x=Date, y=VTI)) + geom_point()
