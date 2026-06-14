# Linux — correct `~/.ssh` permissions

SSH refuses keys (and silently ignores `config`/`authorized_keys`) when permissions
are too open. The canonical set:

```bash
chmod 700 ~/.ssh                      # dir: owner-only
chmod 600 ~/.ssh/id_*                 # private keys: owner read/write
chmod 644 ~/.ssh/id_*.pub             # public keys: world-readable
chmod 600 ~/.ssh/config               # ssh client config
chmod 600 ~/.ssh/authorized_keys      # who may log in to THIS box
chmod 644 ~/.ssh/known_hosts
```

Ownership (everything owned by you, not root):

```bash
chown -R "$USER:$USER" ~/.ssh
```

## Symptoms of wrong perms

```text
Permissions 0644 for 'id_ed25519' are too open.   → chmod 600 the private key
Authentication refused: bad ownership or modes ... → fix ~/.ssh + authorized_keys
```

## Verify

```bash
ls -la ~/.ssh
ssh -v git@github.com 2>&1 | grep -i 'identity\|offering\|permission'
```
