# 2. Software deployment and Debian packaging

Software **deployment** means installing, upgrading or removing software on machines. Software **packaging** means putting software into a standard format that the operating system can manage. This part of the lab practised both.

## Deployment with a Bash script
[`scripts/software_deploy.sh`](../scripts/software_deploy.sh) lets the Admin machine install, remove or upgrade any Ubuntu package on a client over SSH.

```bash
./scripts/software_deploy.sh nginx install
./scripts/software_deploy.sh nginx upgrade
./scripts/software_deploy.sh nginx remove
```
- `ssh -i <key>` connects with the private key kept on Admin.
- `apt install -y`, `apt remove -y` and `apt install --only-upgrade -y` perform the action.
- `&&` makes the install or upgrade run only if `apt update` succeeded.

## Why a `.deb` package
A `.deb` carries the package name, version, architecture, maintainer, description, files, dependencies and upgrade/removal information, so Ubuntu knows what is installed, in which version, and how to upgrade or remove it.

## Custom package: `client-info-tool`
The package sources are in [`packaging/client-info-tool_1.0.0/`](../packaging/client-info-tool_1.0.0/).

```
client-info-tool_1.0.0/
├── DEBIAN/
│   └── control                  # package metadata
└── usr/local/bin/
    └── client-info              # Bash script showing hostname, OS, kernel, CPU, memory, disk, ports, Nginx state
```
```bash
chmod 755 client-info-tool_1.0.0/usr/local/bin/client-info
dpkg-deb --build client-info-tool_1.0.0            # builds client-info-tool_1.0.0.deb
scp -i <key> client-info-tool_1.0.0.deb ubuntu@<client-ip>:/home/ubuntu/
sudo dpkg -i /home/ubuntu/client-info-tool_1.0.0.deb
client-info; dpkg -l | grep client-info-tool; which client-info
```

## Upgrade
Copy the folder to `client-info-tool_1.1.0`, change `Version:` in `control`, update the script, rebuild, copy it over and install with `dpkg -i`. `dpkg -l` then shows the new version.

## Dependencies: `company-tools`
Dependencies belong in the `control` file ([`packaging/company-tools_1.0.0/DEBIAN/control`](../packaging/company-tools_1.0.0/DEBIAN/control)):

```
Depends: nginx, curl
```
Install it with **`apt install ./company-tools_1.0.0.deb`**, not plain `dpkg -i`. `dpkg` installs only the local file, while `apt` also downloads the missing dependencies.

## Configuration after installation: `postinst`
Required packages stay in `control`. Configuration actions go in a `DEBIAN/postinst` script, for example enabling and restarting Nginx (`chmod 755`, ending with `exit 0`).

## Cleanup
```bash
sudo apt remove company-tools
sudo apt autoremove        # removes dependencies that are no longer needed
```

## Connection to the Ansible part
The `client-info` package (versions 2.0 and 3.0) is deployed, upgraded, rolled back and removed on all clients by the `software_deployment` role, and the `health_check` role reports the installed version.

## Commands practised
`dpkg-deb --build`, `dpkg -i`, `dpkg -l`, `apt install ./pkg.deb`, `apt remove`, `apt purge`, `apt autoremove`, `apt-cache policy`, `scp`, `ssh`, `chmod 755`, `which`.
