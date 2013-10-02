# Template script for Monte-Carlo runs with eWater Source using SourceRy
# see https://github.com/flowmatters/sourceRy for more details

# Establish key paths for scripts and data
script.dir <- dirname(sys.frame(1)$ofile)
#print(script.dir)
script.dir.comp <- strsplit(script.dir,'/')
comp.list <- as.list(script.dir.comp[[1]][1:(length(script.dir.comp[[1]])-1)])
comp.list[['sep']]='/'
main.dir <- do.call(paste,comp.list)
#print(main.dir)
source_folder=main.dir

code_fn <- function(f){
	paste(source_folder,f,sep="//")
}

data_folder=code_fn("SampleData")
data_fn <- function(f){
	paste(data_folder,f,sep="//")
}

source(code_fn("source_ei.r"))
source(code_fn("source_mc.r"))


### Specify study parameters
# See SampleData\README.md for details
source_project_fn="YieldExample.rsproj"
scenario_fn="DiscreteScenarios.csv"

# How many runs of each discrete scenario?
sample_size=500

# Select a version of Source. If Source isn't installed in the default location (C:\Program Files\eWater\Source x.y.z.w)
# then use configure_source("full_path_to_source")
configure_for_source_version("3.4.3.540")

end_points = start_source_servers(4)
work_with(end_points)
cluster = source_helper_cluster()

scenario_definitions = read.csv(data_fn(scenario_fn),header=TRUE,quote=NULL)

# Fn to generate sampling parameters for a given sample size
# Should return a matrix with column names matching function names in Source model
sample_inflow <- function(sample_size){
	InflowScalingFactor = pmin(pmax(rnorm(sample_size,mean=0.9,sd=0.2),0.5),1.5)
	cbind(InflowScalingFactor)
}

# Function for calculating output metrics for a single result set
# Should return a matrix with useful column names!
average_supplied_pc <- function(ts_results) {
	results = NULL
	results = as.matrix(c(mean(ts_results$vals)))
	colnames(results) <- c("mean_supplied_fraction")
	results
}

global_results_base = data_fn("Results")
inflow_results =  source_mc(cluster,data_fn(source_project_fn),global_results_base,"SuppliedPC","inflow",scenario_definitions,sample_inflow,sample_size,average_supplied_pc)

# Shut down SNOW cluster (but doesn't shut down Source end-points -- you need to do that manually in TaskManager!)
finished_helper_cluster(cluster)