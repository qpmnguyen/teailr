library(phyloseq)
library(tidyverse)
source("../../R/utils.R")
source("../../R/cilr.R")

enrichment_processing <- function(dat){
  physeq <- dat$physeq
  annotation <- dat$annotation
  label <- physeq@sam_data$HMP_BODY_SUBSITE
  tab <- tax_table(physeq) %>% as('matrix') %>% as.data.frame()
  otu_names <- rownames(tab)
  colnames(annotation) <- c("GENUS", "METAB")
  tab <- dplyr::left_join(tab, annotation, by = "GENUS")
  tab <- tab %>% as.matrix()
  rownames(tab) <- otu_names
  
  # then, convert taxtable to A matrix  
  A <- taxtab2A(tab, "METAB", full = FALSE)
  
  # after than, retrieve X matrix as pivoted OTU table and re-convert to matrix
  X <- as(otu_table(physeq), "matrix") %>% t()
  
  # Shuffling
  idx <- sample(1:nrow(X), size = nrow(X), replace = F)
  X <- X[idx,]
  label <- label[idx]
  
  return(list(X = X, A = A, label = label))
}

enrichment_evaluate <- function(scores, results, metric){
  if (metric == "fdr"){
    significance <- ifelse(results != "Supragingival Plaque",1,0)
  } else {
    significance <- ifelse(results == "Supragingival Plaque", 1, 0)  
  }
  scores <- calculate_statistic(eval = metric, pred = scores[,"Aerobic"], true = significance)
  return(scores)
}

enrichment_analysis <- function(X, A, method, label, metric, ...){
  if (method %in% c("ssgsea", "gsva")){
    scores <- generate_alt_scores(X = X, A = A, method = method, preprocess = T, pcount = 1)
  } else if (method %in% c("wilcoxon")){
    if (metric == "auc"){
      output <- "scores"
    } else {
      output <- "sig"
    }
    scores <- wc_test(X = X, A = A, thresh = 0.05, preprocess = T, pcount = 1, output = output)
  } else {
    scores <- cilr(X = X, A = A, resample = T, ..., maxrestarts=1000, epsilon = 1e-06, maxit= 1e5)
  }
  is.matrix(scores)
  output <- enrichment_evaluate(scores = scores, results = label, metric = metric)
  return(output)
}







