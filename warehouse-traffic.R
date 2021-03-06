library(dplyr)
library(ggplot2)

setwd("/Users/marielpacada/kaiyo-traffic")
categories <- read.csv("categories.csv") 
warehouse <- read.csv("warehouse_flux.csv")

# remove primary key column + duplicates
warehouse$X <- NULL
warehouse <- unique(warehouse)

# join warehouse data with item categories
names(categories)[1] <- "category_id"
warehouse <- merge(warehouse, categories, by = "category_id")
warehouse$category_id <- NULL

# order by timestamp
warehouse$create_date <- strptime(warehouse$create_date, format = "%Y-%m-%d %H:%M:%S")
warehouse <- warehouse[order(warehouse$create_date),]

# extract month and year from timestamp + delete timestamp
warehouse$year <- as.factor(warehouse$create_date$year + 1900)
warehouse$month <- warehouse$create_date$mon + 1
warehouse$month <- month.abb[warehouse$month]
warehouse$create_date <- NULL


# input: factor from status column
# output: bar chart displaying count by each category for given status
status_count <- function(activity) { 
  data <- warehouse %>% filter(status == activity)
  return(ggplot(data, aes(x = category)) + geom_bar(fill = "#F2AE0F", width = 0.5) + 
           labs(title = paste("Number of items marked", tolower(activity))) +
           xlab("Category") + ylab("Count"))
}

status_count("Receiving")
status_count("Sold")
status_count("Retired")

# filter all items that have left the warehouse (either sold or retired)
out_items <- warehouse %>% filter(status != "Receiving")

# normalized bar chart showing proportion of outgoing items that were sold/retired per category
ggplot(out_items, aes(x = category, fill = status)) + geom_bar(position = "fill") + 
  labs(title = "Proportion of outgoing items that were sold and retired", fill = "Status") +
  xlab("Category") + ylab("Count") +
  theme(panel.background = element_blank(), axis.line = element_line(colour = "grey")) +
  scale_fill_brewer(palette = "Set1") + coord_flip()


# bar chart that shows activity for each month
ggplot(warehouse, aes(x = factor(month, levels = month.abb), 
                      fill = factor(status, levels = c("Receiving", "Sold", "Retired")))) + 
  geom_bar(position = position_dodge()) + 
  labs(title = "Monthly Receiving and Selling Activity", fill = "Status") + 
  xlab("Month") + ylab("Count") +
  scale_fill_brewer(palette = "Paired")


# filters the receiving items for the first trimester
first_tri <- warehouse %>% 
  filter(month == "Jan"|month == "Feb"|month == "Mar" & status == "Receiving") %>%
  group_by(category) %>% 
  summarize(count = n())

# bar chart displaying count by each category within the first trimester of all given years
ggplot(first_tri, aes(x = category, y = count)) + 
  labs(title = "Items received within the first quarter") +
  xlab("Category") + ylab("Count") +
  geom_bar(fill = "#189ff2", stat = "identity", width = 0.5)


# all items marked receiving, including items received more than once
all_received <- warehouse %>% filter(status == "Receiving") %>% select(status, subitem_id, category)

# NOTE: there were some items that were marked with two difference categories, so we handle this by simply 
#       filtering the data further to only include examples with a unique subitem_id
once_received <- all_received[!duplicated(all_received$subitem_id),]

# creates data frame that details how many times an item was received
repeat_received <- all_received %>% group_by(subitem_id) %>% summarize(count = n())
repeat_received <- merge(repeat_received, once_received, by = "subitem_id")

# creates a subset that contains only items that were received more than once
# counts how many items (NOT how many times it was received) were received more than once for each category
repeat_received <- repeat_received %>% 
  filter(count > 1) %>% 
  group_by(category) %>% 
  summarize(count = n())

ggplot(repeat_received, aes(x = category, y = count)) + 
  geom_bar(fill = "#43ad26", stat = "identity", width = 0.5) + 
  labs(title = "Items that were received more than once") +
  xlab("Category") + ylab("Count")



# filters data for the first four months of each year
corona_months <- warehouse %>% filter(month == "Mar"|month == "Apr")

# subset that contains only examples from 2018 and 2019
pre_covid <- corona_months %>% filter(year != "2020")

# subset that contains only examples from 2020
covid <- corona_months %>% filter(year == "2020")



# input: factor from status column 
# output: data frame showing the proportion of all first-four-month activity that were from before/after covid
corona_activity <- function(activity) { 
  total <- length(corona_months$status[corona_months$status == activity])
  before <- length(pre_covid$status[pre_covid$status == activity])
  during <- length(covid$status[covid$status == activity])
  
  before_ratio <- round(before / total, 3)
  during_ratio <- round(during / total, 3)
  
  return(as.data.frame(t(rbind(c("before", "during"), c(before_ratio, during_ratio)))))
}

corona_activity("Receiving")
corona_activity("Sold")



# filters all examples from 2018 and 2019
general_activity <- warehouse %>% 
  filter(year != "2020") %>% 
  group_by(year, status) %>% 
  summarize(count = n())

# input: factor from status column
# output: data frame showing the item count from each year based on status
activity_yearly <- function(activity) {
  data <- general_activity %>% filter(status == activity) %>% select(year, count)
  return(data)
}

activity_yearly("Receiving")
activity_yearly("Sold")
activity_yearly("Retired")

