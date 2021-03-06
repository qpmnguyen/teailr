library(tidyverse)
library(ggsci)
library(patchwork)
library(glue)

if(Sys.info()["sysname"] == "Darwin"){
    save_dir <- "../cilr_manuscript/figures"
} else {
    save_dir <- "../teailr_manuscript/manuscript/figures"
}

results <- readRDS(file = "analyses/simulations_diff_ab/output/sim_diff_ab.rds")
grid <- readRDS(file = "analyses/simulations_diff_ab/output/sim_diff_ab_grid.rds")

results <- results %>% mutate(id = map(id, ~{str_split(.x, "_")[[1]][3]})) %>% 
    unnest(id) %>% mutate(id = as.numeric(id))

combined_df <- left_join(results, grid)
combined_df <- combined_df %>% group_by(model, distr, adj, output, spar, eff_size, s_rho) %>% 
    summarise(est = mean(res), 
              upper = mean(res) + (sd(res)/sqrt(10)), 
              lower = mean(res) - (sd(res)/sqrt(10))) %>% 
    unite("model", model, distr)  %>% 
    mutate(model = case_when(
        model == "cilr_wilcox_mnorm" ~ "cILR Mixture Normal w/ Wilcox Test", 
        model == "cilr_wilcox_norm" ~ "cILR Normal w/ Wilcox Test",
        model == "cilr_welch_mnorm" ~ "cILR Mixture Normal w/ Welch Test", 
        model == "cilr_welch_norm" ~ "cILR Normal w/ Welch Test",
        model == "deseq2_NA" ~ "DESeq2", 
        model == "corncob_NA" ~ "corncob"
    )) %>% 
    mutate(adj = replace_na(adj, "Not Applicable")) %>% 
    mutate(output = case_when(
        output == "cdf" ~ "CDF", 
        output == "zscore" ~ "z-score", 
        TRUE ~ "Not Applicable"
    )) %>%
    mutate(model = str_wrap(model, width = 10)) %>% 
    rename("Sparsity" = "spar", "Correlation" = "s_rho", "Effect Size" = "eff_size")

type_i_error <- combined_df %>% filter(`Effect Size` == 1)
power <- combined_df %>% filter(`Effect Size` > 1)

type_i_plt <- ggplot(type_i_error, aes(x = model, y = est, shape = adj, linetype = output)) + 
    geom_pointrange(aes(ymin = lower, ymax = upper, col = model), show.legend = FALSE, position = position_dodge(width = 0.5)) +  
    facet_grid(Sparsity ~ Correlation, labeller = label_both) + geom_hline(aes(yintercept = 0.05), col = "red") + 
    scale_color_d3() + theme_bw() + 
    theme(axis.title.x = element_blank()) + 
    labs(y = "Type I error", linetype = "Output type", shape = "Correlation adjustment", col = "Model")

ggsave(type_i_plt, filename = "figures/sim_diff_ab_type_i_error.png", dpi = 300, width = 15, height = 8)
ggsave(type_i_plt, filename = "figures/sim_diff_ab_type_i_error.eps", dpi = 300, width = 15, height = 8)


pwr_plot <- ggplot(power, aes(x = Sparsity, y = est,  col = model, shape = adj)) +
    geom_pointrange(aes(ymin = lower, ymax = upper, linetype = output)) + 
    geom_line(aes(linetype = output), show.legend = FALSE) + 
    facet_grid(`Effect Size` ~ Correlation, labeller = label_both) + 
    scale_color_d3() + theme_bw() + geom_hline(yintercept = 0.8, col = "red") + 
    labs(y = "Power", linetype = "Output type", shape = "Correlation adjustment", col = "Model")
ggsave(pwr_plot, filename = "figures/sim_diff_ab_pwr.png", dpi = 300, width = 10, height = 8)
ggsave(pwr_plot, filename = "figures/sim_diff_ab_pwr.eps", dpi = 300, width = 10, height = 8)

combo_plot <- type_i_plt + pwr_plot + plot_annotation(tag_levels = "A") + 
    plot_layout(widths = c(0.7,0.3), guides = "collect") & 
    guides(linetype = guide_legend(override.aes = list(shape = NA)), 
           color = guide_legend(override.aes = list(linetype = 0)), 
           shape = guide_legend(override.aes = list(linetype = 0))) &
    theme(legend.position = "bottom", legend.box = "horizontal", legend.direction = "horizontal", 
          legend.justification = "center", legend.box.just = "center", 
          legend.box.margin = margin(r = -12, l = -12, unit = "cm"))

ggsave(combo_plot, filename = "figures/sim_diff_ab_comb.png", dpi = 300, width = 18, height = 10)
ggsave(combo_plot, filename = "figures/sim_diff_ab_comb.eps", dpi = 300, width = 18, height = 10)

file.copy(from = Sys.glob("figures/*.png"), to = glue("{save_dir}", dir = save_dir), 
          recursive = TRUE, overwrite = TRUE)
file.copy(from = Sys.glob("figures/*.eps"), to = glue("{save_dir}", dir = save_dir), 
          recursive = TRUE, overwrite = TRUE)
