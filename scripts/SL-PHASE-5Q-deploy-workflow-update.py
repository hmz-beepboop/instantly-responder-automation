"""Deploy a local workflow export to production n8n via PUT (SL-PHASE-5Q session 15).

Usage: python scripts/SL-PHASE-5Q-deploy-workflow-update.py <local_export.json> <workflow_id>

Sends only name/nodes/connections/settings (n8n v1 API rejects read-only
fields). Reads N8N_API_KEY from the environment; never prints secrets.
Target is the production cloud instance per HMZ production target guard.
"""
import io
import json
import os
import sys
import urllib.request

BASE = "https://n8n.hmzaiautomation.com/api/v1"

def main():
    path, wf_id = sys.argv[1], sys.argv[2]
    api_key = os.environ.get("N8N_API_KEY")
    if not api_key:
        print("N8N_API_KEY not set")
        sys.exit(2)
    with io.open(path, encoding="utf-8-sig") as f:
        wf = json.load(f)
    body = {
        "name": wf["name"],
        "nodes": wf["nodes"],
        "connections": wf["connections"],
        "settings": wf.get("settings") or {},
    }
    req = urllib.request.Request(
        f"{BASE}/workflows/{wf_id}",
        data=json.dumps(body).encode("utf-8"),
        headers={"X-N8N-API-KEY": api_key, "Content-Type": "application/json"},
        method="PUT",
    )
    with urllib.request.urlopen(req) as resp:
        result = json.loads(resp.read().decode("utf-8"))
    print("HTTP", resp.status)
    print("workflow id:", result.get("id"))
    print("new versionId:", result.get("versionId"))
    print("active:", result.get("active"))

if __name__ == "__main__":
    main()
