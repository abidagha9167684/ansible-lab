# 3. Client check automation (Bash)

A Bash script run on the Admin machine that checks a Linux client over SSH, saves a report, warns about high resource usage, tries to recover Nginx and collects logs when recovery fails. The script is [`scripts/client_check.sh`](../scripts/client_check.sh).

## SSH setup
The Admin machine keeps the private key. The matching **public** key is in `~/.ssh/authorized_keys` on the client. If the key has a passphrase, load it once per session so the script does not prompt on every `ssh` call:

```bash
eval "$(ssh-agent -s)"
ssh-add /adminkey
ssh-add -l
```

## What the script does
1. Collects: hostname, user, OS release, kernel, uptime, CPU (`lscpu`), memory (`free -h`), disk (`df -h`), IP addresses, network interfaces, Nginx state, listening ports (`ss -tulpn`), logged-in users and the last five logins.
2. Saves everything with `tee` into `client-report-<date>-<time>.txt`.
3. **Disk warning:** reads the root filesystem percentage and warns at 80% or more.
4. **Memory warning:** calculates used memory as a percentage and warns at 80% or more.
5. **Automatic Nginx recovery:** if `systemctl is-active nginx` is not `active`, runs `sudo systemctl start nginx` and checks again.
6. **Automatic log collection:** if Nginx still does not start, prints `journalctl -u nginx -n 30 --no-pager` and the last 30 lines of `/var/log/nginx/error.log`.

## Least-privilege sudo
The automation account should not get unrestricted passwordless root. Only the Nginx commands the script needs were allowed (edit with `visudo`):

```
ubuntu ALL=(ALL) NOPASSWD: /bin/systemctl start nginx, /bin/systemctl stop nginx, /bin/systemctl restart nginx, /bin/systemctl status nginx
```

## How to test
```bash
./scripts/client_check.sh                                   # normal report
ssh -i /adminkey ubuntu@<client-ip> "sudo systemctl stop nginx"
./scripts/client_check.sh                                   # detects, restarts, re-checks
```
Expected result: the script reports that Nginx is down, starts it, checks again and reports whether recovery worked.

## Security points
- The private key stays on Admin only. `authorized_keys` holds public keys only.
- `chmod 600` on private keys.
- Prefer a short command allow-list in sudoers over full `NOPASSWD`.
