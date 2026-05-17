const ANOMALY_METRICS = ["attestation_count", "proof_count", "connection_frequency", "error_rate"]
const ZSCORE_THRESHOLD = 3.0
const IQR_MULTIPLIER = 1.5

function detect_anomalies(devices::Vector{Dict{String,Any}})
    length(devices) == 0 && return Dict{String,Any}("flagged_devices" => [], "summary" => Dict("total_devices" => 0))

    df = DataFrame(devices)
    metric_cols = filter(c -> c in ANOMALY_METRICS, names(df))
    length(metric_cols) == 0 && return Dict{String,Any}(
        "flagged_devices" => [],
        "summary" => Dict("total_devices" => length(devices), "note" => "No metric columns found")
    )

    device_ids = get_device_ids(df)

    zscore_results = compute_zscores(df, metric_cols)
    iqr_results = compute_iqr_outliers(df, metric_cols)

    all_flags = merge_flags(device_ids, zscore_results, iqr_results, metric_cols)

    flagged_devices = build_flagged_devices(device_ids, df, metric_cols, all_flags, zscore_results, iqr_results)

    return Dict{String,Any}(
        "flagged_devices" => flagged_devices,
        "summary" => Dict(
            "total_devices" => length(devices),
            "flagged_count" => length(flagged_devices),
            "metrics_analyzed" => metric_cols,
            "zscore_threshold" => ZSCORE_THRESHOLD,
            "iqr_multiplier" => IQR_MULTIPLIER
        )
    )
end

function get_device_ids(df::DataFrame)
    if "device_id" in names(df)
        return df.device_id
    elseif "id" in names(df)
        return df.id
    else
        return collect(1:nrow(df))
    end
end

function compute_zscores(df::DataFrame, metrics::Vector{Symbol})
    results = Dict{Symbol,Vector{Float64}}()
    for col in metrics
        vals = Float64.(skipmissing(df[!, col]))
        n = length(vals)
        if n < 2
            results[col] = zeros(n)
            continue
        end
        mu = mean(vals)
        sigma = std(vals)
        if sigma == 0.0
            results[col] = zeros(n)
        else
            results[col] = (vals .- mu) ./ sigma
        end
    end
    return results
end

function compute_iqr_outliers(df::DataFrame, metrics::Vector{Symbol})
    results = Dict{Symbol,Vector{Bool}}()
    for col in metrics
        vals = Float64.(skipmissing(df[!, col]))
        n = length(vals)
        if n < 4
            results[col] = falses(n)
            continue
        end
        sorted_vals = sort(vals)
        q1 = percentile(sorted_vals, 25)
        q3 = percentile(sorted_vals, 75)
        iqr_val = q3 - q1
        lower = q1 - IQR_MULTIPLIER * iqr_val
        upper = q3 + IQR_MULTIPLIER * iqr_val
        results[col] = [v < lower || v > upper for v in vals]
    end
    return results
end

function percentile(sorted_vals::Vector{Float64}, p::Int)
    n = length(sorted_vals)
    k = (p / 100) * (n - 1) + 1
    f = floor(Int, k)
    c = ceil(Int, k)
    if f == c
        return sorted_vals[f]
    end
    return sorted_vals[f] + (k - f) * (sorted_vals[c] - sorted_vals[f])
end

function merge_flags(device_ids, zscores::Dict{Symbol,Vector{Float64}}, iqr::Dict{Symbol,Vector{Bool}}, metrics::Vector{Symbol})
    n = length(device_ids)
    flag_counts = zeros(Int, n)
    for col in metrics
        z_vals = get(zscores, col, Float64[])
        iqr_vals = get(iqr, col, Bool[])
        for i in 1:n
            if i <= length(z_vals) && abs(z_vals[i]) > ZSCORE_THRESHOLD
                flag_counts[i] += 1
            end
            if i <= length(iqr_vals) && iqr_vals[i]
                flag_counts[i] += 1
            end
        end
    end
    return flag_counts
end

function build_flagged_devices(device_ids, df::DataFrame, metrics::Vector{Symbol},
                                flags::Vector{Int}, zscores::Dict{Symbol,Vector{Float64}},
                                iqr::Dict{Symbol,Vector{Bool}})
    flagged = Vector{Dict{String,Any}}()
    for i in 1:length(device_ids)
        flags[i] > 0 || continue
        did = device_ids[i]
        entry = Dict{String,Any}(
            "device_id" => did,
            "flag_count" => flags[i],
            "anomalies" => Dict{String,Any}()
        )
        for col in metrics
            col_str = string(col)
            z_val = get(zscores, col, Float64[])[i]
            iqr_val = get(iqr, col, Bool[])[i]
            row = Dict{String,Any}("zscore" => round(z_val, digits=4))
            if abs(z_val) > ZSCORE_THRESHOLD
                row["zscore_flagged"] = true
            end
            if iqr_val
                row["iqr_flagged"] = true
            end
            if get(row, "zscore_flagged", false) || get(row, "iqr_flagged", false)
                entry["anomalies"][col_str] = row
            end
        end
        push!(flagged, entry)
    end
    return flagged
end

function detect_anomalies(device_data::Dict{String,Any})
    devices = [Dict{String,Any}(k => v for (k, v) in device_data)]
    return detect_anomalies(devices)
end
