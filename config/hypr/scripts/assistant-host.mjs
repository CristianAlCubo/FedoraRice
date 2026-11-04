// Servidor local del asistente: sirve la web de Nexora y reenvía /api a la API (sin buffer, para SSE).
// Solo escucha en 127.0.0.1. Los endpoints /__desktop/* solo aceptan peticiones del mismo origen.
import { createServer, request } from 'node:http';
import { createReadStream, statSync } from 'node:fs';
import { extname, join, normalize, resolve } from 'node:path';
import { spawn } from 'node:child_process';

const PORT = Number(process.env.ASSISTANT_PORT ?? 5180);
const API = { host: '127.0.0.1', port: Number(process.env.API_PORT ?? 3187) };
const ROOT = resolve(process.env.ASSISTANT_WEB_DIST ?? '');
const SCRIPT = process.env.ASSISTANT_SCRIPT;
const TYPES = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8', '.json': 'application/json', '.svg': 'image/svg+xml', '.wasm': 'application/wasm',
  '.glb': 'model/gltf-binary', '.png': 'image/png', '.ico': 'image/x-icon', '.woff2': 'font/woff2',
};
const hostOk = (h = '') => h === `127.0.0.1:${PORT}` || h === `localhost:${PORT}`;

function file(res, path, immutable) {
  let st;
  try { st = statSync(path); } catch { return false; }
  if (!st.isFile()) return false;
  res.writeHead(200, {
    'Content-Type': TYPES[extname(path)] ?? 'application/octet-stream',
    'Content-Length': st.size,
    'Cache-Control': immutable ? 'public, max-age=31536000, immutable' : 'no-cache',
  });
  createReadStream(path).pipe(res);
  return true;
}

createServer((req, res) => {
  if (!hostOk(req.headers.host)) { res.writeHead(421).end(); return; }
  const url = new URL(req.url ?? '/', 'http://x');

  if (url.pathname.startsWith('/__desktop/')) {
    const action = url.pathname.slice('/__desktop/'.length);
    const same = req.headers['sec-fetch-site'] === 'same-origin';
    if (req.method !== 'POST' || !same || !['settings', 'hide'].includes(action)) { res.writeHead(403).end(); return; }
    spawn(SCRIPT, [action], { stdio: 'ignore', detached: true }).unref();
    res.writeHead(204).end();
    return;
  }

  if (url.pathname.startsWith('/api/')) {
    const up = request({ ...API, path: req.url, method: req.method, headers: { ...req.headers, host: `${API.host}:${API.port}` } }, (r) => {
      res.writeHead(r.statusCode ?? 502, r.headers);
      r.pipe(res);
    });
    up.on('error', () => { if (!res.headersSent) res.writeHead(502, { 'Content-Type': 'application/json' }); res.end('{"error":"api_unavailable"}'); });
    res.on('close', () => up.destroy());
    req.pipe(up);
    return;
  }

  const rel = normalize(decodeURIComponent(url.pathname)).replace(/^([/\\])+/, '');
  const path = join(ROOT, rel);
  if (!path.startsWith(ROOT)) { res.writeHead(403).end(); return; }
  if (file(res, path, rel.startsWith('assets/'))) return;
  if (!file(res, join(ROOT, 'index.html'), false)) res.writeHead(404).end();
}).listen(PORT, '127.0.0.1');
