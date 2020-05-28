CheckDupWithinSilly.GCL <- function(sillyvec, loci = LocusControl$locusnames, quantile = 0.99, minnonmissing = 0.6, proportion = 0.99, ncores = 8){
  
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  #   This function checks for duplicate individuals within each silly in "sillyvec".
  #
  # Inputs~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  #   
  #   sillyvec - a vector of silly codes without the ".gcl" extention (e.g. sillyvec <- c("KQUART06","KQUART08","KQUART10")). 
  #
  #   loci - vector of locus names; if set to NULL all loci in the ".gcl" obejects will be used.
  #
  #   quantile and minproportion - these arguments are used together to determine the cut-off proportion at which a pair of duplicates 
  #                                is defined: i.e. proportion = max(quantile(duplication, quantile), minproportion. 
  #                                Setting "quantile" equal to NULL will skip the calculation of the duplication distribution and will run much faster
  # 
  # Outputs~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  #    When quantile is set to NULL, returns a tibble of duplicate pairs of individuals by silly.
  #    When quantile is a number, a list containing a tibble of duplicate pairs of individuals by silly and tibble the porportion of duplication for each pair of individuals.
  #
  # Example~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  #   load("V:/Analysis/2_Central/Chinook/Cook Inlet/2019/2019_UCI_Chinook_baseline_hap_data/2019_UCI_Chinook_baseline_hap_data.RData")
  # 
  #   dupcheck <- CheckDupWithinSilly.GCL(sillyvec = sillyvec157, loci = loci557, quantile = 0.99, proportion = 0.95, ncores = 4)
  #
  # Note~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  #   Sillys without duplicates will be included in the output report but will have NAs for IDs1, IDs2, Missing1, Missing2, and proportion
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  
  start.time <- Sys.time() 
  
  if(!all(loci %in% LocusControl$locusnames)){
    
    stop(paste0("The following `loci` were not found in `LocusControl`:\n", paste(setdiff(loci,LocusControl$locusnames), collapse = "\n")))
    
  }
  
  if(!require("pacman")) install.packages("pacman"); library(pacman); pacman::p_load(tidyverse, doParallel, parallel, foreach, rubias)  # Install packages, if not in library and then load them.
  
  
  if(ncores > detectCores()) {
    stop("'ncores' is greater than the number of cores available on machine\nUse 'detectCores()' to determine the number of cores on your machine")
  }
  
  nsilly <- length(sillyvec)
  
  nloci <- length(loci)
  
  scores_cols <- c(loci, paste0(loci, ".1")) %>% 
    sort()
  
  sillyvec_new <- silly_n.GCL(sillyvec) %>% 
    filter(n > 1) %>% 
    pull(silly)#Removing single individual collections from sillyvec.
  
  my.gcl <- sapply(sillyvec_new, function(silly){
    
    get(paste(silly, ".gcl", sep=""), pos = 1)
    
  }, simplify = FALSE) 
  
  # Start if NULL quantile
  if(is.null(quantile)){
    
    ##Loop through sillys
    cl <- parallel::makePSOCKcluster(ncores)
    
    doParallel::registerDoParallel(cl, cores = ncores)  
    
    dupcheck0 <- foreach::foreach(silly = sillyvec_new, .packages = c("tidyverse","rubias")) %dopar% {
      
      new.gcl <- my.gcl[[silly]] %>% 
        dplyr::mutate(sample_type = "reference", repunit = NA_character_, collection = SILLY_CODE, indiv = SillySource) %>% 
        dplyr::select(sample_type, repunit, collection, indiv, tidyselect::all_of(scores_cols))
      
       rubias::close_matching_samples(D = new.gcl, gen_start_col = 5, min_frac_non_miss = minnonmissing, min_frac_matching = proportion)
       
       } %>% bind_rows()# End multicore loop
    
    parallel::stopCluster(cl)
    
    dupcheck <- dupcheck0 %>% 
      tidyr::separate(indiv_1, into = c(NA, "ID1")) %>% 
      tidyr::separate(indiv_2, into = c(NA, "ID2")) %>% 
      dplyr::mutate(silly = collection_1, proportion = num_match/num_non_miss) %>% 
      dplyr::select(silly, ID1, ID2, proportion)
    
    #Calculate the proportion of missing scores for ID1 and ID2 and create the output report.
    
    report <- lapply(report$silly %>% unique(), function(silly){
      
     new.gcl <- my.gcl[[silly]]
     
     dups <- report %>% 
       dplyr::filter(silly==!!silly) %>% 
       dplyr::mutate(order = seq(length(silly)))
      
     ID1 <- new.gcl %>% 
       dplyr::mutate(ID1 = as.character(FK_FISH_ID)) %>% 
       dplyr::filter(ID1%in%dups$ID1) %>% 
       dplyr::select(ID1, tidyselect::all_of(loci)) %>% 
       tidyr::gather(-ID1, key = "Locus", value = "allele") %>% 
       dplyr::group_by(ID1) %>% 
       dplyr::summarize(Missing1 = sum(is.na(allele))/nloci) %>% 
       dplyr::left_join(dups, by = "ID1")%>% 
       dplyr::arrange(order)
     
     ID2 <- new.gcl %>% 
       dplyr::mutate(ID2 = as.character(FK_FISH_ID)) %>% 
       dplyr::filter(ID2%in%dups$ID2) %>% 
       dplyr::select(ID2, tidyselect::all_of(loci)) %>% 
       tidyr::gather(-ID2, key = "Locus", value = "allele") %>% 
       dplyr::group_by(ID2) %>% 
       dplyr::summarize(Missing2 = sum(is.na(allele))/nloci) %>% 
       dplyr::left_join(dups, by = "ID2") %>% 
       dplyr::arrange(order)
     
     bind_cols(ID1, ID2) %>% 
       dplyr::mutate(silly = !!silly) %>% 
       dplyr::select(silly, ID1, ID2, Missing1, Missing2, proportion)

    }) %>%  bind_rows()  
    
    print(Sys.time()-start.time)
    
    return(report)
    
  }  # End if NULL quantile
  
  # Start if quantile 
  if(!is.null(quantile)){
    
    cl <- parallel::makePSOCKcluster(ncores)
    
    doParallel::registerDoParallel(cl, cores = ncores)  
    
    # multicore loop
    dupcheck <- foreach::foreach(silly = sillyvec, .packages = "tidyverse") %dopar% {
      
      new.gcl <- my.gcl[[silly]]
      
      IDs <- new.gcl$FK_FISH_ID
      
      n <- dim(new.gcl)[1]
      
      nloci <- length(loci)
      
      # Combine allele 1 and 2 into single columns for each locus separated by a period.
      scores0 <- new.gcl[ , c("FK_FISH_ID", scores_cols)] 
      
      if(n < 2){
        
        report <- tibble::tibble(silly = silly, ID1 = NA, ID2 = NA, Missing1 = NA, Missing2 = NA, proportion = NA)  # If only one individual the results will be a tibble of NAs. Can't do next() using applys.
        
      } else {
        
        ncombs <- choose(n, 2)
        
        mycombs <- combn(IDs, 2)
        
        scores0_allele_1 <- scores0 %>% 
          dplyr::select(FK_FISH_ID, !!!loci) %>% 
          tidyr::gather(locus, allele_1, -FK_FISH_ID)
        
        scores0_allele_2 <- scores0 %>% 
          dplyr::select(FK_FISH_ID, !!!paste0(loci, ".1")) %>% 
          tidyr::gather(locus, allele_2, -FK_FISH_ID) %>% 
          dplyr::mutate(locus = stringr::str_remove(string = locus, pattern = "\\.1"))
        
        scores1 <- dplyr::left_join(x = scores0_allele_1, y = scores0_allele_2, by = c("FK_FISH_ID", "locus")) %>% 
          tidyr::unite(col = "genotype", c("allele_1", "allele_2"), sep = ".") %>% 
          dplyr::mutate(genotype = dplyr::na_if(genotype, "NA.NA")) %>% 
          tidyr::spread(locus, genotype) %>% 
          tibble::column_to_rownames("FK_FISH_ID")
        
        duplication <- sapply(1:ncombs, function(comb){
          
          compair <- scores1[as.character(mycombs[1, comb]), ] == scores1[as.character(mycombs[2, comb]), ]
          
          sum(compair[!is.na(compair)]) / sum(!is.na(compair))
          
        }) %>% purrr::set_names(sapply(1:ncombs, function(comb){
          
          paste(mycombs[,comb], collapse=".")
          
        }))
        
        proportion <- max(quantile(duplication, quantile), minproportion)
        
        dupIND <- duplication > proportion
        
        if(sum(dupIND)){
          
          dups <- data.frame(ID1 = mycombs[1, dupIND], ID2 = mycombs[2, dupIND])
          
          missing <- t(sapply(1:nrow(dups), function(dup){
            
            vec <- match(as_vector(dups[dup, ]), IDs)
            
            c("Missing1" = sum(is.na(scores1[vec[1], ])),
              "Missing2" = sum(is.na(scores1[vec[2], ])))
            
          }, simplify = TRUE))
          
          report <- dplyr::bind_cols(dplyr::as_tibble(dups), 
                                     dplyr::as_tibble(missing), 
                                     proportion = duplication[dupIND]) %>% 
            dplyr::mutate(silly = silly) %>% 
            dplyr::select(silly, tidyr::everything())
          
        }
        if(!sum(dupIND)){
          
          report <- tibble::tibble(silly = silly, ID1 = NA, ID2 = NA, Missing1 = NA, Missing2 = NA, proportion = NA) 
          
        }
        
      }
      
      DupDist <- tibble::tibble(silly = silly, IDs = names(duplication), duplication) %>% 
        tidyr::separate(IDs, into = c("ID1", "ID2"), sep = "[:punct:]")
      
      list(report = report, DupDist = DupDist)  
      
    }  # End multicore loop
    
    parallel::stopCluster(cl)
    
    report <- lapply(1:length(sillyvec), function(i){
      
      dupcheck[[i]][["report"]]
      
    }) %>% dplyr::bind_rows()
    
    DupDist <- lapply(1:length(sillyvec), function(i){
      
      dupcheck[[i]][["DupDist"]]
      
    }) %>% dplyr::bind_rows()
    
    output <- list(report = report, DupDist = DupDist)
    
    print(Sys.time()-start.time)
    
    return(output)
    
  }  # end if quantile
  
}