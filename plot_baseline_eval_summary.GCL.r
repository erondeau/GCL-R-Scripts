plot_baseline_eval_summary.GCL <- function(summary, file, method = c("MCMC", "PB", "both"), test_groups = NULL, group_colors = NULL){
  
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  #
  #   This function takes the baseline evaluation summary object produced by summarize_rubias_baseline_eval and produces plots of 
  #   of correct allocation for each test_group with summary statistics placed in the upper left corner of each plot.
  #   
  #   The solid line on the plots indicates where the true proportion equals the esimated proportion. 
  #   The two dotted lines indicate where the estimates fall within +/- 10% of the true proportion.
  #
  # Inputs~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  #
  #   summary - a baseline evaluation summary list produced by summarize_rubias_baseline_eval.
  # 
  #   file - a tibble produced by BaselineEvalSampleSizes.GCL() containing the following variables: test_group, scenario, repunit, and samps
  #
  #   method - a character string indicating the rubias output to summarize.  Select one of three choices: "MCMC" (plot MCMC output), "PB" (plot bias corrected output), "both" (plot both outputs)
  #
  #   test_groups - a character vector of group names to include in the plots. 
  #                 This also sets the order in which they are plotted.
  #                 If test_groups is not supplied, all test groups in summary will be plotted.
  #
  #   group_colors - a character vector of R colors() the same length as test_groups
  #                  If group_colors is not supplied, colors will be automatically selected using rainbow()
  #
  # Outputs~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  #
  #  If method == "MCMC" or "PB", the function produces a single page pdf file containing the plots and returns the faceted plots. 
  #  If method == "both", the function produces a two page pdf file containing the plots for both methods and no plots are returned.
  #
  # Example~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  #  load("V:/Analysis/2_Central/Chinook/Susitna River/Susitna_Chinook_baseline_2020/Susitna_Chinook_baseline_2020.Rdata")
  #  require(tidyverse)
  #  tests <- sample_sizes %>% group_by(test_group, scenario) %>% summarize(test_group = test_group %>% unique(), scenario = scenario %>% unique(), .groups = "drop_last")#Total of 510 tests  #
  #  mixvec <- tests %>% unite(col = "mixvec", test_group, scenario, sep ="_" ) %>% pull()
  #  path <-  "V:/Analysis/2_Central/Chinook/Susitna River/Susitna_Chinook_baseline_2020/rubias/output/3groups"
  #  summary <- summarize_rubias_baseline_eval.GCL (mixvec = mixvec, sample_sizes = sample_sizes, method = "both", group_names = NULL, group_names_new = NULL, groupvec = NULL, groupvec_new = NULL, path = path, alpha = 0.1, burn_in = 5000, threshold = 5e-7, ncores = 8)
  # 
  #  plot_baseline_eval_summary.GCL(summary = summary, file = "Baseline_eval_plots.pdf", method = "both", test_groups = groups3, group_colors = c("green", "magenta", "red"))
  #  
  # Note~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  #
  #  If a large number of test_groups are supplied the faceted plots will become too small to see on one page.  
  #  If so, you may need to supply a subset of test_groups to plot.
  # 
  #  This function is not intended for producing publication-ready plots; however, the code in this function
  #  can be copied and modified to produce plots formated for publication.  
  #
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  
  if(!require("pacman")) install.packages("pacman"); library(pacman); pacman::p_load(tidyverse) #Install packages, if not in library and then load them.
  
  if(!require("ggforce")) install.packages("devtools"); library(devtools); devtools::install_github("crotoc/ggforce"); library(ggforce) #Install packages, if not in library and then load them.
  
  # Check methods
  method_check <- summary$estimates$method %>% 
    unique() %>% 
    sort()
  
  

  
  
  
  
  
  if(method=="both"&!sum(method_check==sort(c("PB", "MCMC")))==2){
    
    stop("The baseline evalution summary supplied does not contain restults for both methods.")
    
  }
  
  if(method=="MCMC"&!sum(method_check%in%"MCMC")==1){
    
    stop("The baseline evalution summary supplied does not contain MCMC restults.")
    
  }
  
  if(method=="PB"&!sum(method_check%in%"PB")==1){
    
    stop("The baseline evalution summary supplied does not contain bias corrected (PB) results restults.")
    
  }
  
  # Get test_groups if none are supplied
  if(is.null(test_groups)){
    
    test_groups <- summary$summary_stats$test_group %>% 
      unique()
    
    }
  
  # Check test_groups
  test_group_check <- summary$estimates$test_group %>% 
    unique() %>% 
    as.character()
  
  if(!sum(test_group_check%in%test_groups)==length(test_groups)){
    
    stop("The baseline evaluation summary supplied does not contain results for all test_groups")
    
  }
 
  # Get rainbow of colors if no group_colors are supplied
  if(is.null(group_colors)){
    
    group_colors <- rainbow(n = length(test_groups))
    
  }
  
  # Color check
  if(!length(group_colors)==length(test_groups)){
    
    stop(paste0("The number of group_colors supplies is not the same length as test_groups: ", length(test_groups)))
    
  }
  
  pdf(file, height = 9, width=13)   
  
  # Both methods
  if(method=="both"){
    
    sapply(c("MCMC", "PB"), function(meth){
      
      plot <- summary$estimates %>%
        dplyr::filter(method==meth, test_group==repunit) %>% 
        dplyr::left_join(summary$summary_stats, by = c("test_group", "method")) %>%
        dplyr::mutate(test_group = factor(test_group, levels = levels(repunit))) %>% 
        ggplot2::ggplot(aes(x = true_proportion, y = mean, colour = repunit)) +
        ggplot2::geom_point() +
        ggplot2::geom_linerange(aes(ymin = lo5CI, ymax = hi95CI))+
        ggplot2::geom_abline(intercept = 0, slope = 1) +
        ggplot2::geom_abline(intercept = 0.1, slope = 1, lty = 2) +
        ggplot2::geom_abline(intercept = -0.1, slope = 1, lty = 2) +
        ggplot2::scale_colour_manual(name = "Reporting Group", values = group_colors) +
        ggplot2::geom_text(aes(x = .3, y = 1, label = paste0("RMSE:", round(RMSE, digits = 3))), color = "black", size = 3)+ 
        ggplot2::geom_text(aes(x = .3, y = .94, label = paste0("Bias:", round(Mean_Bias, digits = 3))), color="black", size = 3)+
        ggplot2::geom_text(aes(x = .3, y = .88, label = paste0("90% Within: ", round(100*`90%_within`, 1), "%")), color = "black", size = 3)+
        ggplot2::geom_text(aes(x = .3, y = .82, label = paste0("Within Interval: ", round(100*Within_Interval, 1), "%")), color = "black", size = 3)+
        ggplot2::facet_wrap(~ test_group) +
        ggplot2::theme(legend.position = "none", strip.text.x = element_text(size = 16), panel.spacing.y = unit(3, "lines"))+
        ggplot2::xlab("True Proportion") +
        ggplot2::ylab("Posterior Mean Reporting Group Proportion") +
        ggplot2::ggtitle(paste0("Baseline evaluation test results: ", meth), subtitle = paste0(summary$estimates$total_samps %>% unique(), " sample mixtures")) 
      
      print(plot)
      
    })
    
  } else{
    
    # One method
    meth <- method
    for(i in 1:ceiling(length(test_groups)/9)){
    plot <- summary$estimates %>%
      dplyr::filter(method==meth, test_group==repunit) %>% 
      dplyr::left_join(summary$summary_stats, by = c("test_group", "method")) %>%
      dplyr::mutate(test_group = factor(test_group, levels = levels(repunit))) %>% 
      ggplot2::ggplot(aes(x = true_proportion, y = mean, colour = repunit)) +
      ggplot2::geom_point() +
      ggplot2::geom_linerange(aes(ymin = lo5CI, ymax = hi95CI))+
      ggplot2::geom_abline(intercept = 0, slope = 1) +
      ggplot2::geom_abline(intercept = 0.1, slope = 1, lty = 2) +
      ggplot2::geom_abline(intercept = -0.1, slope = 1, lty = 2) +
      ggplot2::scale_colour_manual(name = "Reporting Group", values = group_colors) +
      ggplot2::geom_text(aes(x = .3, y = 1, label = paste0("RMSE:", round(RMSE, digits = 3))), color = "black", size = 2.8) + 
      ggplot2::geom_text(aes(x = .3, y = .94, label = paste0("Bias:", round(Mean_Bias, digits = 3))), color="black", size = 2.8) +
      ggplot2::geom_text(aes(x = .3, y = .88, label = paste0("90% Within: ", round(100*`90%_within`, 1), "%")), color = "black", size = 2.8) +
      ggplot2::geom_text(aes(x = .3, y = .82, label = paste0("Within Interval: ", round(100*Within_Interval, 1), "%")), color = "black", size = 2.8) +
      facet_wrap_paginate(~ test_group,ncol=3,nrow=3,page=i) +
      ggplot2::theme(legend.position = "none", strip.text.x = element_text(size = 16), panel.spacing.y = unit(3, "lines")) +
      ggplot2::xlab("True Proportion") +
      ggplot2::ylab("Posterior Mean Reporting Group Proportion") +
      ggtitle(paste0("Baseline evaluation test results: ", meth), subtitle = paste0(summary$estimates$total_samps %>% unique(), " sample mixtures"))
    
    print(plot)
    }
  }
  
  dev.off()
  
  if(!method=="both"){plot}
  
}