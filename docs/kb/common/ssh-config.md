# SSH client config (`~/.ssh/config`)

Define per-host shortcuts so `ssh orion` just works.

```sshconfig
# Per-host block
Host orion
    HostName 192.168.1.50
    User marty
    Port 22
    IdentityFile ~/.ssh/id_orion
    IdentitiesOnly yes

# Wildcards + global defaults (most specific wins; put Host * LAST)
Host *
    ServerAliveInterval 60      # keepalive ping every 60s
    ServerAliveCountMax 3
    AddKeysToAgent yes
    IdentitiesOnly yes          # only offer the IdentityFile(s) named above
```

```bash
chmod 600 ~/.ssh/config
```

## Jump host (bastion)

```sshconfig
Host internal-box
    HostName 10.0.0.9
    User marty
    ProxyJump bastion.example.com
```

## Useful one-offs

```bash
ssh -v orion                    # verbose: see which key is offered
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_orion marty@host   # force one key, ignore agent
ssh-keygen -R orion             # drop a stale known_hosts entry after a rebuild
```
