c = get_config()

c.ServerProxy.servers = {
    "forge": {
        "command": ["/bin/bash", "-lc", "micromamba run -n pyenv /usr/local/bin/start-forge.sh"],
        "port": 7860,
        "timeout": 300,
        "absolute_url": False,
        "launcher_entry": {
            "enabled": True,
            "title": "Forge Neo (Port 7860)",
        },
    }
}

# Paperspace relies on platform auth; disable Jupyter token/password inside the container.
c.ServerApp.token = ""
c.ServerApp.password = ""
c.ServerApp.disable_check_xsrf = True
