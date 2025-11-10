# This is the main script for the projetoSIAD project
# Additional code and functionality will be added here
# as the project develops.
library(plotly)
library(dplyr)
library(ggplot2)


# show all columns of resume_data.csv
#its inside projetoSIAD/data folder
resume_data <- read.csv("C:/Users/migue/Desktop/SIAD/projetoSIAD/resume_data.csv")
str((resume_data))

# show first few rows of resume_data.csv

head(resume_data)
# specify the column types of resume_data.csv
# based on the data below build me a graph using plotly in R

avg_exp <- resume_data %>%
  group_by(experiencere_requirement) %>%
  summarise(avg_score = mean(matched_score, na.rm = TRUE))

# Create bar plot using ggplot2
p1 <- ggplot(avg_exp, aes(x = experiencere_requirement, y = avg_score)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  theme_minimal() +
  labs(title = "Average Match Score by Experience Requirement",
       x = "Experience Requirement",
       y = "Average Score") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# Display the plot
print(p1)

# Example data frame)

# Summarize data: average match score per job position
avg_match <- resume_data %>%
  group_by(`X.job_position_name`) %>%
  summarise(avg_score = mean(matched_score, na.rm = TRUE)) %>%
  arrange(desc(avg_score)) %>%
  slice_head(n = 10)  # top 10 positions

# Create bar plot using ggplot2
p2 <- ggplot(avg_match, aes(x = reorder(X.job_position_name, -avg_score), y = avg_score)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  geom_text(aes(label = round(avg_score, 2)), vjust = -0.5) +
  theme_minimal() +
  labs(title = "Average Match Score by Job Position (Top 10)",
       x = "Job Position",
       y = "Average Match Score") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# Display the plot
print(p2)

# Now you can open the HTML files in your browser to see the plots

# --- IGNORE ---

# Know I want too know a little bit more about the data of the data set
summary(resume_data)
str(resume_data)
# --- END IGNORE ---
# lets clear nan values from columns   
resume_data <- na.omit(resume_data)
# --- END IGNORE ---
