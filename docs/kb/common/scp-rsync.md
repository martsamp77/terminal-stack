# Copy files between servers (scp / rsync)

## scp — quick one-offs

```bash
scp file.txt user@host:/remote/path/           # local → remote
scp user@host:/remote/file.txt ./              # remote → local
scp -r ./dir user@host:/remote/path/           # recurse a directory
scp -P 2222 file user@host:/path/              # non-default port (capital -P)
scp user@host1:/f.txt user@host2:/g.txt        # remote → remote (via your machine)
```

## rsync — bigger/resumable, only-changed transfers

```bash
rsync -avz ./dir/ user@host:/remote/dir/       # mirror dir CONTENTS (trailing / matters)
rsync -avz --progress src/ user@host:/dst/     # show per-file progress
rsync -avz --partial --append-verify big.iso user@host:/dst/   # resume an interrupted copy
rsync -avzn --delete src/ user@host:/dst/      # -n = DRY RUN; --delete prunes extras on dst
rsync -avz -e 'ssh -p 2222' src/ user@host:/dst/   # non-default ssh port
```

Flags: `-a` archive (perms/times/symlinks), `-v` verbose, `-z` compress, `-n` dry-run.
**Trailing slash on the source** copies the contents; no slash copies the dir itself.

## Remote → remote, going through nowhere (server pulls directly)

```bash
ssh user@host1 'rsync -avz /src/ user@host2:/dst/'   # host1 pushes to host2
```
