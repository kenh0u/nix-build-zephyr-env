#!/usr/bin/env python3
"""Inject extra projects into a Zephyr west.yml manifest.

Usage: inject-modules.py <west.yml> '<json array of modules>'

Each module is an object with keys:
  name, url_base, revision, path, remote_name (optional)
"""

import json
import sys
import yaml

def main():
    west_yml_path = sys.argv[1]
    modules_json = sys.argv[2]

    with open(west_yml_path) as f:
        manifest = yaml.safe_load(f)

    modules = json.loads(modules_json)

    remotes = manifest.setdefault("manifest", {}).setdefault("remotes", [])
    projects = manifest["manifest"].setdefault("projects", [])

    existing_remote_names = {r["name"] for r in remotes}
    existing_project_names = {p["name"] for p in projects}

    for mod in modules:
        remote_name = mod.get("remote_name", mod["name"] + "_remote")

        if remote_name not in existing_remote_names:
            remotes.append({
                "name": remote_name,
                "url-base": mod["url_base"],
            })
            existing_remote_names.add(remote_name)

        if mod["name"] not in existing_project_names:
            projects.append({
                "name": mod["name"],
                "path": mod["path"],
                "revision": mod["revision"],
                "remote": remote_name,
            })
            existing_project_names.add(mod["name"])

    with open(west_yml_path, "w") as f:
        yaml.dump(manifest, f, default_flow_style=False, sort_keys=False)

if __name__ == "__main__":
    main()
