# Main module for the SourceRy package
#
# SourceRy supports the specification, execution and post processing of
# many eWater-Source simulations.
#
# This module provide core functions for configuring access to Source, including
# starting multiple Source servers, specifying run parameters, executing sets of runs
# and post processing results.
# 
# See https://github.com/flowmatters/sourceRy

library(snow)

frame_files <- lapply(sys.frames(), function(x) x$ofile)
frame_files <- Filter(Negate(is.null), frame_files)
PATH <- frame_files[[length(frame_files)]]

configure_source <- function(install_path){
  source_executable <<- shQuote(paste(install_path,"\\","RiverSystem.CommandLine.exe",sep=""))
}

configure_for_source_version <- function(version_number){
  configure_source(paste("C:\\Program Files\\eWater\\Source ",version_number,sep=""))
}

default_end_point = "net.tcp://localhost:8523/eWater/Services/RiverSystemService"
current_project_file = ""

current_project_on_endpoint <- function(end_point){
  ep_row = match(end_point,current_project_files[,1])
  current_project_files[ep_row,2]
}

set_current_project_file <- function(end_point,project_file){
  ep_row = match(end_point,current_project_files[,1])
  current_project_files[ep_row,2] <<- project_file
}

work_with <- function(end_points) {
  mappings = cbind(end_points,"")
  colnames(mappings) <- c("end_point","project_file")
  current_project_files <<- mappings
}

start_source_server <- function(end_point=default_end_point){
  system (paste(source_executable,"-m Server", "-a", end_point), wait=FALSE)
}

start_source_servers <- function(n,first_port=8523){
  result = NULL
  for(p in first_port:(first_port+n-1)){
    end_point = paste("net.tcp://localhost:",p,"/eWater/Services/RiverSystemService",sep="")
    start_source_server(end_point)
    result = c(result,end_point)
  }
  result
}

source_params <- function(){
  vector(mode="list")
}

source_results <- function(){
  vector(mode="list")
}

record_global <- function(global_expression){
	paste( "$",global_expression,sep="")
}

record_time_series <- function(time_series_identifier){
	paste("\"",time_series_identifier,"\"",sep="")
}

param_string <- function(parameters){
  result = ""
  for(n in names(parameters)){
	result = paste(result," -v $",n,"=",parameters[[n]]," ",sep="")
  }
  result
}

results_string <- function(results_template){
  result = ""
  for(n in names(results_template)){
	result = paste(result," -r ",results_template[[n]]," ",sep="")
  }
  result
}

results_from <- function(name, results_table){
  subbed_name = gsub("\"","",gsub("[\\$\\ ]",".",name))
  indices = grep(subbed_name,names(results_table)) 
  as.double(results_table[indices][[1]])
}

match_results <-function(results_table,results_template){
  results = vector(mode="list")
  results$Date = results_table$Date
  for(n in names(results_template))
    results[[n]] = results_from(results_template[[n]],results_table)
  results
}

load_source_results <- function(results_fn,results_template){
  all_results = read.csv(results_fn,header=TRUE,quote=NULL)
  if(length(results_template)>0){
 	return(match_results(all_results,results_template))
  } else {
 	return(all_results)
  }
}

run_source <- function(project_file,parameters,results_template,load_results,output_fn,end_point=default_end_point){
#	return (parameters)
    load_required = !(current_project_on_endpoint(end_point) == project_file)
    set_current_project_file(end_point,project_file)
    # "-p", shQuote(project_file),     
#    output_fn = tempfile(fileext=".csv")
	cmd_line = paste(source_executable, "-m Client",  "-a", end_point, ifelse(load_required,paste("-p",shQuote(project_file)),""),"-o", output_fn,param_string(parameters), results_string(results_template))
    print(cmd_line)
	system(cmd_line)
#	return(cmd_line)
	if(load_results){
		return(load_source_results(output_fn,results_template))
	} else {
	  return (output_fn)
	}
}

run_on_end_point <- function(params_and_end_point,project_file,results_template,load_results,results_path){
  params = source_params()
  for(i in 3:length(params_and_end_point)){
     params[[param_names[i-2]]] = params_and_end_point[i]
  }
  end_point = current_project_files[params_and_end_point[2],1]
  output_fn = paste(results_path,"\\","results",params_and_end_point[1],".csv",sep="")
  run_source(project_file,params,results_template,load_results,output_fn,end_point)
}

run_source_parallel <- function(cluster,project_file,params,results_path,results_template=NULL) {
  if(is.null(results_template)) {
    results_template = source_results()	
  }

  num_runs = nrow(params)
  param_names <<- colnames(params)
  params_and_alloc = cbind(1:num_runs,rep(1:length(current_project_files[,1]),length.out=num_runs),params)
  colnames(params_and_alloc) <- c("RunNum","EndPointNum",param_names)
  parameters_df = as.data.frame(t(params_and_alloc))
  clusterExport(cluster,"param_names")
  clusterExport(cluster,"current_project_files")
  clusterExport(cluster,"source_executable")
  num_endpoints = length(current_project_files[,1])
  results=NULL
  if( num_runs >= num_endpoints){
    for( i in 1:(num_runs %/% num_endpoints) ){
      offset = (i-1)*num_endpoints
      param_start = offset + 1
      param_end = offset + num_endpoints
      cat(paste("Run", i, "on full cluster: rows", param_start,"to",param_end,"\n"))
  	  these_results =   clusterApply(cluster,parameters_df[,param_start:param_end],run_on_end_point,project_file,results_template,FALSE,results_path)
      results = c(results,these_results)
  	  current_project_files[,2] <<- rep(project_file,num_endpoints)
    }
  }
  leftovers = num_runs %% num_endpoints
  if( leftovers > 0 ) {
  cat(paste("Running", leftovers, "leftovers on cluster\n"))
  leftover_params = parameters_df[,(num_runs-(leftovers-1)):num_runs,drop = FALSE]
  print(leftover_params)
  leftover_results = clusterApply(cluster,leftover_params,run_on_end_point,project_file,results_template,FALSE,results_path)
    results = c(results,leftover_results)
	current_project_files[1:leftovers,2] <<- rep(project_file,leftovers)
  }
  results
}

source_helper_cluster <- function(){
  cluster = makeCluster(rep("localhost",length(current_project_files[,1])),type="SOCK")
  clusterCall(cluster,source,PATH)
  cluster
}

finished_helper_cluster <- function(cluster){
  stopCluster(cluster)
}
