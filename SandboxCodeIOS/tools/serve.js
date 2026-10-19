// Server tĩnh tối giản để Simulator trên Mac tải model/PLY từ PC Windows qua LAN.
// Chạy:  node tools\serve.js [thư-mục] [cổng]      (mặc định: Downloads, 8000)
// Rồi trong app iOS nhập  http://<ip-pc>:8000/ten-file.ply
const http = require("http");
const fs = require("fs");
const path = require("path");
const os = require("os");

const root = path.resolve(process.argv[2] || path.join(os.homedir(), "Downloads"));
const port = Number(process.argv[3] || 8000);

const types = {
  ".ply": "application/octet-stream",
  ".usdz": "model/vnd.usdz+zip",
  ".usd": "model/vnd.usd",
  ".usda": "model/vnd.usda",
  ".usdc": "model/vnd.usdc",
  ".obj": "text/plain",
  ".mtl": "text/plain",
  ".scn": "application/octet-stream",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
};

http.createServer((req, res) => {
  const urlPath = decodeURIComponent(new URL(req.url, "http://x").pathname);
  const file = path.join(root, urlPath);
  if (!file.startsWith(root)) { res.writeHead(403); return res.end("forbidden"); }

  fs.stat(file, (err, st) => {
    if (err) { res.writeHead(404); return res.end("not found: " + urlPath); }
    if (st.isDirectory()) {
      // Liệt kê thư mục để kiểm tra nhanh bằng Safari
      const items = fs.readdirSync(file).map((n) => `<li><a href="${encodeURIComponent(n)}">${n}</a></li>`).join("");
      res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
      return res.end(`<h3>${root}</h3><ul>${items}</ul>`);
    }
    res.writeHead(200, {
      "Content-Type": types[path.extname(file).toLowerCase()] || "application/octet-stream",
      "Content-Length": st.size,
      "Access-Control-Allow-Origin": "*",
    });
    fs.createReadStream(file).pipe(res);
    console.log(new Date().toLocaleTimeString(), req.socket.remoteAddress, urlPath, (st.size / 1048576).toFixed(1) + " MB");
  });
}).listen(port, "0.0.0.0", () => {
  const ips = Object.values(os.networkInterfaces()).flat()
    .filter((i) => i.family === "IPv4" && !i.internal).map((i) => i.address);
  console.log(`Đang phục vụ ${root}`);
  for (const ip of ips) console.log(`  http://${ip}:${port}/`);
});
