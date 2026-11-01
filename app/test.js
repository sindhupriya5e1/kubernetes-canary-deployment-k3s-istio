const assert = require("node:assert/strict");
const { spawn } = require("node:child_process");

const port = 3100 + Math.floor(Math.random() * 1000);
const baseUrl = `http://127.0.0.1:${port}`;
const child = spawn(process.execPath, ["server.js"], {
  cwd: __dirname,
  env: { ...process.env, PORT: String(port), APP_VERSION: "canary" },
  stdio: ["ignore", "ignore", "inherit"]
});

async function waitForServer() {
  for (let attempt = 0; attempt < 40; attempt += 1) {
    try {
      const response = await fetch(`${baseUrl}/health`);
      if (response.ok) return;
    } catch {}
    await new Promise(resolve => setTimeout(resolve, 150));
  }
  throw new Error("Application did not become ready in time");
}

(async () => {
  try {
    await waitForServer();

    const health = await fetch(`${baseUrl}/health`);
    assert.equal(health.status, 200);
    assert.deepEqual(await health.json(), { status: "ok", version: "canary" });

    const home = await fetch(baseUrl);
    assert.equal(home.status, 200);
    assert.equal((await home.json()).version, "canary");

    const missing = await fetch(`${baseUrl}/missing`);
    assert.equal(missing.status, 404);

    const metrics = await fetch(`${baseUrl}/metrics`);
    assert.equal(metrics.status, 200);
    const metricsText = await metrics.text();
    assert.match(metricsText, /canary_http_requests_total/);
    assert.match(metricsText, /version="canary"/);
    assert.match(metricsText, /status="404"/);

    process.stdout.write("Application tests passed: health, home, 404 and Prometheus metrics.\\n");
  } finally {
    child.kill("SIGTERM");
  }
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
