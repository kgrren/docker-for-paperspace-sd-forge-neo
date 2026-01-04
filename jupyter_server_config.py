# jupyter_server_config.py の修正案
c.ServerProxy.servers = {
    'forge': {
        'command': ['echo', 'Forge Neo should be started from Notebook'],
        'port': 7860,
        'absolute_url': False, # これをFalseにする場合はForge側で--subpathが必要
        'launcher_entry': {
            'enabled': True,
            'title': 'Forge Neo',
        }
    }
}

# WebUIの表示がブロックされるのを防ぐための設定を追加
c.ServerApp.allow_origin = '*'
c.ServerApp.tornado_settings = {
    'headers': {
        'Content-Security-Policy': "frame-ancestors 'self' *"
    }
}
