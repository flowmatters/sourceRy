
source_folder="C:\\src\\sourceRy"
data_folder="C:\\temp\\sourceRyExample"
source_project_fn="Example.rsproj"
scenario_fn="Scenario_Definitions.csv"
sample_size=500

code_fn <- function(f){
	paste(source_folder,f,sep="\\")
}

data_fn <- function(f){
	paste(data_folder,f,sep="\\")
}

source(code_fn("source_ei.r"))
source(code_fn("example_flow_metrics.r"))
source(code_fn("source_mc.r"))

# Select a version of Source. If Source isn't installed in the default location (C:\Program Files\eWater\Source x.y.z.w)
# then use configure_source("full_path_to_source")
configure_for_source_version("3.0.7.31")

end_points = start_source_servers(6)
work_with(end_points)
cluster = source_helper_cluster()

scenario_definitions = read.csv(data_fn(scenario_fn),header=TRUE,quote=NULL)

sample_evap <- function(sample_size){
	PET_SCALE = pmin(pmax(rnorm(sample_size,mean=1,sd=0.2),0.5),1.5)
	cbind(PET_SCALE)
}

global_results_base = data_fn("Results")
system.time(evap_results <- source_mc(cluster,fn(source_project_fn),global_results_base,"evap",scenario_definitions,sample_evap,sample_size,seasonal_flow_statistics),gcFirst=TRUE)

# Shut down SNOW cluster (but doesn't shut down Source end-points -- you need to do that manually in TaskManager!)
finished_helper_cluster(cluster)