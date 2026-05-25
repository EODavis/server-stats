# 🖥️ server-stats.sh

A Bash script to analyse basic Linux server performance stats — runnable on any Linux server.

## 📊 Stats Reported
- Total CPU usage (used vs idle)
- Total memory usage (free vs used with %)
- Total disk usage (free vs used with %)
- Top 5 processes by CPU usage
- Top 5 processes by memory usage

## 🎯 Stretch Goals Included
- OS version, hostname, kernel
- Uptime and load average (1min, 5min, 15min)
- Logged-in users
- Failed SSH login attempts with top offending IPs

## 🚀 Usage

```bash
chmod +x server-stats.sh
./server-stats.sh

# For full failed-login access
sudo ./server-stats.sh
```

## 🔧 Requirements
- Any Linux server (Ubuntu, Debian, RHEL, CentOS)
- Bash 4+, standard GNU coreutils (`top`, `free`, `df`, `ps`)

## 📁 Reproduction Steps
```bash
git clone https://github.com/EODavis/server-stats.git
cd server-stats
chmod +x server-stats.sh
./server-stats.sh
```
