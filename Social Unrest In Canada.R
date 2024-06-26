#---- Setup --------------------------------------------------------------------
setwd("C:/Users/amrit/Desktop/A-Files/Social Unrest In Canada")

set.seed(141047)

#Colors
BLUE <- "#076fa2"
RED <- "#E3120B"
BLACK <- "#202020"
GREY <- "grey50"

#Libraries
library(knitr)
library(grid)
library(tidyverse)
library(shadowtext)
library(extrafont)
library(car)
library(MASS)
library(pscl)
library(boot)

library(dplyr)
library(tidyr)
library(purrr)
library(forecast)



# ---- Loading Dataset----------------------------------------------------------
data = read.csv("canadianProtestData.csv")
head(data, n = 40) # Showing first few lines of the data

# Telling R,provinces, months and years are factors
data$prov <- as.factor(data$prov)
data$month <- as.factor(data$month)
data$year <- as.factor(data$year )

#Looking at the data and Summary
print(paste("This dataset has", nrow(data), "entries"))



#----Visualizing Data ----------------------------------------------------------
# Number of Protests in each province 

protests_by_province <- data.frame(matrix(0, ncol = 2, nrow = 13)) 

names(protests_by_province) <- c("Province", "Protests")
protests_by_province$Province <- data$prov[1:13] 

for (i in 1:13){
  indicies <- which(data$prov == data$prov[i])
  for (j in indicies){
    protests_by_province[i,2] <- protests_by_province[i,2] + data$protests[j]
  }
}


# Making the Bar Chart ( I am going a bit more fancy here :) )
protests_by_province[,1] <- factor(
  protests_by_province[,1], 
  levels = protests_by_province[,1][order(protests_by_province[,2])])

# This is where I got the way of making the graph
# https://r-graph-gallery.com/web-horizontal-barplot-with-labels-the-economist.html

plot_1 <- ggplot(protests_by_province) + 
  geom_col(aes(Protests, Province), fill = BLUE, width = 0.6) +
  scale_x_continuous(
    limits = c(0, 1250),
    breaks = seq(0, 1250, by = 100), 
    expand = c(0, 0), 
    position = "top"
  ) +
  scale_y_discrete(expand = expansion(add = c(0, 0.5))) +
  theme(
    panel.background = element_rect(fill = "white"),
    panel.grid.major.x = element_line(color = "#A8BAC4", linewidth = 0.3),
    axis.ticks.length = unit(0, "mm"),
    axis.title = element_blank(),
    axis.line.y.left = element_line(color = "black"),
    axis.text.y = element_blank(),
    axis.text.x = element_text(family = "Econ Sans Cnd", size = 10)
  ) +
  geom_shadowtext(
    data = subset(protests_by_province, Protests < 150),
    aes(Protests + 5, y = Province, label = Province),
    hjust = 0,
    vjust = 0.4,
    nudge_x = 0.3,
    colour = BLUE,
    bg.colour = "white",
    bg.r = 0.2,
    family = "Econ Sans Cnd",
    size = 3.5
  ) +
  geom_text(
    data = subset(protests_by_province, Protests >= 150),
    aes(5, y = Province, label = Province),
    hjust = 0,
    vjust = 0.4,
    nudge_x = 0.3,
    colour = "white",
    family = "Econ Sans Cnd",
    size = 3.5
  ) +
  labs(
    title = "Canadian Protests",
    subtitle = "Number of protests in each province, 2022 Jan - 2023 Nov"
  ) + 
  theme(
    plot.title = element_text(
      family = "Econ Sans Cnd", 
      face = "bold",
      size = 14
    ),
    plot.subtitle = element_text(
      family = "Econ Sans Cnd",
      size = 12
    )
  )

plot_1



# ---- Looking at numbers themselves--------------------------------------------

# Number of no protests in different Months and Provinces
zero_protests <- 0
for (i in data$protests){
  if (i == 0) {
    zero_protests <- zero_protests + 1
  }
}

print(paste("there are total of", zero_protests,
            "times where there were no protest"))


# Mean and Variance of number of protests
protest_mean <- mean(data$protests)
protest_var <- var(data$protests)
print(paste("the mean of number of protests is",
            protest_mean, "and the variance is", protest_var))



# ----population and protest dispersion over whole of Canada--------------------
province_pop <- data.frame(
  id=data$prov[1:13],
  population=data$pop[1:13])

province_pop$pop_percentage <-
  province_pop$population/sum(province_pop$population) * 100

province_pop$protest_percentage <- 
  protests_by_province$Protests/sum(protests_by_province$Protests) * 100

province_pop


#----Variable Transformation----------------------------------------------------
plot((data$pop), data$protests, main = "Scatter Plot", xlab = "Population", 
     ylab = "Protests", col = "black", pch = 16)

#If we apply log transformation to population data not only the number are 
# smaller and easier to manage but also looks more linearized
plot(log(data$pop), data$protests, main = "Scatter Plot",
     xlab = "log(Population)", ylab = "Protests", col = "black", pch = 16)



# -----Zero Inflated Negative Binomial Model------------------------------------
# I am going to use province as the predictor for the zero part of the model due
#to the case that some states just record a lot lower protests and closer to 0 
# for the negative binomial model itself i will include all the 
#rest of the variables.

model <- zeroinfl(protests ~ data$year + data$month + log(data$pop)|  data$prov,
                  data=data, dist="negbin")
summary(model)



#---- Bootstrapping ------------------------------------------------------------
boot_function <- function(data, indices) {
  resampled_data <- data[indices, ] # Creating a bootstrap sample
  model_boot <- zeroinfl(protests ~ year + month + log(pop)|  prov , 
                         data=resampled_data, dist="negbin") # Fitting the model
  return(coef(model_boot)) # Returning the model coefficients
}

boot_results <- suppressWarnings(boot(data, boot_function, R=500))
```
```{r}
summary(boot_results)

for (i in 1:15) {
  boot_ci <- boot.ci(boot_results, index=i, type="norm")
  print(boot_ci)
}


# ---- Monte Carlo Simulations

newdata_2025 <- data.frame()
zero_predictions <- predict(model, newdata = newdata_2025, type = "zero")
count_predictions <- predict(model, newdata = newdata_2025, type = "count")
# Grouping predictions by province
province_predictions <- aggregate(cbind(count_predictions, zero_predictions) ~ prov, data = data, FUN = mean)

# Adjusting simulation to use province-based predictions
simulation_results_province <- vector("list", length(province_predictions$prov))
names(simulation_results_province) <- province_predictions$prov


n_simulations<-10000
theta <- model$theta

for (i in 1:nrow(province_predictions)) {
  simulated_counts_province <- numeric(n_simulations)
  for (j in 1:n_simulations) {
    if (runif(1) < province_predictions$zero_predictions[i]) {
      simulated_counts_province[j] <- 0
    } else {
      simulated_counts_province[j] <- rnbinom(1, size = theta,
                                              mu = province_predictions$count_predictions[i])
    }
  }
  simulation_results_province[[i]] <- simulated_counts_province
}

# Calculating prediction intervals for each province
prediction_intervals_province <- sapply(simulation_results_province, function(sim) {
  c(lower = quantile(sim, probs = 0.025), upper = quantile(sim, probs = 0.975))
})

# Converting to a dataframe for easier viewing
prediction_intervals_df <- as.data.frame(t(prediction_intervals_province))
colnames(prediction_intervals_df) <- c("Lower_Interval", "Upper_Interval")
prediction_intervals_df$Province <- rownames(prediction_intervals_df)

prediction_intervals_df
