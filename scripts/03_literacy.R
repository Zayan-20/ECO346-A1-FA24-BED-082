# Question 3 and redesigned Question 4
# Literacy rates across age groups in rural Sindh
# Execute from the repository root:
# Rscript scripts/03_literacy.R

library(ggplot2)
library(svglite)
library(dplyr)

# Input and output locations
person_path <- "data/pslm_person_subset.csv"
hh_path <- "data/pslm_hh_subset.csv"

if (!file.exists(person_path)) {
  stop("Please run this script from the repository root.")
}

dir.create("figures", showWarnings = FALSE)
dir.create("tables", showWarnings = FALSE)

# Load person and household records
person_data <- read.csv(person_path)
hh_data <- read.csv(hh_path)

hh_data <- hh_data[
  , c("hhid", "hhweight", "prov_code", "urban_rural")
]

merged_data <- merge(
  person_data,
  hh_data,
  by = "hhid",
  all.x = TRUE
)

# Keep rural Sindh residents aged 10 to 64 with known literacy status
literacy_data <- subset(
  merged_data,
  prov_code == 3 &
    urban_rural == 1 &
    age >= 10 &
    age <= 64 &
    !is.na(literate)
)

# Create five-year age groups and their plotting midpoints
literacy_data$age_group_start <- floor(literacy_data$age / 5) * 5
literacy_data$age_midpoint <- literacy_data$age_group_start + 2

literacy_data$gender <- ifelse(
  literacy_data$sex == 1,
  "Men",
  "Women"
)

# Calculate sample counts and weighted literacy percentages
group_summary <- literacy_data %>%
  group_by(age_group_start, age_midpoint, gender) %>%
  summarise(
    observations = n(),
    literacy_percent = 100 * sum(hhweight * literate) / sum(hhweight),
    .groups = "drop"
  ) %>%
  mutate(
    small_sample = observations < 30
  )

# Prepare the comparison table for women and men
women_data <- group_summary %>%
  filter(gender == "Women") %>%
  select(age_group_start, age_midpoint, observations, literacy_percent)

men_data <- group_summary %>%
  filter(gender == "Men") %>%
  select(age_group_start, age_midpoint, observations, literacy_percent)

comparison_table <- merge(
  women_data,
  men_data,
  by = c("age_group_start", "age_midpoint"),
  suffixes = c("_women", "_men")
)

comparison_table$age_band <- paste0(
  comparison_table$age_group_start,
  "-",
  comparison_table$age_group_start + 4
)

comparison_table$literacy_gap <-
  comparison_table$literacy_percent_men -
  comparison_table$literacy_percent_women

comparison_table <- comparison_table[
  order(comparison_table$age_group_start),
  c(
    "age_band",
    "age_midpoint",
    "observations_women",
    "literacy_percent_women",
    "observations_men",
    "literacy_percent_men",
    "literacy_gap"
  )
]

names(comparison_table) <- c(
  "band",
  "mid",
  "n_women",
  "rate_women",
  "n_men",
  "rate_men",
  "gap"
)

# Round percentage values for presentation
export_table <- comparison_table

percentage_columns <- c("rate_women", "rate_men", "gap")

export_table[percentage_columns] <- lapply(
  export_table[percentage_columns],
  round,
  digits = 1
)

# Save the table to its original location
write.csv(
  export_table,
  "tables/band_table_R.csv",
  row.names = FALSE
)

print(export_table)

# Report the required age-specific figures
get_rate <- function(age_band, column_name) {
  sprintf(
    "%.1f",
    comparison_table[[column_name]][comparison_table$band == age_band]
  )
}

cat(
  "Women, ages 15-19:",
  get_rate("15-19", "rate_women"),
  " Men:",
  get_rate("15-19", "rate_men"),
  "\n"
)

cat(
  "Women, ages 55-59:",
  get_rate("55-59", "rate_women"),
  " Men:",
  get_rate("55-59", "rate_men"),
  "\n"
)

# Identify the age group with the largest male-female difference
largest_gap <- comparison_table[
  which.max(comparison_table$gap),
]

cat(
  "Largest literacy gap:",
  largest_gap$band,
  "=",
  sprintf("%.1f", largest_gap$gap),
  "percentage points\n"
)

cat(
  "Total observations:",
  nrow(literacy_data),
  " Smallest group:",
  min(group_summary$observations),
  "\n"
)

# Prepare age labels and series endpoints for the graph
age_labels <- paste0(
  seq(10, 60, by = 5),
  "-",
  seq(14, 64, by = 5)
)

gender_colours <- c(
  "Women" = "#8f4e8b",
  "Men" = "#287271"
)

series_ends <- group_summary %>%
  filter(age_midpoint == 62)

gap_label_height <- (
  largest_gap$rate_women + largest_gap$rate_men
) / 2

figure_caption <- paste0(
  "Source: PSLM 2019-20 person and household files. ",
  "Sample: rural Sindh residents aged 10-64 with reported literacy status (n = ",
  format(nrow(literacy_data), big.mark = ","),
  ").\n",
  "Literacy percentages use household weights. Each point represents a five-year age group.\n",
  "Open circles indicate groups with fewer than 30 observations",
  if (any(group_summary$small_sample)) "." else " (none in this sample)."
)

# Draw literacy trends by gender
literacy_plot <- ggplot(
  group_summary,
  aes(
    x = age_midpoint,
    y = literacy_percent,
    colour = gender,
    group = gender
  )
) +
  geom_line(linewidth = 1) +
  geom_point(
    aes(shape = small_sample),
    size = 3.1,
    stroke = 1.1,
    fill = "white"
  ) +
  scale_shape_manual(
    values = c("FALSE" = 16, "TRUE" = 21),
    guide = "none"
  ) +
  scale_colour_manual(
    values = gender_colours,
    guide = "none"
  ) +
  # Label both lines at their final age group
  geom_text(
    data = series_ends,
    aes(label = gender),
    hjust = 0,
    nudge_x = 1,
    fontface = "bold",
    size = 4
  ) +
  # Mark the age group with the largest literacy difference
  geom_segment(
    data = largest_gap,
    aes(
      x = mid,
      xend = mid,
      y = rate_women,
      yend = rate_men
    ),
    inherit.aes = FALSE,
    colour = "grey35",
    arrow = arrow(
      ends = "both",
      length = grid::unit(0.08, "inches")
    )
  ) +
  annotate(
    "text",
    x = largest_gap$mid + 1,
    y = gap_label_height,
    hjust = 0,
    size = 3.7,
    colour = "grey20",
    label = paste0(
      "Largest difference\n",
      largest_gap$band,
      ": ",
      sprintf("%.1f", largest_gap$gap),
      " points"
    )
  ) +
  scale_x_continuous(
    breaks = seq(12, 62, by = 5),
    labels = age_labels,
    limits = c(10, 70),
    expand = expansion(mult = 0)
  ) +
  scale_y_continuous(
    limits = c(0, 100),
    breaks = seq(0, 100, by = 20),
    labels = function(value) paste0(value, "%")
  ) +
  labs(
    title = paste0(
      "Literacy rates differ between men and women\n",
      "across age groups in rural Sindh"
    ),
    x = "Age group (years)",
    y = "Weighted literacy rate",
    caption = figure_caption
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold"),
    plot.title.position = "plot",
    plot.caption.position = "plot",
    plot.caption = element_text(
      hjust = 0,
      size = 9,
      colour = "grey35"
    )
  )

# Export the chart using the same filename
ggsave(
  filename = "figures/literacy_by_age.svg",
  plot = literacy_plot,
  width = 9,
  height = 5.8
)