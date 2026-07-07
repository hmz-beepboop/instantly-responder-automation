"""Inject a Code node's jsCode from a plain JS file into a local workflow export.

Usage: python scripts/SL-PHASE-5Q-S2-inject-node-code.py <workflow_export.json> <node_name> <code_file.js>

Round-trips the export JSON, replacing only parameters.jsCode of the named node.
Created for SL-PHASE-5Q S2 (session 16); reusable for any node patch.
"""
import io
import json
import sys


def main():
    wf_path, node_name, code_path = sys.argv[1], sys.argv[2], sys.argv[3]
    with io.open(wf_path, encoding="utf-8-sig") as f:
        wf = json.load(f)
    code = io.open(code_path, encoding="utf-8").read()
    hits = [n for n in wf["nodes"] if n.get("name") == node_name]
    if len(hits) != 1:
        print(f"ERROR: expected exactly 1 node named {node_name!r}, found {len(hits)}")
        sys.exit(1)
    old = hits[0]["parameters"].get("jsCode", "")
    hits[0]["parameters"]["jsCode"] = code
    with io.open(wf_path, "w", encoding="utf-8") as f:
        json.dump(wf, f, ensure_ascii=False, indent=2)
    print(f"Injected {len(code)} chars into node {node_name!r} (was {len(old)} chars) in {wf_path}")


if __name__ == "__main__":
    main()
