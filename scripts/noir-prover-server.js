const http = require("http");
const { resolve } = require("path");
const {
  UltraHonkBackend,
} = require("@noir-lang/backend_barretenberg");
const { Noir } = require("@noir-lang/noirjs");

const PORT = parseInt(process.env.PORT || "3001", 10);
const CIRCUITS_DIR = process.env.CIRCUITS_DIR || resolve(__dirname, "..", "circuits");

async function loadCircuit(circuitPath) {
  const fs = require("fs");
  const path = require("path");
  const circuitDir = path.resolve(CIRCUITS_DIR, circuitPath);
  const circuitJson = JSON.parse(
    fs.readFileSync(path.join(circuitDir, "target", "circuit.json"), "utf-8")
  );
  return circuitJson;
}

async function generateProof(circuitName, inputs) {
  const circuit = await loadCircuit(circuitName);
  const backend = new UltraHonkBackend(circuit.bytecode);
  const noir = new Noir(circuit);
  const proof = await noir.generateProof(inputs);
  await backend.destroy();
  return { proof: proof.proof, publicInputs: proof.publicInputs };
}

async function verifyProof(circuitName, proofData) {
  const circuit = await loadCircuit(circuitName);
  const backend = new UltraHonkBackend(circuit.bytecode);
  const noir = new Noir(circuit);
  const isValid = await noir.verifyProof(proofData);
  await backend.destroy();
  return { isValid };
}

function parseBody(req) {
  return new Promise((resolve, reject) => {
    let body = "";
    req.on("data", (chunk) => (body += chunk));
    req.on("end", () => {
      try {
        resolve(JSON.parse(body));
      } catch {
        reject(new Error("Invalid JSON"));
      }
    });
    req.on("error", reject);
  });
}

function sendJSON(res, status, data) {
  res.writeHead(status, { "Content-Type": "application/json" });
  res.end(JSON.stringify(data));
}

const server = http.createServer(async (req, res) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    res.writeHead(204);
    res.end();
    return;
  }

  try {
    const url = new URL(req.url, `http://${req.headers.host}`);
    const path = url.pathname;

    if (req.method === "GET" && path === "/health") {
      return sendJSON(res, 200, {
        status: "ok",
        service: "noir-prover",
        version: "0.1.0",
      });
    }

    if (req.method === "POST" && path === "/prove") {
      const body = await parseBody(req);
      const { circuit, inputs } = body;
      if (!circuit) return sendJSON(res, 400, { error: "Missing 'circuit' field" });
      if (!inputs) return sendJSON(res, 400, { error: "Missing 'inputs' field" });
      const result = await generateProof(circuit, inputs);
      return sendJSON(res, 200, result);
    }

    if (req.method === "POST" && path === "/verify") {
      const body = await parseBody(req);
      const { circuit, proof } = body;
      if (!circuit) return sendJSON(res, 400, { error: "Missing 'circuit' field" });
      if (!proof) return sendJSON(res, 400, { error: "Missing 'proof' field" });
      const result = await verifyProof(circuit, proof);
      return sendJSON(res, 200, result);
    }

    sendJSON(res, 404, { error: "Not found" });
  } catch (err) {
    console.error("Server error:", err);
    sendJSON(res, 500, { error: err.message });
  }
});

server.listen(PORT, () => {
  console.log(`Noir prover server listening on port ${PORT}`);
});
