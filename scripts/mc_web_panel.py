#!/usr/bin/env python3
"""Lightweight MC Server Control Panel - runs on Watcher machine"""
import http.server
import json
import subprocess
import socket
import urllib.parse
import os
import re

AWS_REGION = os.environ.get("AWS_REGION", "ap-east-1")
MC_SERVER_IP = os.environ.get("MC_SERVER_IP", "172.31.16.100")
AWS_CLI = "/usr/local/bin/aws"
AUTH_TOKEN = os.environ.get("AUTH_TOKEN", "koei2026")
RCON_PASS = os.environ.get("RCON_PASS", "")

HTML_PAGE = r'''<!DOCTYPE html>
<html lang="zh-HK">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>MC Server Control</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:-apple-system,sans-serif;background:#1a1a2e;color:#e0e0e0;min-height:100vh;display:flex;justify-content:center;align-items:center}
.card{background:#16213e;border-radius:16px;padding:32px;width:380px;box-shadow:0 8px 32px rgba(0,0,0,.4)}
h1{text-align:center;margin-bottom:24px;font-size:22px;color:#fff}
.status-box{background:#0f3460;border-radius:12px;padding:20px;margin-bottom:20px;text-align:center}
.status-label{font-size:13px;color:#888;margin-bottom:4px}
.status-value{font-size:28px;font-weight:bold}
.status-value.running{color:#4ecca3}
.status-value.stopped{color:#e74c3c}
.status-value.pending,.status-value.stopping{color:#f39c12}
.status-value.unknown{color:#888}
.info-row{display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid #1a1a3e;font-size:14px}
.info-row:last-child{border:none}
.info-label{color:#888}
.btns{display:flex;gap:12px;margin-top:20px}
.btn{flex:1;padding:14px;border:none;border-radius:10px;font-size:15px;font-weight:bold;cursor:pointer;transition:all .2s}
.btn:disabled{opacity:.4;cursor:not-allowed}
.btn-start{background:#4ecca3;color:#1a1a2e}
.btn-start:hover:not(:disabled){background:#3db892}
.btn-stop{background:#e74c3c;color:#fff}
.btn-stop:hover:not(:disabled){background:#c0392b}
.btn-panel{display:block;text-align:center;margin-top:16px;padding:12px;background:#533483;color:#fff;border-radius:10px;text-decoration:none;font-size:14px;font-weight:bold;transition:all .2s}
.btn-panel:hover{background:#6c44a2}
.btn-panel.disabled{opacity:.4;pointer-events:none}
.msg{text-align:center;margin-top:12px;padding:8px;border-radius:8px;font-size:13px;display:none}
.msg.ok{display:block;background:#1b4332;color:#4ecca3}
.msg.err{display:block;background:#3d0000;color:#e74c3c}
.footer{text-align:center;margin-top:16px;font-size:11px;color:#555}
</style>
</head>
<body>
<div class="card">
  <h1>Minecraft Server Control</h1>
  <div class="status-box">
    <div class="status-label">Server Status</div>
    <div class="status-value" id="status">Loading...</div>
  </div>
  <div id="info"></div>
  <div class="btns">
    <button class="btn btn-start" id="startBtn" onclick="doAction('start')" disabled>Start</button>
    <button class="btn btn-stop" id="stopBtn" onclick="doAction('stop')" disabled>Stop</button>
  </div>
  <a class="btn-panel disabled" id="panelLink" href="#" target="_blank">Open Pterodactyl Panel</a>
  <div class="msg" id="msg"></div>
  <div class="footer">Watcher Control Panel</div>
</div>
<script>
const TOKEN = new URLSearchParams(window.location.search).get('token') || '';
function api(path, method) {
  return fetch('/api/' + path + '?token=' + TOKEN, {method: method || 'GET'}).then(function(r) { return r.json(); });
}
function refresh() {
  api('status').then(function(d) {
    var s = document.getElementById('status');
    s.textContent = d.state || 'unknown';
    s.className = 'status-value ' + (d.state || 'unknown');
    document.getElementById('startBtn').disabled = d.state === 'running' || d.state === 'pending';
    document.getElementById('stopBtn').disabled = d.state !== 'running';
    var pl = document.getElementById('panelLink');
    if (d.state === 'running' && d.public_ip) {
      pl.href = 'http://' + d.public_ip + ':8080';
      pl.className = 'btn-panel';
    } else {
      pl.className = 'btn-panel disabled';
    }
    var info = '';
    if (d.public_ip) info += '<div class="info-row"><span class="info-label">Public IP</span><span>' + d.public_ip + '</span></div>';
    info += '<div class="info-row"><span class="info-label">Connect</span><span>it114115.duckdns.org</span></div>';
    if (d.players) info += '<div class="info-row"><span class="info-label">Players</span><span>' + d.players + '</span></div>';
    document.getElementById('info').innerHTML = info;
  });
}
function doAction(action) {
  var msg = document.getElementById('msg');
  msg.className = 'msg ok';
  msg.textContent = action === 'start' ? 'Starting... please wait 2-3 minutes' : 'Stopping...';
  msg.style.display = 'block';
  document.getElementById('startBtn').disabled = true;
  document.getElementById('stopBtn').disabled = true;
  api(action, 'POST').then(function(d) {
    msg.className = 'msg ' + (d.ok ? 'ok' : 'err');
    msg.textContent = d.message;
    setTimeout(refresh, 5000);
  });
}
refresh();
setInterval(refresh, 10000);
</script>
</body>
</html>'''


def run_aws(args, timeout=15):
    try:
        r = subprocess.run([AWS_CLI] + args, capture_output=True, text=True, timeout=timeout)
        return r.stdout.strip()
    except Exception:
        return ""


def get_mc_info():
    info = run_aws(["ec2", "describe-instances",
        "--region", AWS_REGION,
        "--filters", "Name=tag:Name,Values=minecraft-server",
        "--query", "Reservations[0].Instances[0].{State:State.Name,IP:PublicIpAddress,Id:InstanceId}",
        "--output", "json"])
    try:
        return json.loads(info)
    except Exception:
        return {"State": "unknown", "IP": None, "Id": None}


def get_players():
    try:
        r = subprocess.run(
            ["mcrcon", "-H", MC_SERVER_IP, "-P", "25575", "-p", RCON_PASS, "list"],
            capture_output=True, text=True, timeout=5)
        m = re.search(r"(\d+) of", r.stdout)
        return m.group(1) + "/8" if m else None
    except Exception:
        return None


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def check_auth(self):
        q = urllib.parse.urlparse(self.path).query
        params = urllib.parse.parse_qs(q)
        return params.get("token", [""])[0] == AUTH_TOKEN

    def send_json(self, data, code=200):
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path
        if path == "/" or path == "":
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(HTML_PAGE.encode())
        elif path == "/api/status":
            if not self.check_auth():
                return self.send_json({"error": "unauthorized"}, 401)
            info = get_mc_info()
            players = get_players() if info.get("State") == "running" else None
            self.send_json({
                "state": info.get("State", "unknown"),
                "public_ip": info.get("IP"),
                "instance_id": info.get("Id"),
                "players": players
            })
        else:
            self.send_json({"error": "not found"}, 404)

    def do_POST(self):
        path = urllib.parse.urlparse(self.path).path
        if not self.check_auth():
            return self.send_json({"error": "unauthorized"}, 401)
        info = get_mc_info()
        iid = info.get("Id")
        if not iid or iid == "None":
            return self.send_json({"ok": False, "message": "Cannot find MC instance"})

        if path == "/api/start":
            if info.get("State") == "running":
                return self.send_json({"ok": True, "message": "Server is already running"})
            run_aws(["ec2", "start-instances", "--region", AWS_REGION, "--instance-ids", iid])
            self.send_json({"ok": True, "message": "Starting server... wait 2-3 minutes"})
        elif path == "/api/stop":
            if info.get("State") != "running":
                return self.send_json({"ok": True, "message": "Server is not running"})
            # Graceful shutdown: save world via RCON, then stop Pterodactyl, then EC2
            import threading
            def graceful_stop(instance_id):
                try:
                    # 1. Save world and stop MC via RCON
                    subprocess.run(["mcrcon", "-H", MC_SERVER_IP, "-P", "25575", "-p", RCON_PASS,
                        "say Server shutting down in 10 seconds..."], capture_output=True, timeout=5)
                    time.sleep(10)
                    subprocess.run(["mcrcon", "-H", MC_SERVER_IP, "-P", "25575", "-p", RCON_PASS,
                        "save-all"], capture_output=True, timeout=10)
                    time.sleep(5)
                    subprocess.run(["mcrcon", "-H", MC_SERVER_IP, "-P", "25575", "-p", RCON_PASS,
                        "stop"], capture_output=True, timeout=10)
                    time.sleep(15)  # wait for MC to fully stop
                except Exception:
                    pass
                # 2. Stop EC2
                run_aws(["ec2", "stop-instances", "--region", AWS_REGION, "--instance-ids", instance_id])
            threading.Thread(target=graceful_stop, args=(iid,), daemon=True).start()
            self.send_json({"ok": True, "message": "Saving world... server will stop in ~30 seconds"})
        else:
            self.send_json({"error": "not found"}, 404)


if __name__ == "__main__":
    print("MC Web Panel listening on :8080", flush=True)
    server = http.server.HTTPServer(("0.0.0.0", 8080), Handler)
    server.serve_forever()
