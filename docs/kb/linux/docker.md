# Linux — Docker

> If your user is in the `docker` group, none of these need sudo.

| Command | What it does |
|---|---|
| `docker ps` | running containers (`-a` for stopped too) |
| `docker logs -f name` | follow a container's logs (`--tail 100` to start near the end) |
| `docker exec -it name bash` | shell into a running container |
| `docker stop\|restart name` | stop / restart |
| `docker compose up -d` | start a compose stack |
| `docker compose logs -f svc` | follow one service in a stack |
| `docker stats` | live CPU/mem per container |
| `docker system prune` | clean dangling images/containers (`-a` is aggressive) |
