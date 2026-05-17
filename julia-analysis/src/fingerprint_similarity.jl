function find_similar_devices(target::Vector{Float64}, all_fingerprints::Matrix{Float64}, k::Int=5)
    n = size(all_fingerprints, 2)
    n == 0 && return Dict{String,Any}("neighbors" => [], "note" => "No fingerprints provided")

    target_norm = norm(target)
    if target_norm == 0.0
        return Dict{String,Any}("neighbors" => [], "note" => "Target fingerprint is zero vector")
    end

    similarities = Vector{Tuple{Int,Float64,Float64}}()
    for i in 1:n
        fp = all_fingerprints[:, i]
        cs = cosine_similarity(target, fp)
        ed = euclidean_distance(target, fp)
        push!(similarities, (i, cs, ed))
    end

    sort!(similarities, by = t -> t[2], rev = true)

    k_actual = min(k, n)
    neighbors = Vector{Dict{String,Any}}()
    for i in 1:k_actual
        idx, cs, ed = similarities[i]
        push!(neighbors, Dict{String,Any}(
            "index" => idx,
            "cosine_similarity" => round(cs, digits=6),
            "euclidean_distance" => round(ed, digits=6)
        ))
    end

    if k_actual < k
        push!(neighbors, Dict{String,Any}("note" => "Requested k=$k but only $k_actual fingerprints available"))
    end

    return Dict{String,Any}(
        "neighbors" => neighbors,
        "k_requested" => k,
        "k_returned" => k_actual,
        "total_fingerprints" => n
    )
end

function cosine_similarity(a::Vector{Float64}, b::Vector{Float64})
    dot_val = dot(a, b)
    norm_a = norm(a)
    norm_b = norm(b)
    if norm_a == 0.0 || norm_b == 0.0
        return 0.0
    end
    return dot_val / (norm_a * norm_b)
end

function euclidean_distance(a::Vector{Float64}, b::Vector{Float64})
    return sqrt(sum((a - b) .^ 2))
end

function cluster_devices(fingerprints::Matrix{Float64}, n_clusters::Int=3; max_iters::Int=200)
    n_features, n_samples = size(fingerprints)
    n_samples == 0 && return Dict{String,Any}("clusters" => [], "note" => "No fingerprints provided")

    k = min(n_clusters, n_samples)

    result = kmeans(fingerprints, k; max_iter=max_iters)

    clusters = Vector{Dict{String,Any}}()
    for i in 1:k
        members = findall(assignments(result) .== i)
        centroid = result.centers[:, i]
        push!(clusters, Dict{String,Any}(
            "cluster_id" => i,
            "size" => length(members),
            "members" => members,
            "centroid" => round.(centroid, digits=6)
        ))
    end

    silhouette = compute_silhouette(fingerprints, assignments(result))

    return Dict{String,Any}(
        "clusters" => clusters,
        "n_clusters" => k,
        "n_samples" => n_samples,
        "iterations" => result.iterations,
        "total_withinss" => round(result.totalwithin, digits=6),
        "silhouette_score" => round(silhouette, digits=6)
    )
end

function compute_silhouette(data::Matrix{Float64}, assignments::Vector{Int})
    n = size(data, 2)
    n < 2 && return 1.0
    k = length(unique(assignments))
    k == 1 && return 0.0

    scores = Float64[]
    for i in 1:n
        a_i = mean_intra_distance(data, assignments, i)
        b_i = mean_nearest_cluster_distance(data, assignments, i)
        denom = max(a_i, b_i)
        denom > 0 && push!(scores, (b_i - a_i) / denom)
    end
    length(scores) == 0 && return 0.0
    return mean(scores)
end

function mean_intra_distance(data::Matrix{Float64}, assignments::Vector{Int}, i::Int)
    cluster = assignments[i]
    members = findall(assignments .== cluster)
    n = length(members)
    n <= 1 && return 0.0
    total_dist = 0.0
    for j in members
        j == i && continue
        total_dist += euclidean_distance(data[:, i], data[:, j])
    end
    return total_dist / (n - 1)
end

function mean_nearest_cluster_distance(data::Matrix{Float64}, assignments::Vector{Int}, i::Int)
    own_cluster = assignments[i]
    clusters = unique(assignments)
    best_dist = Inf
    for c in clusters
        c == own_cluster && continue
        members = findall(assignments .== c)
        total_dist = sum(euclidean_distance(data[:, i], data[:, j]) for j in members)
        mean_dist = total_dist / length(members)
        mean_dist < best_dist && (best_dist = mean_dist)
    end
    return best_dist == Inf ? 0.0 : best_dist
end

function find_similar_devices(target::Vector, all_fingerprints::Vector{Vector}, k::Int=5)
    fp_vec = Float64.(target)
    n = length(all_fingerprints)
    n == 0 && return Dict{String,Any}("neighbors" => [], "note" => "No fingerprints provided")

    matrix = zeros(length(fp_vec), n)
    for (i, fp) in enumerate(all_fingerprints)
        matrix[:, i] = Float64.(fp)
    end

    return find_similar_devices(fp_vec, matrix, k)
end

function find_similar_devices(target::Dict{String,Any}, all_fingerprints::Vector{Dict{String,Any}}, k::Int=5)
    target_fp = get_fingerprint_vector(target)
    all_fps = [get_fingerprint_vector(fp) for fp in all_fingerprints]
    return find_similar_devices(target_fp, all_fps, k)
end

function get_fingerprint_vector(d::Dict{String,Any})
    if haskey(d, "fingerprint")
        return Float64.(d["fingerprint"])
    elseif haskey(d, "features")
        return Float64.(d["features"])
    elseif haskey(d, "vector")
        return Float64.(d["vector"])
    end
    vals = [v for (k, v) in d if v isa Number]
    return Float64.(vals)
end

function cluster_devices(fingerprints::Vector{Vector{Float64}}, n_clusters::Int=3)
    n = length(fingerprints)
    n == 0 && return Dict{String,Any}("clusters" => [], "note" => "No fingerprints provided")

    dims = length(fingerprints[1])
    matrix = zeros(dims, n)
    for (i, fp) in enumerate(fingerprints)
        matrix[:, i] = fp
    end

    return cluster_devices(matrix, n_clusters)
end
