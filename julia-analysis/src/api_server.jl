function run_server(host="0.0.0.0", port=8090)
    router = HTTP.Router()
    HTTP.@register(router, "POST", "/analyze/anomalies", handle_anomaly)
    HTTP.@register(router, "POST", "/analyze/attestations", handle_attestation)
    HTTP.@register(router, "POST", "/analyze/similarity", handle_similarity)
    HTTP.@register(router, "GET", "/health", handle_health)
    println("Analysis server starting on $host:$port")
    HTTP.serve(router, host, port)
end

function parse_json_body(req::HTTP.Request)
    body = String(req.body)
    isempty(body) && return Dict{String,Any}()
    return JSON.parse(body)
end

function make_response(data::Dict, status=200)
    return HTTP.Response(status, ["Content-Type" => "application/json"], JSON.json(data))
end

function make_error(message::String, status=400)
    return HTTP.Response(status, ["Content-Type" => "application/json"], JSON.json(Dict("error" => message)))
end

function handle_anomaly(req::HTTP.Request)
    try
        data = parse_json_body(req)
        haskey(data, "devices") || return make_error("Missing 'devices' field")
        result = detect_anomalies(data["devices"])
        return make_response(Dict("anomalies" => result))
    catch e
        return make_error("Anomaly detection failed: $(sprint(showerror, e))", 500)
    end
end

function handle_attestation(req::HTTP.Request)
    try
        data = parse_json_body(req)
        haskey(data, "attestations") || return make_error("Missing 'attestations' field")
        result = analyze_attestations(data["attestations"])
        return make_response(Dict("analysis" => result))
    catch e
        return make_error("Attestation analysis failed: $(sprint(showerror, e))", 500)
    end
end

function handle_similarity(req::HTTP.Request)
    try
        data = parse_json_body(req)
        haskey(data, "fingerprints") || return make_error("Missing 'fingerprints' field")
        haskey(data, "target") || return make_error("Missing 'target' field")
        k = get(data, "k", 5)
        result = find_similar_devices(data["target"], data["fingerprints"], k)
        return make_response(Dict("similar_devices" => result))
    catch e
        return make_error("Similarity search failed: $(sprint(showerror, e))", 500)
    end
end

function handle_health(req::HTTP.Request)
    return make_response(Dict(
        "status" => "ok",
        "service" => "zk-device-analysis",
        "version" => "0.1.0"
    ))
end
