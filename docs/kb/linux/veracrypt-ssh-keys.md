# Linux/WSL — VeraCrypt container for SSH keys

Keep private keys inside an encrypted VeraCrypt volume, mounted only when needed.
This is the **generic** runbook; the personalized copy (real user/host/key names)
lives in `~/.doc.local/linux/veracrypt-ssh-keys.md`.

## 1. Install (once)

```bash
sudo apt update && sudo apt install software-properties-common -y
sudo add-apt-repository ppa:unit193/encryption -y
sudo apt update
sudo apt install veracrypt -y
```

## 2. Create the container (once)

```bash
mkdir -p ~/secure
veracrypt -t --create ~/secure/ssh-keys.vc --size 50M --encryption AES \
  --hash SHA-512 --filesystem ext4 --volume-type normal -k "" --pim 0 --force
```

## 3. Mount

```bash
sudo mkdir -p /mnt/veracrypt
veracrypt -t --mount ~/secure/ssh-keys.vc /mnt/veracrypt
```

## 4. Fix ownership + permissions — RUN AFTER EVERY MOUNT

```bash
sudo chown -R "$USER:$USER" /mnt/veracrypt
chmod 700 /mnt/veracrypt
chmod 600 /mnt/veracrypt/id_*
chmod 644 /mnt/veracrypt/id_*.pub
```

## 5. Generate a key inside it

```bash
cd /mnt/veracrypt
ssh-keygen -t ed25519 -C "you@host-$(date +%Y%m%d)" -f id_newkey
```

## 6. Point ~/.ssh/config at the mounted key

```bash
cat >> ~/.ssh/config <<'EOF'
Host *
    IdentityFile /mnt/veracrypt/id_newkey
    IdentitiesOnly yes
    ServerAliveInterval 60
EOF
chmod 600 ~/.ssh/config
```

## 7. Test, then unmount when done

```bash
ssh -T git@github.com
veracrypt -t -d /mnt/veracrypt          # dismount (all VeraCrypt volumes: -d with no path)
```
