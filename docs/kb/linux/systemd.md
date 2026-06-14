# Linux — services & logs (systemd)

| Command | What it does |
|---|---|
| `sudo systemctl status svc` | is it running, recent log lines |
| `sudo systemctl restart\|start\|stop\|enable svc` | service control |
| `sudo systemctl daemon-reload` | after editing a unit file |
| `journalctl -u svc -f` | follow a service's logs live |
| `journalctl -u svc --since "1 hour ago"` | recent history for a service |
| `journalctl -u svc -n 100` | last 100 lines |
| `systemctl --user ...` | per-user services (no sudo) |
