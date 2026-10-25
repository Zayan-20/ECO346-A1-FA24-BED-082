# Question 2: Distribution of education expenditure
# Variant 2: Rural Sindh
# Run from the project root:
# Rscript scripts/02_distribution.R

library(ggplot2)
library(svglite)

# Check the required input and prepare output folder
person_file <- "data/pslm_person_subset.csv"
household_file <- "data/pslm_hh_subset.csv"

if (!file.exists(person_file)) {
  stop("Please run this script from the repository root.")
}

dir.create("figures", showWarnings = FALSE, recursive = TRUE)

# Import the datasets and attach household information
persons <- read.csv(person_file)
households <- read.csv(household_file)

households <- households[
  , c("hhid", "hhweight", "prov_code", "urban_rural")
]

combined_data <- merge(
  persons,
  households,
  by = "hhid",
  all.x = TRUE
)

# Select students in rural Sindh with positive education expenditure
sindh_students <- subset(
  combined_data,
  prov_code == 3 &
    urban_rural == 1 &
    !is.na(ed_total) &
    ed_total > 0
)

# Calculate weighted quantiles using cumulative household weights
weighted_percentile <- function(values, weights, probability) {
  sorted_index <- order(values)

  sorted_values <- values[sorted_index]
  sorted_weights <- weights[sorted_index]

  cumulative_share <- cumsum(sorted_weights) / sum(sorted_weights)
  position <- which(cumulative_share >= probability)[1]

  return(sorted_values[position])
}

# Summary statistics
student_count <- nrow(sindh_students)

education_cost <- sindh_students$ed_total
household_weights <- sindh_students$hhweight

median_weighted <- weighted_percentile(
  education_cost, household_weights, 0.50
)

median_regular <- median(education_cost)

percentile_10 <- weighted_percentile(
  education_cost, household_weights, 0.10
)

percentile_90 <- weighted_percentile(
  education_cost, household_weights, 0.90
)

percentile_ratio <- percentile_90 / percentile_10

# Restrict the chart to expenditures between Rs 100 and Rs 1,000,000
outside_limits <- education_cost < 100 | education_cost > 1000000
excluded_count <- sum(outside_limits)

chart_data <- sindh_students[
  education_cost >= 100 & education_cost <= 1000000,
]

# Display numerical results in the console
cat("Total students:", student_count, "\n")
cat("Weighted median (Rs):", median_weighted, "\n")
cat("Unweighted median (Rs):", median_regular, "\n")
cat("Weighted 10th percentile (Rs):", percentile_10, "\n")
cat("Weighted 90th percentile (Rs):", percentile_90, "\n")
cat("90th / 10th percentile:", sprintf("%.2f", percentile_ratio), "\n")
cat("Observations excluded from chart:", excluded_count, "\n")

# Format rupee amounts for labels
rupee_label <- function(value) {
  format(
    round(value),
    big.mark = ",",
    scientific = FALSE,
    trim = TRUE
  )
}

# Construct a weighted histogram on a logarithmic x-axis
base_chart <- ggplot(
  chart_data,
  aes(x = ed_total, weight = hhweight)
) +
  geom_histogram(
    aes(y = after_stat(density)),
    binwidth = 0.1,
    boundary = 2,
    closed = "left",
    fill = "#386641",
    colour = "white",
    linewidth = 0.35
  ) +
  scale_x_log10(
    breaks = 10^(2:6),
    labels = c(
      "Rs 100",
      "Rs 1,000",
      "Rs 10,000",
      "Rs 100,000",
      "Rs 1,000,000"
    )
  )

# Verify the total density area
histogram_bins <- ggplot_build(base_chart)$data[[1]]

density_area <- sum(
  histogram_bins$density *
    (histogram_bins$xmax - histogram_bins$xmin)
)

cat("Histogram density area:", round(density_area, 4), "\n")

peak_density <- max(histogram_bins$density)

# Add percentile reference lines and annotations
final_chart <- base_chart +
  geom_vline(
    xintercept = c(median_weighted, percentile_90),
    colour = "#9b2226",
    linetype = "dashed",
    linewidth = 0.8
  ) +
  annotate(
    "text",
    x = median_weighted,
    y = peak_density * 1.12,
    label = paste0(
      "Weighted median\nRs ",
      rupee_label(median_weighted)
    ),
    hjust = 1.05,
    vjust = 0,
    colour = "#9b2226",
    fontface = "bold",
    size = 3.6
  ) +
  annotate(
    "text",
    x = percentile_90,
    y = peak_density * 1.12,
    label = paste0(
      "90th percentile\nRs ",
      rupee_label(percentile_90)
    ),
    hjust = -0.05,
    vjust = 0,
    colour = "#9b2226",
    fontface = "bold",
    size = 3.6
  ) +
  scale_y_continuous(
    expand = expansion(mult = c(0, 0.25))
  ) +
  labs(
    title = paste0(
      "Annual education expenditure among rural Sindh students\n",
      "Middle 80%: Rs ", rupee_label(percentile_10),
      " to Rs ", rupee_label(percentile_90)
    ),
    x = "Education expenditure per year (Rs, logarithmic scale)",
    y = "Density per log10 unit",
    caption = paste0(
      "Data: PSLM 2019-20, person and household files.\n",
      "Rural Sindh; ", rupee_label(student_count),
      " students with positive education expenditure.\n",
      excluded_count,
      " observations outside the displayed expenditure range were excluded.\n",
      "Household-weighted histogram; bin width = 0.1 log10 units."
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold"),
    plot.title.position = "plot",
    plot.caption.position = "plot",
    plot.caption = element_text(
      hjust = 0,
      size = 9,
      colour = "grey35"
    ),
    panel.grid.minor = element_blank()
  )

# Save the chart to the original output location
ggsave(
  filename = "figures/distribution.svg",
  plot = final_chart,
  width = 9,
  height = 5.8
)