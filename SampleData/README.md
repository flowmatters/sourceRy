# Sample Data for SourceRy

## YieldExample.rsproj

Simple Source model, built in 3.4.3.540.

Four nodes in series. From top:
* Inflow  - driven by time series (average ~186GL/yr)
* Storage - capacity 100GL
* Supply Point
* Demand - 60GL/yr based on monthly pattern

In addition to the base nodes and parameters, there are two scaling factors
* InflowScalingFactor = 1
* DemandScaling = 1

These can both be manipulated from SourceRy

## DiscreteScenarios.csv

Definition of various demand scenarios (the DemandScaling variable). Each row represents a scenario and each column represents a variable to modify in a scenario.

These scenarios get combined with randomised sampling of the InflowScalingFactor variable in the tutorial.
