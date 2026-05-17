using ZkDeviceAnalysis
using Test

@testset "Anomaly Detection" begin
    devices = [
        Dict{String,Any}("device_id" => "dev-001", "attestation_count" => 100, "proof_count" => 50, "connection_frequency" => 10.0, "error_rate" => 0.01),
        Dict{String,Any}("device_id" => "dev-002", "attestation_count" => 95, "proof_count" => 48, "connection_frequency" => 9.5, "error_rate" => 0.02),
        Dict{String,Any}("device_id" => "dev-003", "attestation_count" => 500, "proof_count" => 250, "connection_frequency" => 50.0, "error_rate" => 0.50),
        Dict{String,Any}("device_id" => "dev-004", "attestation_count" => 102, "proof_count" => 52, "connection_frequency" => 10.5, "error_rate" => 0.015),
    ]

    result = detect_anomalies(devices)

    @test haskey(result, "flagged_devices")
    @test result["summary"]["total_devices"] == 4
    @test length(result["flagged_devices"]) > 0
    @test result["flagged_devices"][1]["device_id"] == "dev-003"
end

@testset "No Anomalies" begin
    devices = [
        Dict{String,Any}("device_id" => "dev-001", "attestation_count" => 100, "proof_count" => 50, "connection_frequency" => 10.0, "error_rate" => 0.01),
        Dict{String,Any}("device_id" => "dev-002", "attestation_count" => 102, "proof_count" => 51, "connection_frequency" => 10.5, "error_rate" => 0.02),
    ]

    result = detect_anomalies(devices)
    @test haskey(result, "flagged_devices")
end

@testset "Attestation Analysis" begin
    attestations = [
        Dict{String,Any}("device_id" => "dev-001", "timestamp" => "2026-01-01T10:00:00", "proof_type" => "dac", "status" => "valid"),
        Dict{String,Any}("device_id" => "dev-001", "timestamp" => "2026-01-01T11:00:00", "proof_type" => "pai", "status" => "valid"),
        Dict{String,Any}("device_id" => "dev-002", "timestamp" => "2026-01-01T10:30:00", "proof_type" => "dac", "status" => "valid"),
        Dict{String,Any}("device_id" => "dev-001", "timestamp" => "2026-01-01T12:00:00", "proof_type" => "paa", "status" => "invalid"),
    ]

    result = analyze_attestations(attestations)

    @test result["total_attestations"] == 4
    @test result["unique_devices"] == 2
    @test haskey(result, "statistics")
    @test haskey(result, "patterns")
end

@testset "Similar Devices" begin
    target = [1.0, 0.0, 1.0]
    fingerprints = [
        [1.0, 0.0, 1.0],
        [0.9, 0.1, 0.95],
        [0.0, 1.0, 0.0],
        [0.8, 0.2, 0.9],
    ]

    result = find_similar_devices(target, fingerprints, 3)

    @test result["k_returned"] == 3
    @test length(result["neighbors"]) == 3
    @test result["neighbors"][1]["cosine_similarity"] ≈ 1.0
end

@testset "Cosine Similarity Edge Cases" begin
    @test cosine_similarity([1.0, 0.0], [0.0, 1.0]) == 0.0
    @test cosine_similarity([0.0, 0.0], [1.0, 1.0]) == 0.0
    @test cosine_similarity([1.0, 0.0], [1.0, 0.0]) == 1.0
end

@testset "Euclidean Distance" begin
    @test euclidean_distance([0.0, 0.0], [3.0, 4.0]) == 5.0
    @test euclidean_distance([1.0, 2.0], [1.0, 2.0]) == 0.0
end

@testset "Clustering" begin
    fingerprints = [
        [1.0, 0.0],
        [1.1, 0.1],
        [0.0, 1.0],
        [0.1, 0.9],
        [5.0, 5.0],
        [5.1, 4.9],
    ]

    result = cluster_devices(fingerprints, 3)

    @test result["n_clusters"] == 3
    @test result["n_samples"] == 6
    @test length(result["clusters"]) == 3
    @test sum(c["size"] for c in result["clusters"]) == 6
end

@testset "Health Endpoint" begin
    req = HTTP.Request("GET", "/health")
    resp = handle_health(req)
    @test resp.status == 200
    body = JSON.parse(String(resp.body))
    @test body["status"] == "ok"
end

@testset "Empty Inputs" begin
    result = detect_anomalies(Dict{String,Any}[])
    @test result["summary"]["total_devices"] == 0

    result = analyze_attestations(Vector{Dict{String,Any}}[])
    @test result["total_attestations"] == 0

    result = find_similar_devices([1.0, 0.0], Matrix{Float64}(undef, 2, 0), 5)
    @test length(result["neighbors"]) == 0
end

println("All tests passed!")
