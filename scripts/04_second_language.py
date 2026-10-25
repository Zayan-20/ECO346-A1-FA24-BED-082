"""
Question 5: Literacy comparison by age and gender
Variant 2: Rural Sindh
Run from the repository root:
python scripts/04_second_language.py
"""

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

# Set the project directory and prepare output folders
project_dir = Path(__file__).resolve().parent.parent

fig_dir = project_dir / "figures"
table_dir = project_dir / "tables"

fig_dir.mkdir(exist_ok=True)
table_dir.mkdir(exist_ok=True)

# Read the person and household datasets
person_data = pd.read_csv(
    project_dir / "data" / "pslm_person_subset.csv"
)

household_data = pd.read_csv(
    project_dir / "data" / "pslm_hh_subset.csv",
    usecols=["hhid", "hhweight", "prov_code", "urban_rural"]
)

# Combine household information with individual records
survey_data = person_data.merge(
    household_data,
    on="hhid",
    how="left"
)

# Select eligible respondents from rural Sindh
eligible = survey_data.loc[
    (survey_data["prov_code"] == 3)
    & (survey_data["urban_rural"] == 1)
    & survey_data["age"].between(10, 64)
    & survey_data["literate"].notna()
].copy()

# Assign each respondent to a five-year age category
eligible["age_start"] = (eligible["age"] // 5) * 5
eligible["age_middle"] = eligible["age_start"] + 2

# Generate the summary statistics for each age category
summary_rows = []

for age_start, group in eligible.groupby("age_start"):
    result = {
        "band": f"{age_start}-{age_start + 4}",
        "mid": age_start + 2
    }

    for sex_code, label in [(2, "women"), (1, "men")]:
        subgroup = group.loc[group["sex"] == sex_code]

        result[f"n_{label}"] = len(subgroup)

        result[f"rate_{label}"] = (
            100 * np.average(
                subgroup["literate"],
                weights=subgroup["hhweight"]
            )
        )

    result["gap"] = result["rate_men"] - result["rate_women"]
    summary_rows.append(result)

# Arrange the results into a table
literacy_table = pd.DataFrame(summary_rows)

column_order = [
    "band", "mid", "n_women", "rate_women",
    "n_men", "rate_men", "gap"
]

literacy_table = literacy_table[column_order].sort_values("mid")

# Round percentages for the exported file
export_table = literacy_table.copy()

percent_cols = ["rate_women", "rate_men", "gap"]
export_table[percent_cols] = export_table[percent_cols].round(1)

export_table.to_csv(
    table_dir / "band_table_python.csv",
    index=False
)

print(export_table.to_string(index=False))

# Print the requested age-group statistics
def find_rate(age_band, column):
    selected = literacy_table.loc[
        literacy_table["band"] == age_band, column
    ]
    return f"{selected.iloc[0]:.1f}"


print("Women 15-19 (Python):", find_rate("15-19", "rate_women"))

print(
    "Women 55-59:", find_rate("55-59", "rate_women"),
    " Men 15-19:", find_rate("15-19", "rate_men"),
    " Men 55-59:", find_rate("55-59", "rate_men")
)

# Identify the age group with the greatest difference
max_gap = literacy_table.loc[literacy_table["gap"].idxmax()]

print(
    "Largest gap:", max_gap["band"],
    f"{max_gap['gap']:.1f}", "points"
)

# Check whether the Python estimates agree with the R output
r_file = table_dir / "band_table_R.csv"

if r_file.exists():
    r_table = pd.read_csv(r_file)

    rate_difference = max(
        (r_table[col] - export_table[col]).abs().max()
        for col in ["rate_women", "rate_men"]
    )

    matching_counts = (
        (r_table["n_women"] == export_table["n_women"]).all()
        and
        (r_table["n_men"] == export_table["n_men"]).all()
    )

    print(
        f"R vs Python: maximum rate difference = "
        f"{rate_difference:.4f}; same sample counts: {matching_counts}"
    )
else:
    print(
        "R comparison file is missing. "
        "Run scripts/03_literacy.R first."
    )

# Draw the literacy comparison chart
gender_style = {
    "women": {"label": "Women", "colour": "#8f4e8b"},
    "men": {"label": "Men", "colour": "#287271"}
}

fig, ax = plt.subplots(figsize=(9, 5.8))

for group_key, settings in gender_style.items():
    x_values = literacy_table["mid"]
    y_values = literacy_table[f"rate_{group_key}"]
    sample_size = literacy_table[f"n_{group_key}"]

    # Distinguish groups containing fewer than 30 observations
    small_group = sample_size < 30
    line_colour = settings["colour"]

    ax.plot(
        x_values,
        y_values,
        color=line_colour,
        linewidth=2,
        zorder=2
    )

    ax.scatter(
        x_values[~small_group],
        y_values[~small_group],
        s=48,
        color=line_colour,
        zorder=3
    )

    ax.scatter(
        x_values[small_group],
        y_values[small_group],
        s=48,
        facecolors="white",
        edgecolors=line_colour,
        linewidths=1.5,
        zorder=3
    )

    # Label each line at its final point
    ax.text(
        x_values.iloc[-1] + 1,
        y_values.iloc[-1],
        settings["label"],
        color=line_colour,
        fontweight="bold",
        fontsize=11,
        va="center"
    )

# Highlight the largest gap between the two groups
ax.annotate(
    "",
    xy=(max_gap["mid"], max_gap["rate_men"]),
    xytext=(max_gap["mid"], max_gap["rate_women"]),
    arrowprops={"arrowstyle": "<->", "color": "0.35"}
)

gap_position = (
    max_gap["rate_men"] + max_gap["rate_women"]
) / 2

ax.text(
    max_gap["mid"] + 1,
    gap_position,
    f"Largest gap, ages {max_gap['band']}:\n"
    f"{max_gap['gap']:.1f} points",
    fontsize=10,
    va="center",
    color="0.2"
)

# Configure axes and tick labels
ax.set_xlim(10, 70)
ax.set_ylim(-5, 105)

ax.set_xticks(range(12, 63, 5))
ax.set_xticklabels(
    [f"{start}-{start + 4}" for start in range(10, 61, 5)]
)

ax.set_yticks(range(0, 101, 20))
ax.set_yticklabels([f"{value}%" for value in range(0, 101, 20)])

ax.set_xlabel("Age group (years)")
ax.set_ylabel("Weighted literacy rate")

# Improve the chart's appearance
ax.grid(axis="y", color="0.88", linewidth=0.8)
ax.grid(axis="x", color="0.92", linewidth=0.6)
ax.set_axisbelow(True)

for spine in ax.spines.values():
    spine.set_visible(False)

ax.tick_params(length=0)

fig.suptitle(
    "Literacy rates by gender across age groups\nin rural Sindh",
    x=0.01,
    ha="left",
    fontweight="bold",
    fontsize=13
)

# Add the data source and sample details
has_small_groups = (
    (literacy_table["n_women"] < 30)
    | (literacy_table["n_men"] < 30)
).any()

caption = (
    "Source: PSLM 2019-20, person and household files. "
    f"Rural Sindh residents aged 10-64 with known literacy status "
    f"(n = {len(eligible):,}).\n"
    "Household-weighted literacy rates; points represent five-year age groups.\n"
    "Hollow markers: groups with fewer than 30 observations"
    + ("." if has_small_groups else " (none in this sample).")
)

fig.text(
    0.01,
    0.01,
    caption,
    fontsize=8.5,
    color="0.3",
    ha="left",
    va="bottom"
)

fig.subplots_adjust(
    left=0.08,
    right=0.97,
    top=0.85,
    bottom=0.22
)

# Save using the original output path
fig.savefig(
    fig_dir / "literacy_by_age_python.svg"
)

plt.close(fig)