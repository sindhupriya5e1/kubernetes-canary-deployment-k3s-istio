const http = require("http");
const version = process.env.APP_VERSION || "stable";
const port = Number(process.env.PORT || 3000);
const requests = new Map();

function record(method, status) {
  const key = [version, method, status].join("|");
  requests.set(key, (requests.get(key) || 0) + 1);
}

function metrics() {
  const lines = [
    "# HELP canary_http_requests_total Total HTTP requests handled by this application.",
    "# TYPE canary_http_requests_total counter"
  ];
  for (const [key, count] of requests) {
    const [appVersion, method, status] = key.split("|");
    lines.push(`canary_http_requests_total{version="${appVersion}",method="${method}",status="${status}"} ${count}`);
  }
  return lines.join("\n") + "\n";
}

http.createServer((req, res) => {
  if (req.url === "/metrics") {
    res.writeHead(200, { "content-type": "text/plain; version=0.0.4; charset=utf-8" });
    return res.end(metrics());
  }

  let status = 200;
  let body;
  if (req.url === "/health") {
    body = { status: "ok", version };
  } else if (req.url === "/") {
    body = {
      message: "K3s + Istio canary demo",
      version,
      timestamp: new Date().toISOString()
    };
  } else {
    status = 404;
    body = { error: "not found", path: req.url };
  }

  record(req.method, status);
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify(body));
}).listen(port, "0.0.0.0", () => {
  console.log(`canary demo listening on ${port}; version=${version}`);
});
