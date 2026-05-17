function analyze_attestations(attestations::Vector{Dict{String,Any}})
    length(attestations) == 0 && return Dict{String,Any}(
        "total_attestations" => 0,
        "statistics" => nothing,
        "patterns" => nothing,
        "anomalies" => []
    )

    df = DataFrame(attestations)

    parsed = parse_attestation_times(df)

    stats = compute_attestation_statistics(parsed)

    patterns = analyze_attestation_patterns(parsed)

    anomalies = detect_pattern_anomalies(parsed, stats)

    return Dict{String,Any}(
        "total_attestations" => nrow(parsed),
        "unique_devices" => length(unique(parsed.device_id)),
        "time_range" => build_time_range(parsed),
        "statistics" => stats,
        "patterns" => patterns,
        "anomalies" => anomalies
    )
end

function parse_attestation_times(df::DataFrame)
    result = DataFrame(
        device_id = String[],
        timestamp = DateTime[],
        proof_type = String[],
        status = String[]
    )

    for row in eachrow(df)
        did = string(get(row, :device_id, get(row, :id, "unknown")))
        ts_str = string(get(row, :timestamp, get(row, :time, get(row, :created_at, ""))))
        ts = parse_datetime(ts_str)
        pt = string(get(row, :proof_type, get(row, :type, "unknown")))
        st = string(get(row, :status, get(row, :state, "unknown")))
        push!(result, (did, ts, pt, st))
    end

    return result
end

function parse_datetime(s::AbstractString)
    isempty(s) && return now()
    for fmt in ["yyyy-mm-dd HH:MM:SS", "yyyy-mm-ddTHH:MM:SS", "yyyy-mm-ddTHH:MM:SS.sssZ",
                 "yyyy-mm-dd", "dd/mm/yyyy HH:MM:SS", "yyyy/mm/dd"]
        try
            return DateTime(s, fmt)
        catch
            continue
        end
    end
    return now()
end

function compute_attestation_statistics(df::DataFrame)
    by_device = groupby(df, :device_id)

    device_stats = Dict{String,Any}()
    for group in by_device
        did = first(group.device_id)
        n = nrow(group)
        if n < 2
            device_stats[did] = Dict{String,Any}(
                "count" => n,
                "mean_interval" => nothing,
                "median_interval" => nothing,
                "std_interval" => nothing,
                "min_interval" => nothing,
                "max_interval" => nothing
            )
            continue
        end
        times = sort(group.timestamp)
        intervals = [Dates.value(times[i+1] - times[i]) / 1000.0 for i in 1:length(times)-1]
        device_stats[did] = Dict{String,Any}(
            "count" => n,
            "mean_interval" => round(mean(intervals), digits=4),
            "median_interval" => round(median(intervals), digits=4),
            "std_interval" => round(std(intervals), digits=4),
            "min_interval" => round(minimum(intervals), digits=4),
            "max_interval" => round(maximum(intervals), digits=4)
        )
    end

    all_intervals = Float64[]
    for (_, s) in device_stats
        s["mean_interval"] !== nothing && push!(all_intervals, s["mean_interval"])
    end

    global_stats = Dict{String,Any}()
    if length(all_intervals) > 0
        global_stats["mean_interval_across_devices"] = round(mean(all_intervals), digits=4)
        global_stats["std_interval_across_devices"] = round(std(all_intervals), digits=4)
        global_stats["min_interval_across_devices"] = round(minimum(all_intervals), digits=4)
        global_stats["max_interval_across_devices"] = round(maximum(all_intervals), digits=4)
    end

    proof_types = combine(groupby(df, :proof_type), nrow => :count)
    status_dist = combine(groupby(df, :status), nrow => :count)

    return Dict{String,Any}(
        "per_device" => device_stats,
        "global" => global_stats,
        "proof_type_distribution" => Dict{String,Int}(pairs(proof_types)),
        "status_distribution" => Dict{String,Int}(pairs(status_dist))
    )
end

function analyze_attestation_patterns(df::DataFrame)
    if nrow(df) < 2
        return Dict{String,Any}("note" => "Insufficient data for pattern analysis")
    end

    time_windows = determine_time_windows(df)

    windowed_counts = Dict{String,Vector{Dict{String,Any}}}()
    for (window_name, window_fn) in time_windows
        counts = Dict{String,Int}()
        for row in eachrow(df)
            bucket = window_fn(row.timestamp)
            counts[bucket] = get(counts, bucket, 0) + 1
        end
        windowed_counts[window_name] = [
            Dict{String,Any}("window" => k, "count" => v) for (k, v) in sort(counts)
        ]
    end

    hourly = windowed_counts["hourly"]
    if length(hourly) > 1
        hourly_counts = [h["count"] for h in hourly]
        mu = mean(hourly_counts)
        sigma = std(hourly_counts)
        for h in hourly
            dev = sigma > 0 ? (h["count"] - mu) / sigma : 0.0
            h["zscore"] = round(dev, digits=4)
        end
    end

    device_freq = combine(groupby(df, :device_id), nrow => :total)
    freq_stats = Dict{String,Any}()
    if nrow(device_freq) > 0
        totals = device_freq.total
        freq_stats["mean"] = round(mean(totals), digits=4)
        freq_stats["std"] = round(std(totals), digits=4)
        freq_stats["min"] = minimum(totals)
        freq_stats["max"] = maximum(totals)
        freq_stats["median"] = round(median(totals), digits=4)
    end

    return Dict{String,Any}(
        "time_series" => windowed_counts,
        "device_frequency" => freq_stats,
        "total_devices_active" => length(unique(df.device_id))
    )
end

function determine_time_windows(df::DataFrame)
    if nrow(df) < 2
        return Dict{String,Any}()
    end
    times = df.timestamp
    span = maximum(times) - minimum(times)
    windows = Dict{String,Any}()
    if Dates.value(span) < 3_600_000_000
        windows["hourly"] = dt -> Dates.format(dt, "yyyy-mm-ddTHH:00:00")
    end
    if Dates.value(span) < 86_400_000_000
        windows["hourly"] = dt -> Dates.format(dt, "yyyy-mm-ddTHH:00:00")
    end
    windows["daily"] = dt -> Dates.format(dt, "yyyy-mm-dd")
    windows["weekly"] = dt -> Dates.format(Dates.value(dt) >= 4 ? dt - Day(dayofweek(dt) - 1) : dt, "yyyy-mm-dd")
    return windows
end

function build_time_range(df::DataFrame)
    nrow(df) == 0 && return Dict{String,Any}("start" => nothing, "end" => nothing)
    return Dict{String,Any}(
        "start" => Dates.format(minimum(df.timestamp), "yyyy-mm-ddTHH:MM:SS"),
        "end" => Dates.format(maximum(df.timestamp), "yyyy-mm-ddTHH:MM:SS")
    )
end

function detect_pattern_anomalies(df::DataFrame, stats::Dict{String,Any})
    anomalies = Vector{Dict{String,Any}}()
    device_counts = combine(groupby(df, :device_id), nrow => :count)

    if nrow(device_counts) > 2
        counts = device_counts.count
        mu = mean(counts)
        sigma = std(counts)
        for row in eachrow(device_counts)
            if sigma > 0 && abs(row.count - mu) / sigma > 3
                push!(anomalies, Dict{String,Any}(
                    "device_id" => row.device_id,
                    "type" => "attestation_frequency_anomaly",
                    "count" => row.count,
                    "zscore" => round((row.count - mu) / sigma, digits=4),
                    "mean" => round(mu, digits=4)
                ))
            end
        end
    end

    if haskey(stats, "per_device")
        for (did, dstats) in stats["per_device"]
            dstats_dict = dstats
            if haskey(dstats_dict, "std_interval") && dstats_dict["std_interval"] !== nothing
                cv = dstats_dict["mean_interval"] > 0 ? dstats_dict["std_interval"] / dstats_dict["mean_interval"] : 0.0
                if cv > 2.0
                    push!(anomalies, Dict{String,Any}(
                        "device_id" => did,
                        "type" => "irregular_attestation_interval",
                        "cv" => round(cv, digits=4),
                        "mean_interval" => dstats_dict["mean_interval"],
                        "std_interval" => dstats_dict["std_interval"]
                    ))
                end
            end
        end
    end

    return anomalies
end

function analyze_attestations(attestation_data::Dict{String,Any})
    if haskey(attestation_data, "attestations")
        return analyze_attestations(attestation_data["attestations"])
    end
    return analyze_attestations([attestation_data])
end
