RemoveIndMissLoci.GCL <- function(sillyvec, proportion = 0.8){
  
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  #   This function removes individuals from "*.gcl" objects that have fewer non-missing loci than that specified by "proportion".
  #
  # Inputs~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  #   
  #   sillyvec - a vector of silly codes without the ".gcl" extention (e.g. sillyvec <- c("KQUART06","KQUART08","KQUART10")). 
  #
  #   proportion - the cut-off proportion of the number of non-missing loci.
  # 
  # Outputs~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  #    Returns a tibble of indiduals removed by silly.
  #    Assigns the ".gcl" objects back to workspace after removing individuals with missing loci.
  #
  # Example~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  #   load("V:/Analysis/2_Central/Chinook/Cook Inlet/2019/2019_UCI_Chinook_baseline_hap_data/2019_UCI_Chinook_baseline_hap_data.RData")
  # 
  #   missloci_ind <- RemoveIndMissLoci.GCL(sillyvec = sillyvec157, proportion = 0.8)
  #
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  
  if(!require("pacman")) install.packages("pacman"); library(pacman); pacman::p_load(tidyverse) #Install packages, if not in library and then load them.
  
  output <- lapply(sillyvec, function(silly){
    
    my.gcl <- get(paste0(silly, ".gcl"), pos = 1)
    
    tmp <- my.gcl %>% 
      select(LocusControl$locusnames) 
    
    IDsToRemove <- my.gcl %>% 
      mutate(nloci = rowSums(!is.na(tmp)), nmissing = rowSums(tmp == "0")) %>% 
      mutate(prop_loci = 1-(nmissing/nloci)) %>% 
      select(prop_loci, everything()) %>% 
      filter(prop_loci <= proportion) %>% 
      pull(FK_FISH_ID)
    
    assign(x = paste0(silly, ".gcl"), value = my.gcl %>% filter(!FK_FISH_ID%in%IDsToRemove), pos = 1, envir = .GlobalEnv )
    
    tibble(SILLY_CODE = silly, IDs_Removed = IDsToRemove)
    
  }) %>% 
    bind_rows()
  
 if(dim(output)[1]==0){
   
  message("No individuals were removed")
   
 } else{
   
   message(paste0("A total of ", dim(output)[1]), " individuals were removed from sillys in sillyvec.")
   
 }

  return(output)

}
