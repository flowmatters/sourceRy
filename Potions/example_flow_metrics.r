
calculate_stats_for_season <- function(season,results) {
	in_season =  results$Season==season
	num_years = 1 + as.numeric(rev(results$Year)[1])-as.numeric(results$Year[1])
	indices = which(in_season)
	season_flows = results$vals[indices]
	non_zero_season_flows = season_flows[which(season_flows>0.0)]
	median_non_zero = median(non_zero_season_flows)

	is.season.fresh = in_season & (results$vals>(2.0*median_non_zero))
	unique_freshes = rle(is.season.fresh)
	num_freshes = length(which(unique_freshes$values))
	fresh_ave_duration = ifelse(num_freshes==0,0,mean(unique_freshes$lengths[which(unique_freshes$values)]))
	
	mean_daily = mean(season_flows)
	pc80exc_non_zero = quantile(non_zero_season_flows,0.2)[1]
	years_with_zero = length(unique(results$Year[intersect(which(results$vals==0.0),indices)]))
	years_with_freshes = length(unique(results$Year[which(is.season.fresh)]))
	average_freshes_per_year = num_freshes / num_years
	
	results = c(mean_daily,pc80exc_non_zero,years_with_zero,years_with_freshes,average_freshes_per_year,fresh_ave_duration)
	metric_names = c("mean_daily","80pc_exceedance_non0","years_with_zero","years_with_freshes","average_num_freshes_per_year","fresh_ave_duration")
	metric_names = paste(season,metric_names,sep="_")
    names(results) <- metric_names
	results
}

seasonal_flow_statistics <- function(ts_results) {
	results = NULL
	results = as.matrix(c(mean(ts_results$vals)))
	colnames(results) <- c("mean_daily_flow")
	
	for( s in seasonNames ) {
		results = c(results,calculate_stats_for_season(s,ts_results))
	}
	results
}

