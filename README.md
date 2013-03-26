# sourceRy

R modules for managing [eWater Source][source] runs, including:

* multiple scenarios run and post-processed
* deterministic and stochastic scenarios
* parallel execution of runs
* summarising and reporting results across runs


## Configuring the Source Model

sourceRy runs Source using the Source External Interface (aka the Command Line Tool). The command line tool allows the modification of global expressions, which are configured by the user, and the retrieval of time-series results from global expressions as well as from other recorders. 

Using sourceRy requires configuring your Source model with appropriate global expressions, both for manipulating the model and for retrieving results for post-processing.

Refer to the Source user guide for more detail on the Expression Editor in general and Global Expressions in particular.

### Configuring Global Expressions for Parameterisation

The external interface allows for setting the value of a global expression to a numeric value. For this to have an effect on the model, the global expression needs to be referenced in another expression, which is either directly attached to a model parameter, or is itself used in another global which is ultimately used in an expression attached to a parameter.

Where the global expression is to map directly to an existing model parameter, the Metaparameter Explorer (in the Tools menu in Source) can be used to configure both the global expression and the parameter expression. The Metaparameter Explorer can be used to assign the same global expression to multiple parameters, allowing multiple parameters to be ‘locked’ together.

Refer to the Source user guide for more detail on the Metaparameter Explorer.

### Configuring Global Expressions for Outputs

Global expressions provide a convenient way to get output from Source, particularly in automation contexts such as sourceRy. Used in this way, global expressions offer:

* A simple, user defined text string to identify the right column in the output file (eg `$endofsystem`)
* The ability to incorporate multiple model outputs into one prior to output (eg = `$endofsystem = $outflow1 + $outflow2 + $outflow3`)
* The ability to keep the same output (and not have to change the logic in R) even when the underlying model evolves, by changing the formula of the global expressions (eg `$endofsystem = $outflow1 + $outflow2 + $outflow3 + $outflow4`)

To create a global expression for output, open the expression editor, switch the global expressions tab and create a new global. In this global, configure local expression variables for accessing at least one other value from within the model (eg `$flowAtKeyNode = Gauge Node 5 / Downstream Flow / Volume`) and use this (or these) in the formula for the global (eg `$myglobal = $flowAtKeyNode`).

### Other Setup Issues

sourceRy makes it relatively straight-forward to set up a great many Source runs. This can take a very long time to run, so it is worth taking steps to minimise runtime. There are obvious ways to do this, such as reducing the complexity of the model or limiting the simulation period. There are also technical factors to be aware of:

1.	Minimise the recorded outputs: Turn off any unnecessary recorders. Time series recording slows the process down in a number of ways: longer runtime for the core model, more memory required for each parallel run of Source and larger output files which take more time to save from Source and then load into R.
1.	Eliminate (or at least minimise) warnings: Run the model from within the main Source application and look at the log reporter. If there are warnings from the run, investigate these and eliminate them. Warnings are usually a sign that something has gone wrong, but even when the issue itself is inconsequential, the warning has an impact on performance and a scenario with many warnings can slow the model down significantly.

## Loading the R Module

There are two main R source code files used in sourceRy: A generic 'source_ei' module for coordinating interaction with the Source external interface, and the 'source_mc' module which contains the core Monte-Carlo logic. In addition, there is a third file containing sample time series metrics that can be used in post-processing results ('example_flow_metrics'). All files can be loaded into an interactive R session using the source command (no relationship to eWater Source!).

```R
source("C:\\TEMP\\source_ei.r")
source("C:\\TEMP\\source_mc.r")
source("C:\\TEMP\\example_flow_metrics.r")
```

(Hint: Dragging the .r file from a Windows explorer window to the R window has the effect of running the Source command).

sourceRy uses the R package ‘SNOW’, which supports parallel processing on one or more machines. This package must be separately installed:

1.	In R-Console, use the Packages|Install Package(s)… menu
1.	Select an appropriate mirror of the R archive (CRAN): Usually the Canberra or Melbourne mirror will be best for Australian users
1.	Scroll down the list of packages to snow and click OK
1.	R will download snow as well as a series of package dependencies. This may take a few minutes.
1.	Once snow (and all of its dependencies) has been installed, you should see a message on the R-Console similar to:

```
package ‘snow’ successfully unpacked and MD5 sums checked
The downloaded binary packages are in
        C:\...\Temp\RtmpKOEu48\downloaded_packages
```
6.	Run a quick test of snow from the R prompt:

```R
library(snow)
cluster <- makeCluster(rep(“localhost”,10),type=”SOCK”)
clusterApply(cluster,1:100,get(“+”),3)
stopCluster(cluster)
```

**Note: It’s highly likely that the above example will first produce a Windows firewall warning to tell you that R has requested the ability to accept incoming network connections. Incoming network connections are required to use snow (which remains one of the simplest ways to do parallel processing in R, even for a single machine).**

## Setting Up the Source Execution Environment

### Starting Source Servers

The Source external interface will be run in client-server mode, allowing each parallel instance running as a long-lived process so that we can load the Source model (rsproj file) once per instance.

Its common for Source users to have multiple versions installed at any one time. Tell R which version of Source you’re using before starting up the various instances.
```R
configure_for_source_version("3.0.7.31")
end_points = start_source_servers(6)
work_with(end_points)
```

Notes:

* If configure_for_source_version or start_source_server fail, it’s probably because Source is installed somewhere non-standard. You can replace call to `configure_for_source_version` with a call to `configure_source`. For example, if Source is installed on D-drive:
```R
configure_source(“D:\\Program Files\\eWater\\Source 3.0.7.31”)
```
* As with R/snow earlier, you may get a Windows firewall warning here about RiverSystem.CommandLine needing to accept incoming network connections. This is necessary and carries the same warnings as for R/snow.
* Once you’ve started the Source servers with start_source_servers, there is no way from within R to shut them down (at this point). You’ll need to do that from the Processes tab of Task Manager (Start|Run|taskmgr).
* The number of servers you start should match the number of CPU cores you have available locally. For example, Intel i7s usually have 4 CPU cores (though some only have 2 and some have 6). If you have less servers than you have cores, then you won’t use all the available computing power. If you have more servers than cores, then you can lose performance from Windows trying to manage multiple jobs.
* We use the server mode of RiverSystem.CommandLine in order to save the load time. With the server, we load the .rsproj file once onto each server and reuse it multiple times.
* The `start_source_servers` function is a convenience for starting multiple instances of Source on one machine. You could run this function on multiple machines in order to distribute runs. At this stage you need to manually communicate the list of end-points back to the main machine which will be used to coordinate model runs.

### Create snow Cluster
The snow cluster coordinates the parallel runs. R, by its nature, is not a parallel processing system. snow essentially sets up multiple instances of R, on the one machine or across the network, and provides a means for these instances to communicate. snow is a helper for us in running parallel jobs.

```R
cluster = source_helper_cluster()
```

** Note: At this stage, the source_helper_cluster function creates the cluster on one machine, even if you have created Source servers on other machines. **

## Deterministic and Stochastic Scenarios

sourceRy is configured to run a series of deterministic scenarios (defined by sets of values for global expressions), with each scenario run for multiple replicates defined by sampling a different set of global expressions. Both the deterministic and the stochastic (monte-carlo) aspects of the scenarios are defined in R, with convenience functions provided for capturing this information is csv files and the like.

## Defining the Monte-Carlo Parameters

Sampling of stochastic parameters happens at runtime by calling a user defined sampling function. This sampling function should accept a single parameter, sample_size, through which will be passed the specified number of replicates required.

The sampling function returns a matrix, with each column representing a sampling parameter and each row representing a replicate. The columns should carry the name of the corresponding global expression in the Source model.

The following example is for a single stochastic parameter, to be used with a Source model that defines a $PET_SCALE global expression.
```R
sample_evap <- function(sample_size){
	PET_SCALE = pmax(rnorm(sample_size,mean=1,sd=0.2),0.0)
	cbind(PET_SCALE)
}
```

Notes:
* Note the use of the R function rnorm, which generates random deviates of a normal distribution. rnorm (along with generators for other distributions) accept the number of values as the first parameter, followed by distribution parameters.
* Note also the use of the pmax function, which we use here to cap the random values with a lower bound of 0.0

This technique can equally work for multiple Monte-Carlo variables

```R
sample_climate <- function(sample_size){
	PET_SCALE = pmax(rnorm(sample_size,mean=1,sd=0.2),0.0)
	RAIN_SCALE = pmax(rnorm(sample_size,mean=1,sd=0.1),0.0)
	cbind(PET_SCALE,RAIN_SCALE)
}
```

### Defining Many Monte-Carlo Parameters

The sampling function can use any logic in order to come up with a matrix of variables and replicates. It can be convenient, for example, to put some of the information about the Monte-Carlo parameters into a separate file, and have the sampling function read and process this file.

For example, consider the situation where you need to sample a series of variables, with each variable being sampled around its current estimated value. In this case, the variable names and estimated values could be placed in a CSV file:

```
Variable,Estimated
ExportUrban,5.76
ExportGrazing,7.61
ExportForest,3.91
ExportIrrigation,6.0
```

The sampling function could then read this file, using the first column as the variable name and the second column as the mean in a distribution:

```R
sample_export <- function(sample_size){
	estimated_exports = read.table("C:\\TEMP\\ExportValues.csv"),header=TRUE,sep=",",quote=NULL)
	
	sampled_parameters = NULL
	for(i in 1:nrow(estimated_exports)){
		samples = estimated_exports [i,2]*pmin(pmax(rnorm(sample_size,mean=1.0,sd=0.25),0.5),1.5)
		sampled_parameters = cbind(sampled_parameters,samples)
	}
	colnames(sampled_parameters) <- estimated_exports [,1]
	sampled_parameters
}
```

Notes:
* read.table is a flexible built-in function for reading tabular text files, in this case the CSV file with a one row header
* colnames is used to give column names to the matrix. This explicit call was necessary because the of the way the matrix was constructed. The column names were automatically assigned in the earlier examples.

## Defining the Fixed Scenarios

The stochastic module is typically used to run a number of scenarios, with each scenario being run across a set of stochastic replicates. This gives the ability to compare the range of results for each scenario.

These fixed scenarios are defined using a matrix, with each row representing a scenario. The first column of the matrix is the scenario number (integer or decimal) and the second and subsequent columns represent global expressions in the Source model. This matrix can generated in R, or stored in a CSV file, such as:

```
Scenario,WaterUse1,WaterUse2,WaterUse3,WaterUse4,MinFlowSummer,MinFlowAutumn,MinFlowWinter,MinFlowSpring,
2,0,0,0,0,0,0,0,0
3,1.006,0.056,0.082,0.027,0.037,0.127,0.097,0.017
4,0,0.056,0,0,0,0.127,0.097,0.017
5,1.006,0.056,0.082,0,0,0.127,0.097,0
6.1,1.006,0,0.082,0,0,0.127,0,0
6.2,1.006,0.056,0.082,0,0.037,0.127,0.097,0
7.1,1.006,0,0,0,0,0.127,0,0
7.2,1.006,0.056,0.082,0,0,0.127,0.097,0
```

and loaded into R:

```R
scenario_definitions = read.csv("C:\\TEMP\\Scenarios.csv",header=TRUE,quote=NULL)
```

## Specifying the Metrics
sourceRy will calculate user defined metrics, for a specified output from Source, for each replicate of each scenario.

The statistics is provided as a function, accepting a ts_results parameter, which will be an R list containing the time series from a single replicate. The ts_results list will contain entries for the values of the timeseries ($vals), along with the date, both as a single value ($Date) and with separate Year ($Year), Month ($Month) and Season ($Season) values.

A simple metrics function, using just the values of the time series to compute mean daily flow is shown:

```R
flow_statistics <- function(ts_results) {
	results = NULL
	results = as.matrix(c(mean(ts_results$vals)))
	colnames(results) <- c("mean_daily_flow")
	results
}
```

Notes:
* The example_flow_metrics module contains seasonal_flow_statistics as a comprehensive example with numerous seasonal statistics
* Both the names and the corresponding months of the Seasons can be user defined. The easiest way is to supply a CSV file and use the configure_seasons function:

```
Month,Season
1,Summer
2,Summer
3,Autumn
4,Autumn
5,Autumn
6,Winter
7,Winter
8,Winter
9,Spring
10,Spring
11,Spring
12,Summer
```

```R
configure_seasons("C:\\TEMP\\seasons.csv"))
```

## Steps for running and summarising results

The `source_mc` function runs the entire Monte-Carlo process. Specifically:

* Runs each of the fixed scenarios (#scenarios) for each of the replicates (#replicates)
* Calculates all the metrics for each model run (#scenarios x #replicates)
* Calculates summary statistics across each scenario (#replicates)
* Creates box plots across the scenarios for each metrics

The function requires numerous parameters:

* cluster: The Snow cluster, configured above
* project: The path on disk to the Source project
* results_base: A base folder for all results
* results_id: A string representing the analysis, to separate results in the base folder. This typically represents the variables being sampled in the Monte-Carlo (eg ‘Climate’)
* scenarios: A matrix of the fixed scenarios (see above)
* sampler: A reference to the sampling function (see above)
* nRuns: The number of replicates in each Monte-Carlo analysis (#replicates). Total number of runs will be this number multiplied by the number of distinct scenarios
* stats_fn: A reference to the metrics function (see above)

```R
source_mc(
cluster,
"C:\\TEMP\\Source_Model.rsproj",
"C:\\TEMP\\Results",
"Climate",
scenario_definitions,
sample_climate,
1000,
seasonal_flow_statistics)
```

After the run, the results folder (in this case, C:\TEMP\Results\Climate) will contain:
* boxplots.pdf (containing boxplots of each metrics, across each scenario)
* boxplot_*.csv (containing the values from the box plot for each metric)
* Scenario* subfolders (containing the time series results)

### Feedback

Feedback, suggestions and contributions are all very welcome!

## Licencse

The Source FEWS Adapter is licensed under the [LGPLv3]

[source]: http://www.ewater.com.au/products/ewater-source/
[LGPLv3]: http://www.gnu.org/copyleft/lesser.html
