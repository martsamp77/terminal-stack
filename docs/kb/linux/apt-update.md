# Linux — update & upgrade (apt)

## Routine update

```bash
sudo apt update                 # refresh package lists
sudo apt upgrade -y             # upgrade installed packages
sudo apt full-upgrade -y        # upgrade, allowing add/remove to satisfy deps
sudo apt autoremove --purge -y  # drop orphaned deps + their config
sudo apt autoclean              # clear out stale .deb cache
```

## One-liner

```bash
sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove --purge -y
```

## Inspect before upgrading

```bash
apt list --upgradable           # what would change
apt-cache policy <pkg>          # installed vs candidate version
```

## Reboot needed?

```bash
[ -f /var/run/reboot-required ] && cat /var/run/reboot-required
```

## Release upgrade (Ubuntu, deliberate)

```bash
sudo do-release-upgrade         # add -d to jump to a not-yet-final release
```
