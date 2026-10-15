# 1. Linux administration and Ansible automation

The lab started with manual Linux administration so that I understood each task before automating it.

## Lab setup

| Machine | Purpose |
|---|---|
| **Admin** | Central management server. Runs Ansible (and later n8n, AWX, Prometheus and Grafana). |
| **Client1** | First managed Ubuntu client (AWS EC2). |
| **Client2** | Second managed Ubuntu client, added to prove that the same automation manages several clients. |

IP addresses changed when the instances were recreated during the project, so this repo uses placeholders. The central design decision was to administer clients from the Admin machine rather than by logging in to each one.

## Step 1: SSH key authentication
Admin connects to each client with an SSH key so that Ansible can later work without prompts.

```bash
ssh -i <key> ubuntu@<client-ip> hostname
```
- Generated an Ed25519 key and put the public key in each client's `~/.ssh/authorized_keys`.
- Checked Admin → Client1 and Admin → Client2 connectivity, key permissions (`chmod 600`) and host verification, and used `scp` for file transfer.

## Step 2: Manual administration
```bash
# users, groups and a shared support folder
sudo groupadd it-support
sudo useradd -m -s /bin/bash helpdesk1
sudo useradd -m -s /bin/bash helpdesk2
sudo usermod -aG it-support helpdesk2
sudo mkdir -p /company-support
sudo chown root:it-support /company-support
sudo chmod 2770 /company-support     # SGID: new files inherit the it-support group

# Nginx service administration and troubleshooting
sudo apt install nginx
systemctl status nginx; systemctl is-active nginx
nginx -t; ss -tulpn; journalctl -u nginx; curl http://localhost
```

## Step 3: Ansible inventory and ad-hoc commands
```ini
[clients]
Client1 ansible_host=<CLIENT1_IP> ansible_user=ubuntu ansible_ssh_private_key_file=<path-to-key>
Client2 ansible_host=<CLIENT2_IP> ansible_user=ubuntu ansible_ssh_private_key_file=<path-to-key>
```
```bash
ansible clients -i inventory.ini -m ping
ansible clients -i inventory.ini -b -m apt -a "name=nginx state=present update_cache=yes"
ansible clients -i inventory.ini -b -m service -a "name=nginx state=restarted"
```
`ping` proves the inventory, SSH authentication and remote Python execution all work.

## Step 4: Playbooks, variables, templates and handlers
Repeatable tasks moved into playbooks: package cache update, Nginx install and enable, group and users, the shared folder with correct ownership and permissions, and a templated Nginx page.

| Concept | Use in this project |
|---|---|
| Variables | Package and service names, health thresholds kept out of task logic |
| Templates | Per-client web page built from `inventory_hostname` and the client's IP |
| Handlers | Restart Nginx only when its page or configuration actually changed |
| Idempotency | Running the playbook again leaves a correct system unchanged |

The demo playbooks `nginx_setup.yml`, `nginx_stop.yml` and `varaiable_demo.yml` show these concepts in their simplest form.

## Step 5: Refactor into roles
The code was then split into roles. The current `site.yml` applies six:

| Role | Responsibility |
|---|---|
| `nginx` | Install, enable and configure Nginx, deploy the template page, restart via handler |
| `users` | Create the `it-support` group and the `helpdesk1` / `helpdesk2` users |
| `shared_folder` | Create `/company-support` (`root:it-support`, mode `2770`) |
| `software_deployment` | Deploy, upgrade, roll back or remove the custom `client-info` package |
| `health_check` | Report Nginx, port 80, disk, memory, package version and failed services |
| `security_compliance` | Audit SSH settings and fix `.ssh` permissions |

An early version of the main playbook used `role_setup.yml` with only the first three roles. Run against both clients it finished with `failed=0`.

### `software_deployment` role
Copies `client-info_<version>.deb` to the client and installs it with the `apt` module (`allow_downgrade: true`, so a rollback works too), or removes it. The behaviour is controlled by two variables: `client_info_state` (`present` / `absent`) and `client_info_version` (default `2.0`). Both `client-info_2.0.deb` and `client-info_3.0.deb` are in `roles/software_deployment/files/`.

### `health_check` role
Produces a compact `CLIENT HEALTH SUMMARY` with Nginx state, port 80, disk and memory usage against thresholds, the `client-info` version and failed systemd services. Thresholds live in `group_vars/clients.yml` (80%) and `host_vars/Client1.yml` overrides the disk threshold to 90% for that host.

### `security_compliance` role
Checks `sshd -T` for password authentication and root login, and checks the permissions of `~/.ssh` (expected `0700`) and `authorized_keys` (expected `0600`). It then reports COMPLIANT or WARNING, fixes wrong permissions, and checks again.

## Step 6: Git
The Ansible project is kept in Git, so every change to the inventory, playbooks and roles is tracked and reviewable. Private keys and secrets are never committed (see `.gitignore`).

```bash
git status
git add <files>
git commit -m "Update Linux client automation"
git log --oneline
```

## Running it
```bash
ansible-playbook -i inventory.ini site.yml                  # all six roles
ansible-playbook -i inventory.ini site.yml --tags health    # one role by tag
ansible-playbook -i inventory.ini health_check.yml          # health report only
ansible-playbook -i inventory.ini nginx_recovery.yml        # detect and recover Nginx
ansible-playbook -i inventory.ini diagnostics.yml           # collect diagnostics
```
Tags in `site.yml`: `nginx`, `users`, `shared`, `software`, `health`, `security`.
