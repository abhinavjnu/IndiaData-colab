# ============================================================================
# 07_viz_themes.R - Publication-Quality Visualization Themes
# ============================================================================
# Custom ggplot2 themes and helper functions for academic publications.
# Designed for economics/social science journals.
#
# Features:
#   - Clean, minimal themes suitable for journals
#   - Consistent color palettes
#   - Easy export to PDF/PNG at correct dimensions
#   - Pre-built plot functions for common visualizations
# ============================================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(scales)
  library(data.table)
})

# ============================================================================
# Color Palettes
# ============================================================================

# Professional color palette (colorblind-friendly)
COLORS_MAIN <- c(
  "#2E5B88",  # Dark blue
  "#E57200",  # Orange
  "#6B8E23",  # Olive green
  "#8B0000",  # Dark red
  "#4B0082",  # Indigo
  "#008B8B",  # Dark cyan
  "#8B4513",  # Saddle brown
  "#2F4F4F"   # Dark slate gray
)

# Two-color palette (e.g., Male/Female)
COLORS_BINARY <- c(
  "#2E5B88",  # Blue
  "#E57200"   # Orange
)

# Sequential palette (for gradients)
COLORS_SEQUENTIAL <- c(
  "#f7fbff",
  "#deebf7",
  "#c6dbef",
  "#9ecae1",
  "#6baed6",
  "#4292c6",
  "#2171b5",
  "#08519c",
  "#08306b"
)

# Diverging palette (for comparisons around zero)
COLORS_DIVERGING <- c(
  "#b2182b",  # Dark red
  "#d6604d",
  "#f4a582",
  "#fddbc7",
  "#f7f7f7",  # White (center)
  "#d1e5f0",
  "#92c5de",
  "#4393c3",
  "#2166ac"   # Dark blue
)

# Rural/Urban colors
COLORS_SECTOR <- c(
  "Rural" = "#6B8E23",   # Green
  "Urban" = "#2E5B88"    # Blue
)

# Employment type colors
COLORS_EMPLOYMENT <- c(
  "Self-employed" = "#2E5B88",
  "Regular wage/salaried" = "#E57200",
  "Casual labour" = "#6B8E23"
)

#' Get color palette
#' @param palette Name: "main", "binary", "sequential", "diverging", "sector", "employment"
#' @param n Number of colors needed (for main palette)
#' @return Character vector of hex colors
get_colors <- function(palette = "main", n = NULL) {

  colors <- switch(
    palette,
    "main" = COLORS_MAIN,
    "binary" = COLORS_BINARY,
    "sequential" = COLORS_SEQUENTIAL,
    "diverging" = COLORS_DIVERGING,
    "sector" = COLORS_SECTOR,
    "employment" = COLORS_EMPLOYMENT,
    COLORS_MAIN  # default
  )

  if (!is.null(n) && n <= length(colors)) {
    colors <- colors[1:n]
  }

  return(colors)
}

# ============================================================================
# Publication Theme
# ============================================================================

#' Publication-quality ggplot2 theme
#' @param base_size Base font size (default: 11)
#' @param base_family Font family (default: "sans")
#' @param grid Include grid lines: "none", "major", "minor", "both"
#' @param axis_lines Show axis lines: "both", "x", "y", "none"
#' @return ggplot2 theme object
theme_publication <- function(base_size = 11,
                              base_family = "sans",
                              grid = "major",
                              axis_lines = "both") {

  # Base theme
  theme_minimal(base_size = base_size, base_family = base_family) %+replace%
    theme(
      # Text elements
      plot.title = element_text(
        size = base_size * 1.2,
        face = "bold",
        hjust = 0,
        margin = margin(b = 10)
      ),
      plot.subtitle = element_text(
        size = base_size,
        hjust = 0,
        margin = margin(b = 10)
      ),
      plot.caption = element_text(
        size = base_size * 0.8,
        hjust = 1,
        color = "gray40",
        margin = margin(t = 10)
      ),

      # Axis
      axis.title = element_text(size = base_size, face = "bold"),
      axis.title.x = element_text(margin = margin(t = 10)),
      axis.title.y = element_text(margin = margin(r = 10)),
      axis.text = element_text(size = base_size * 0.9, color = "gray20"),
      axis.ticks = element_line(color = "gray50", linewidth = 0.3),
      axis.line = if (axis_lines %in% c("both", "x", "y")) {
        element_line(color = "gray20", linewidth = 0.4)
      } else {
        element_blank()
      },
      axis.line.x = if (axis_lines %in% c("both", "x")) {
        element_line(color = "gray20", linewidth = 0.4)
      } else {
        element_blank()
      },
      axis.line.y = if (axis_lines %in% c("both", "y")) {
        element_line(color = "gray20", linewidth = 0.4)
      } else {
        element_blank()
      },

      # Grid
      panel.grid.major = if (grid %in% c("major", "both")) {
        element_line(color = "gray90", linewidth = 0.3)
      } else {
        element_blank()
      },
      panel.grid.minor = if (grid %in% c("minor", "both")) {
        element_line(color = "gray95", linewidth = 0.2)
      } else {
        element_blank()
      },

      # Panel
      panel.background = element_rect(fill = "white", color = NA),
      panel.border = element_blank(),

      # Legend
      legend.title = element_text(size = base_size * 0.9, face = "bold"),
      legend.text = element_text(size = base_size * 0.85),
      legend.position = "bottom",
      legend.direction = "horizontal",
      legend.box = "horizontal",
      legend.key = element_rect(fill = "white", color = NA),
      legend.key.size = unit(0.8, "lines"),
      legend.background = element_rect(fill = "white", color = NA),
      legend.margin = margin(t = 5),

      # Facets
      strip.text = element_text(
        size = base_size,
        face = "bold",
        margin = margin(b = 5, t = 5)
      ),
      strip.background = element_rect(fill = "gray95", color = NA),

      # Plot margins
      plot.margin = margin(15, 15, 15, 15),

      # Complete theme
      complete = TRUE
    )
}

#' Minimal theme (even cleaner)
#' @param base_size Base font size
#' @return ggplot2 theme object
theme_minimal_pub <- function(base_size = 11) {
  theme_publication(base_size = base_size, grid = "none", axis_lines = "both")
}

#' Theme for faceted plots
#' @param base_size Base font size
#' @return ggplot2 theme object
theme_facet <- function(base_size = 10) {
  theme_publication(base_size = base_size) +
    theme(
      strip.text = element_text(size = base_size * 0.95),
      panel.spacing = unit(1, "lines")
    )
}

# ============================================================================
# Scale Functions
# ============================================================================

#' Scale for discrete fill using publication colors
#' @param palette Which palette to use
#' @param ... Additional arguments to scale_fill_manual
#' @return ggplot2 scale
scale_fill_pub <- function(palette = "main", ...) {
  scale_fill_manual(values = get_colors(palette), ...)
}

#' Scale for discrete color using publication colors
#' @param palette Which palette to use
#' @param ... Additional arguments to scale_color_manual
#' @return ggplot2 scale
scale_color_pub <- function(palette = "main", ...) {
  scale_color_manual(values = get_colors(palette), ...)
}

#' Scale for continuous fill (gradients)
#' @param low Low color
#' @param high High color
#' @param ... Additional arguments
#' @return ggplot2 scale
scale_fill_gradient_pub <- function(low = "#deebf7", high = "#08519c", ...) {
  scale_fill_gradient(low = low, high = high, ...)
}

#' Percentage scale for y-axis
#' @param ... Additional arguments to scale_y_continuous
#' @return ggplot2 scale
scale_y_percent <- function(...) {
  scale_y_continuous(labels = function(x) paste0(x, "%"), ...)
}

#' Comma-formatted scale for y-axis
#' @param ... Additional arguments
#' @return ggplot2 scale
scale_y_comma <- function(...) {
  scale_y_continuous(labels = scales::comma, ...)
}

# ============================================================================
# Figure Export
# ============================================================================

#' Save figure in publication-ready format
#' @param plot ggplot object
#' @param filename Output filename (without extension)
#' @param output_dir Output directory (default: figures folder)
#' @param formats Output formats: "pdf", "png", or both
#' @param width Width in inches (default: 6)
#' @param height Height in inches (default: 4)
#' @param dpi Resolution for PNG (default: 300)
#' @param scale Scale factor (default: 1)
#' @return Paths to created files (invisibly)
save_figure <- function(plot,
                        filename,
                        output_dir = NULL,
                        formats = c("pdf", "png"),
                        width = 6,
                        height = 4,
                        dpi = 300,
                        scale = 1) {

  if (is.null(output_dir)) {
    output_dir <- get_path("figures")
  }

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  created_files <- character()

  for (fmt in formats) {
    output_path <- file.path(output_dir, paste0(filename, ".", fmt))

    tryCatch({
      ggsave(
        output_path,
        plot = plot,
        width = width,
        height = height,
        dpi = dpi,
        scale = scale,
        bg = "white"
      )

      message(sprintf("Saved: %s", output_path))
      created_files <- c(created_files, output_path)

    }, error = function(e) {
      warning(sprintf("Failed to save %s: %s", fmt, e$message))
    })
  }

  invisible(created_files)
}

#' Save figure at journal-specific dimensions
#' @param plot ggplot object
#' @param filename Filename
#' @param journal Preset: "single_column", "double_column", "full_page"
#' @param ... Additional arguments to save_figure
#' @return Paths to files
save_figure_journal <- function(plot,
                                filename,
                                journal = c("single_column", "double_column", "full_page"),
                                ...) {

  journal <- match.arg(journal)

  # Common journal dimensions (in inches)
  dims <- switch(
    journal,
    "single_column" = c(width = 3.5, height = 3),
    "double_column" = c(width = 7, height = 4),
    "full_page" = c(width = 7, height = 9)
  )

  save_figure(plot, filename, width = dims["width"], height = dims["height"], ...)
}

# ============================================================================
# Pre-built Plot Functions
# ============================================================================

#' Bar plot for labour force indicators
#' @param data data.table with indicator data
#' @param x_var X-axis variable
#' @param y_var Y-axis variable (indicator)
#' @param fill_var Optional fill variable for grouping
#' @param title Plot title
#' @param y_label Y-axis label
#' @param show_values Show value labels on bars
#' @return ggplot object
plot_indicator_bars <- function(data,
                                x_var,
                                y_var,
                                fill_var = NULL,
                                title = NULL,
                                y_label = NULL,
                                show_values = TRUE) {

  # Base plot
  if (is.null(fill_var)) {
    p <- ggplot(data, aes(x = reorder(!!sym(x_var), -!!sym(y_var)),
                          y = !!sym(y_var)))
    p <- p + geom_col(fill = COLORS_MAIN[1], width = 0.7)
  } else {
    p <- ggplot(data, aes(x = !!sym(x_var),
                          y = !!sym(y_var),
                          fill = !!sym(fill_var)))
    p <- p + geom_col(position = position_dodge(width = 0.8), width = 0.7)
    p <- p + scale_fill_pub()
  }

  # Add value labels
  if (show_values) {
    if (is.null(fill_var)) {
      p <- p + geom_text(aes(label = round(!!sym(y_var), 1)),
                         vjust = -0.5, size = 3)
    } else {
      p <- p + geom_text(aes(label = round(!!sym(y_var), 1)),
                         position = position_dodge(width = 0.8),
                         vjust = -0.5, size = 2.5)
    }
  }

  # Labels and theme
  p <- p +
    labs(
      title = title,
      x = NULL,
      y = y_label %||% y_var,
      fill = fill_var
    ) +
    scale_y_percent() +
    theme_publication() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))

  return(p)
}

#' Line plot for time series indicators
#' @param data data.table with time series data
#' @param x_var Time variable
#' @param y_var Indicator variable
#' @param group_var Grouping variable (for multiple lines)
#' @param title Plot title
#' @param y_label Y-axis label
#' @param show_points Show data points
#' @return ggplot object
plot_indicator_trend <- function(data,
                                 x_var,
                                 y_var,
                                 group_var = NULL,
                                 title = NULL,
                                 y_label = NULL,
                                 show_points = TRUE) {

  if (is.null(group_var)) {
    p <- ggplot(data, aes(x = !!sym(x_var), y = !!sym(y_var)))
    p <- p + geom_line(color = COLORS_MAIN[1], linewidth = 1)
    if (show_points) {
      p <- p + geom_point(color = COLORS_MAIN[1], size = 2)
    }
  } else {
    p <- ggplot(data, aes(x = !!sym(x_var), y = !!sym(y_var),
                          color = !!sym(group_var), group = !!sym(group_var)))
    p <- p + geom_line(linewidth = 1)
    if (show_points) {
      p <- p + geom_point(size = 2)
    }
    p <- p + scale_color_pub()
  }

  p <- p +
    labs(
      title = title,
      x = NULL,
      y = y_label %||% y_var,
      color = group_var
    ) +
    scale_y_percent() +
    theme_publication()

  return(p)
}

#' Horizontal bar plot (for state comparisons)
#' @param data data.table
#' @param x_var Value variable (will be on x-axis)
#' @param y_var Category variable (will be on y-axis, sorted)
#' @param title Plot title
#' @param x_label X-axis label
#' @param highlight_top Highlight top N states
#' @return ggplot object
plot_horizontal_bars <- function(data,
                                 x_var,
                                 y_var,
                                 title = NULL,
                                 x_label = NULL,
                                 highlight_top = NULL) {

  # Sort by value
  data <- copy(data)
  setorderv(data, x_var, order = 1)
  data[, (y_var) := factor(get(y_var), levels = get(y_var))]

  # Create fill variable for highlighting
  if (!is.null(highlight_top)) {
    n <- nrow(data)
    data[, .highlight := c(rep("Other", n - highlight_top),
                           rep("Top", highlight_top))]

    p <- ggplot(data, aes(x = !!sym(x_var), y = !!sym(y_var), fill = .highlight))
    p <- p + scale_fill_manual(values = c("Top" = COLORS_MAIN[1], "Other" = "gray70"),
                               guide = "none")
  } else {
    p <- ggplot(data, aes(x = !!sym(x_var), y = !!sym(y_var)))
    p <- p + geom_col(fill = COLORS_MAIN[1])
  }

  p <- p +
    geom_col(width = 0.7) +
    geom_text(aes(label = round(!!sym(x_var), 1)),
              hjust = -0.2, size = 2.5) +
    labs(
      title = title,
      x = x_label %||% x_var,
      y = NULL
    ) +
    scale_x_continuous(expand = expansion(mult = c(0, 0.15))) +
    theme_publication() +
    theme(panel.grid.major.y = element_blank())

  return(p)
}

#' Dot plot with error bars (for estimates with CIs)
#' @param data data.table with estimate, low, and high columns
#' @param y_var Category variable (y-axis)
#' @param estimate_var Point estimate variable
#' @param low_var Lower CI variable
#' @param high_var Upper CI variable
#' @param title Plot title
#' @return ggplot object
plot_estimates_ci <- function(data,
                              y_var,
                              estimate_var,
                              low_var,
                              high_var,
                              title = NULL,
                              x_label = NULL) {

  # Sort by estimate
  data <- copy(data)
  setorderv(data, estimate_var, order = 1)
  data[, (y_var) := factor(get(y_var), levels = get(y_var))]

  p <- ggplot(data, aes(x = !!sym(estimate_var), y = !!sym(y_var))) +
    geom_errorbarh(aes(xmin = !!sym(low_var), xmax = !!sym(high_var)),
                   height = 0.2, color = "gray50") +
    geom_point(color = COLORS_MAIN[1], size = 2) +
    labs(
      title = title,
      x = x_label %||% estimate_var,
      y = NULL
    ) +
    theme_publication() +
    theme(panel.grid.major.y = element_blank())

  return(p)
}

# ============================================================================
# Startup Message
# ============================================================================

message("Visualization themes loaded. Main functions:")
message("  theme_publication()              - Clean publication theme")
message("  scale_fill_pub(), scale_color_pub() - Color scales")
message("  save_figure(plot, filename)      - Export to PDF/PNG")
message("  plot_indicator_bars(data, ...)   - Bar plots for indicators")
message("  plot_indicator_trend(data, ...)  - Line plots for trends")
message("  plot_horizontal_bars(data, ...)  - Horizontal bar plots")
message("\nColor palettes: get_colors('main'), get_colors('binary'), etc.")
