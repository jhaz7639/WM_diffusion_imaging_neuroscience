from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
from matplotlib.lines import Line2D
from matplotlib.patches import Patch

# This script generates a multipanel figure showing publication trends for four diffusion MRI methods,
# with bars for yearly counts and lines for cumulative counts. The left panel shows all four methods from
#  2000, while the right panel zooms in on two emerging methods from 2015. This figure is published as
# Figure 1 C-D in the paper Landin-Romero, Hazelton, Mito, & Calamente (Under review). 
# The data are derived from Europe PMC counts, and the CSV files should be placed in the specified folder.
# See /data for inputs.

# --- Point this at your local folder ---
files_path = Path("/path/to/where/you/have/the/csvs") # change this

files = {
    "Diffusion tensor imaging": files_path / "diffusion_tensor_imaging_by_year.csv",
    "Fractional anisotropy": files_path / "fractional_anisotropy_by_year.csv",
    "Constrained spherical deconvolution": files_path / "constrained_spherical_deconvolution_by_year.csv",
    "Fixel-based analysis": files_path / "fixel_based_analysis_by_year.csv",
}

# --- Panel start years (change these to adjust each x-axis) ---
panel_a_start = 2000
panel_b_start = 2015

series = {}
for label, path in files.items():
    #df = pd.read_csv(path, skiprows=1)
    df = pd.read_csv(path)
    df = df[df["year"] <= 2026]
    df = df.sort_values("year")
    series[label] = df.set_index("year")["total"]

min_year = min(s.index.min() for s in series.values())
max_year = 2026
years = list(range(min_year, max_year + 1))

# Yearly counts, and cumulative counts computed from the FULL record
# (so the cumulative line at 2000 or 2015 still includes earlier papers).
annual = pd.DataFrame(index=years)
for label, s in series.items():
    annual[label] = s.reindex(years, fill_value=0)
cum = annual.cumsum()

all_terms = list(files.keys())
emerging = ["Constrained spherical deconvolution", "Fixel-based analysis"]

plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "font.size": 14,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "axes.linewidth": 0.8,
})

colors = {
    "Diffusion tensor imaging": "#1b4965",
    "Fractional anisotropy": "#e07a5f",
    "Constrained spherical deconvolution": "#5f8d4e",
    "Fixel-based analysis": "#8e44ad",
}


def combo_panel(ax, cols, start, tick_step=5, bar_width_total=0.8):
    """Bars = publications per year (left axis); lines = cumulative (right axis)."""
    a = annual.loc[start:, cols]
    c = cum.loc[start:, cols]
    x = np.array(a.index)
    n = len(cols)
    width = bar_width_total / n

    ax2 = ax.twinx()
    ax2.spines["right"].set_visible(True)   # global rcParams hides it; twin axis needs it

    # Bars, grouped side by side for each year
    for i, col in enumerate(cols):
        offset = (i - (n - 1) / 2) * width
        ax.bar(x + offset, a[col], width=width, color=colors[col],
               alpha=0.55, edgecolor="none", zorder=2)

    # Cumulative lines on the right axis
    for col in cols:
        ax2.plot(x, c[col], color=colors[col], linewidth=2.2, zorder=3)

    ax.set_xlim(start - 0.7, max_year + 0.7)
    ax.set_xticks(list(range(start, 2026, tick_step)))
    ax.set_xlabel("Year")
    ax.set_ylabel("Publications per year")
    ax2.set_ylabel("Cumulative publications")
    ax.set_ylim(bottom=0)
    ax2.set_ylim(bottom=0)
    fmt = mticker.FuncFormatter(lambda v, _: f"{int(v):,}")
    ax.yaxis.set_major_formatter(fmt)
    ax2.yaxis.set_major_formatter(fmt)
    ax.grid(axis="y", color="#dddddd", linewidth=0.6, zorder=0)
    ax.set_axisbelow(True)
    ax.axvline(2026, color="#999999", linewidth=0.6, linestyle="--", zorder=1)
    return ax2


fig, axes = plt.subplots(1, 2, figsize=(12.5, 5), dpi=600)

# Panel A: all four methods from 2000; Panel B: CSD + FBA from 2015
combo_panel(axes[0], all_terms, panel_a_start, tick_step=5)
combo_panel(axes[1], emerging, panel_b_start, tick_step=2)

for ax, letter in zip(axes, "AB"):
    ax.text(-0.14, 1.05, letter, transform=ax.transAxes, fontsize=15,
            fontweight="bold", va="top")

# Shared legend: row 1 = colour per search term, row 2 = bar vs line meaning
term_handles = [Patch(facecolor=colors[t], alpha=0.7, label=t) for t in all_terms]
style_handles = [
    Patch(facecolor="#888888", alpha=0.55, label="Publications per year (bars, left axis)"),
    Line2D([0], [0], color="#888888", linewidth=2.2, label="Cumulative publications (lines, right axis)"),
]
fig.legend(handles=term_handles, loc="upper center", bbox_to_anchor=(0.5, 1.10),
           ncol=4, frameon=False, fontsize=12, columnspacing=1.2)
fig.legend(handles=style_handles, loc="upper center", bbox_to_anchor=(0.5, 1.03),
           ncol=2, frameon=False, fontsize=12, columnspacing=1.5)

plt.rcParams["svg.fonttype"] = "none"
fig.tight_layout(rect=[0, 0, 1, 0.92])
fig.savefig(files_path / "Figure_1_C_D.png", dpi=300, bbox_inches="tight")
fig.savefig(files_path / "Figure_1_C_D.pdf", bbox_inches="tight")
fig.savefig(files_path / "Figure_1_C_D.svg", bbox_inches="tight")
print("done")
