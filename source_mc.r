
run_scenario <- function(cluster,results_base,scenario,all_scenarios,sample_parameters){
	# construct parameter matrix (from sampled variables + )
	scenario_path = paste(results_base,"\\Scenario",gsub("\\.","_",scenario),sep="")
	dir.create(scenario_path,recursive=TRUE)
	row = which(all_scenarios==scenario)
	params = as.matrix(cbind(sample_parameters,all_scenarios[row,-1],row.names=NULL))
	run_source_parallel(cluster,project_file,params,scenario_path)
}

run_all_scenarios <- function(cluster,results_base,scenarios,sample_parameters,stats_fn) {
	metrics_list = list()
	for(s in scenarios$Scenario) {
		filenames = run_scenario(cluster,results_base,s,scenarios,sample_parameters)
		metrics_list[[paste("Scenario_",s,sep="")]] = calculate_metrics_across_files(filenames,"outflow",stats_fn,rewrite_files=TRUE)	
	}
	metrics_list
}

regroup_by_metric <- function(scenario_results_list) {
	metrics = colnames(scenario_results_list[[1]])
	by_metrics = list()
	for( m in metrics ){
		by_metrics[[m]] = group_by_stat(scenario_results_list,m)
	}
	by_metrics
}

regenerate_stats <- function(base_directory,stats_fn) {
	scenario_dirs = dir(base_directory,pattern="Scenario*")
	metrics_list = list()
	for(sd in scenario_dirs) {
	    cat(paste("Calculating stats for",sd,"\n"))
		fqd = paste(base_directory,sd,sep="\\")
		metrics_list[[sd]] = calculate_metrics_across_files(dir(fqd,full.names=TRUE),"outflow",stats_fn,rewrite_files=FALSE)
	}

	by_metric = regroup_by_metric(metrics_list)
	box_plot_all_to_file(by_metric,paste(base_directory,"boxplot",sep="\\"))
}

box_plot_all_to_file <- function(metric_summaries,base_file) {
	pdf(paste(base_file,".pdf",sep=""))
	for(i in 1:length(metric_summaries)) {
	  boxplot(metric_summaries[[i]],main=names(metric_summaries)[i])
	  
	  csvfn = paste(base_file,"_",names(metric_summaries)[i],".csv",sep="")
	  the_stats = boxplot.stats(metric_summaries[[i]])
	  numbers = the_stats$stats 
	  colnames(numbers) <- the_stats$names
	  write.csv(numbers,csvfn)
	}
		
	dev.off()
}

source_mc <- function(cluster,project,results_base,results_id,scenarios,sampler,nRuns,stats_fn){
	project_file <<- project
	results_dir = paste(results_base,results_id,sep="\\")
	all_scenario_results = run_all_scenarios(cluster,results_dir,scenarios,sampler(nRuns),stats_fn)
	by_metric = regroup_by_metric(all_scenario_results)
	box_plot_all_to_file(by_metric,paste(results_dir,"boxplot",sep="\\"))
	all_scenario_results
}

calculate_metrics_across_files <- function(filenames,resultsName,stats_fn,rewrite_files=FALSE){
	results_template = source_results()
	results_template$vals = record_global(resultsName)
	
	metric_values = NULL
	for(i in 1:length(filenames)) {
#	  cat(paste("Loading results from: ",filenames[i],"\n"))
	  resultsX = load_source_results(filenames[[i]],results_template)
	  resultsX = add_date_elements(resultsX)
	  
	  metric_values = rbind(metric_values,stats_fn(resultsX))
	  if(rewrite_files){
		names = c("Date",paste("$",resultsName,sep=""))
		table_to_write = cbind(as.character(resultsX$Date),as.character(resultsX$vals))
		colnames(table_to_write) <- names
	    write.csv(table_to_write,filenames[[i]],quote=FALSE,row.names=FALSE)
	  }
	}
	rownames(metric_values) <- filenames
	metric_values	
}

group_by_stat <- function(scenario_results,stat){
	results = NULL
	for( s in scenario_results ){
		col_num = which(colnames(s)==stat)
		
		results = cbind(results,s[,col_num])
	}
	colnames(results) <- names(scenario_results)
	results
}

add_date_elements <- function(results) {
  results$Month = as.numeric(gsub("-..","",gsub("^....-","",results$Date)))
  results$Year = as.numeric(gsub("-.*","",results$Date))
  results$Season = as.character(seasons$Season[results$Month])
  results
}

configure_seasons <- function(filename){
	seasons <<- read.csv(filename,header=TRUE,quote=NULL)
	seasonNames <<- levels(seasons$Season)	
}

configure_seasons(fn("seasons.csv"))
