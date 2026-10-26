const http = require("http");
const version = process.env.APP_VERSION || "stable";
const port = Number(process.env.PORT || 3000);

http.createServer((req, res) => {
  if (req.url === "/health") {
    res.writeHead(200, { "content-type": "application/json" });
    return res.end(JSON.stringify({ status: "ok", version }));
  }
  if (req.url === "/") {
    res.writeHead(200, { "content-type": "application/json" });
    return res.end(JSON.stringify({
      message: "K3s + Istio canary demo",
      version,
      timestamp: new Date().toISOString()
    }));
  }
  res.writeHead(404, { "content-type": "application/json" });
  res.end(JSON.stringify({ error: "not found", path: req.url }));
}).listen(port, "0.0.0.0", () => {
  console.log(`canary demo listening on ${port}; version=${version}`);
});
