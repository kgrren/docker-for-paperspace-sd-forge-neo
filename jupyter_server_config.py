# Minimal Jupyter Server config for Paperspace + Server Proxy
# Avoid touching base_url/token/xsrf here; those are controlled via CLI in start-jupyter.

c.ServerProxy.servers = {
  "forge_neo": {
    "command": ["/usr/local/bin/start-forge-neo"],
    "timeout": 120,
    "launcher_entry": {
      "title": "Stable Diffusion Forge Neo (7860)",
      "icon_path": ""
    },
    "absolute_url": False,
  }
}
