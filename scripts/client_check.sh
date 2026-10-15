#!/bin/bash
# Remote health report for one Linux client, run from the Admin machine over SSH.
# Saves a timestamped report, warns on high disk/memory usage, tries to recover Nginx
# and collects Nginx logs if recovery fails.

CLIENT="ubuntu@CLIENT_PRIVATE_IP"   # replace with your client's user@private-ip
KEY="/adminkey"                      # path to the SSH private key on the Admin machine
REPORT="client-report-$(date +%F-%H-%M-%S).txt"

{
echo "===== CLIENT HEALTH REPORT ====="
echo ""

echo "Hostname:";            ssh -i "$KEY" "$CLIENT" "hostname"
echo ""
echo "Current User:";        ssh -i "$KEY" "$CLIENT" "whoami"
echo ""
echo "Operating System:";    ssh -i "$KEY" "$CLIENT" "cat /etc/os-release"
echo ""
echo "Kernel:";              ssh -i "$KEY" "$CLIENT" "uname -r"
echo ""
echo "Uptime:";              ssh -i "$KEY" "$CLIENT" "uptime"
echo ""
echo "CPU:";                 ssh -i "$KEY" "$CLIENT" "lscpu"
echo ""
echo "Memory:";              ssh -i "$KEY" "$CLIENT" "free -h"
echo ""
echo "Disk:";                ssh -i "$KEY" "$CLIENT" "df -h"
echo ""
echo "IP Address:";          ssh -i "$KEY" "$CLIENT" "hostname -I"
echo ""
echo "Network Interfaces:";  ssh -i "$KEY" "$CLIENT" "ip addr"
echo ""
echo "Nginx Status:";        ssh -i "$KEY" "$CLIENT" "systemctl is-active nginx"
echo ""
echo "Listening Ports:";     ssh -i "$KEY" "$CLIENT" "ss -tulpn"
echo ""
echo "Logged-in Users:";     ssh -i "$KEY" "$CLIENT" "who"
echo ""
echo "Recent Logins:";       ssh -i "$KEY" "$CLIENT" "last -n 5"
echo ""

DISK_USAGE=$(ssh -i "$KEY" "$CLIENT" "df / | tail -1 | awk '{print \$5}' | tr -d '%'")
if [ "$DISK_USAGE" -ge 80 ]; then
  echo "WARNING: Disk usage is ${DISK_USAGE}%"
else
  echo "Disk usage is OK: ${DISK_USAGE}%"
fi
echo ""

MEMORY_USAGE=$(ssh -i "$KEY" "$CLIENT" "free | awk '/Mem:/ {printf(\"%.0f\", \$3/\$2 * 100)}'")
if [ "$MEMORY_USAGE" -ge 80 ]; then
  echo "WARNING: Memory usage is ${MEMORY_USAGE}%"
else
  echo "Memory usage is OK: ${MEMORY_USAGE}%"
fi
echo ""

NGINX_STATUS=$(ssh -i "$KEY" "$CLIENT" "systemctl is-active nginx")
if [ "$NGINX_STATUS" = "active" ]; then
  echo "Nginx is running"
else
  echo "WARNING: Nginx is down"
  echo "Trying to start nginx..."
  ssh -i "$KEY" "$CLIENT" "sudo systemctl start nginx"
  NEW_STATUS=$(ssh -i "$KEY" "$CLIENT" "systemctl is-active nginx")
  if [ "$NEW_STATUS" = "active" ]; then
    echo "Nginx started successfully"
  else
    echo "CRITICAL: Nginx could not start"
    echo "Collecting nginx logs..."
    ssh -i "$KEY" "$CLIENT" "journalctl -u nginx -n 30 --no-pager"
    ssh -i "$KEY" "$CLIENT" "tail -n 30 /var/log/nginx/error.log"
  fi
fi

echo ""
echo "===== REPORT COMPLETE ====="
} | tee "$REPORT"

echo ""
echo "Report saved as: $REPORT"
