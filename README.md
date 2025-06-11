# Multi-SSH Tool

A powerful bash script for connecting to multiple Linux hosts simultaneously using tmux. Works within your existing tmux session by splitting the current window into multiple panes. Perfect for system administrators, DevOps engineers, and anyone managing multiple servers.

## Features

- **Works in Current tmux Window**: Splits your current tmux window into multiple panes
- **Multiple Connection Methods**: Command-line arguments, stdin, or host files
- **Synchronized Input**: Type commands once, execute on all hosts
- **Flexible SSH Commands**: Support for different SSH clients (ssh, tsh, etc.)
- **Customizable Layouts**: Choose from various tmux pane arrangements
- **Error Handling**: Robust validation and helpful error messages
- **Verbose Logging**: Optional detailed output for debugging

## Prerequisites

- **tmux**: Terminal multiplexer (required)
- **SSH client**: Any SSH client (ssh, tsh, etc.)
- **Bash**: Version 4+ recommended

### Installation

```bash
# Install tmux (Ubuntu/Debian)
sudo apt install tmux

# Install tmux (CentOS/RHEL)
sudo yum install tmux

# Install tmux (macOS)
brew install tmux
```

## Quick Start

```bash
# Make script executable
chmod +x multi-ssh.sh

# Copy to your PATH (optional)
cp multi-ssh.sh /usr/local/bin/

# Start tmux first
tmux

# Then run the script inside tmux
./multi-ssh.sh web1 web2 db1
```

## Important: Must Run Inside tmux

**This script must be run from within a tmux session.** It will split your current tmux window into multiple panes, one for each host.

```bash
# Step 1: Start tmux
tmux

# Step 2: Run the multi-ssh script
./multi-ssh.sh host1 host2 host3
```

## Usage

### Basic Syntax

```bash
multi-ssh.sh [OPTIONS] [HOSTS...] [-- COMMAND]
echo "host1\nhost2" | multi-ssh.sh [OPTIONS] [-- COMMAND]
```

### Connection Methods

#### 1. Command Line Arguments
```bash
# Simple connection
./multi-ssh.sh server1 server2 server3

# With specific command
./multi-ssh.sh web1 web2 -- htop
```

#### 2. Stdin Input (Original Method)
```bash
# From echo
echo -e 'web1\nweb2\ndb1' | ./multi-ssh.sh

# From file
cat hosts.txt | ./multi-ssh.sh

# With command
echo -e 'host1\nhost2' | ./multi-ssh.sh -- 'tail -f /var/log/syslog'
```

#### 3. Host Files
Create a `hosts.txt` file:
```
web1.example.com
web2.example.com
# This is a comment
db1.example.com

# Empty lines are ignored
app1.example.com
```

Then use:
```bash
cat hosts.txt | ./multi-ssh.sh
```

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `-h, --help` | Show help message | - |
| `-v, --verbose` | Enable verbose output | Off |
| `-s, --session NAME` | Use specific session name | `multi-ssh-$` |
| `-l, --layout LAYOUT` | Set tmux layout | `tiled` |
| `-c, --ssh-cmd CMD` | SSH command to use | `ssh -A` |
| `-k, --kill-session` | Kill existing session | Keep existing |

## Environment Variables

Customize behavior with environment variables:

```bash
export SSH_CMD="ssh -o StrictHostKeyChecking=no"
export LAYOUT="even-horizontal"
export SESSION_NAME="my-servers"
export VERBOSE=1
```

## Examples

### Basic Examples

```bash
# Start tmux first
tmux

# Connect to three web servers
./multi-ssh.sh web1 web2 web3

# Monitor logs across multiple servers
./multi-ssh.sh app1 app2 app3 -- tail -f /var/log/application.log

# Use custom SSH options
SSH_CMD="ssh -i ~/.ssh/prod_key" ./multi-ssh.sh prod1 prod2
```

### Advanced Examples

```bash
# Start tmux first
tmux

# Verbose mode with custom layout
./multi-ssh.sh -v -l even-horizontal web1 web2 web3

# Custom SSH command for specific environment
./multi-ssh.sh -c "ssh -o ConnectTimeout=5" host1 host2
```

### Production Workflow

```bash
# Create a production hosts file
cat > prod_hosts.txt << EOF
web1.prod.company.com
web2.prod.company.com
api1.prod.company.com
api2.prod.company.com
EOF

# Start tmux and connect to all production servers
tmux
cat prod_hosts.txt | ./multi-ssh.sh -v

# Quick system check across all servers (in new tmux window)
tmux new-window
cat prod_hosts.txt | ./multi-ssh.sh -- 'uptime && df -h / && free -m'
```

## Tmux Layouts

Available layouts for the `-l` option:

- `tiled` (default): Equal-sized panes in a grid
- `even-horizontal`: Horizontal split with equal widths
- `even-vertical`: Vertical split with equal heights
- `main-horizontal`: Large pane on top, smaller ones below
- `main-vertical`: Large pane on left, smaller ones on right

## Tmux Key Bindings

Once connected, use these tmux shortcuts:

| Key Combination | Action |
|----------------|--------|
| `Ctrl+b d` | Detach from session |
| `Ctrl+b x` | Close current pane |
| `Ctrl+b :` | Enter tmux command mode |
| `Ctrl+b z` | Zoom current pane |
| `Ctrl+b Arrow` | Navigate between panes |

### Toggle Synchronization

```bash
# Disable synchronization
Ctrl+b : set-window-option synchronize-panes off

# Enable synchronization
Ctrl+b : set-window-option synchronize-panes on
```

## Troubleshooting

### Common Issues

**1. "tmux is required but not installed"**
```bash
# Install tmux first
sudo apt install tmux  # Ubuntu/Debian
sudo yum install tmux  # CentOS/RHEL
brew install tmux      # macOS
```

**2. "This script must be run inside a tmux session"**
```bash
# Start tmux first
tmux

# Then run your multi-ssh command
./multi-ssh.sh host1 host2
```

**3. SSH Connection Failures**
```bash
# Test individual connections first
ssh host1

# Use verbose mode to debug
./multi-ssh.sh -v host1 host2

# Check SSH configuration
ssh -v host1
```

**4. Permission Denied**
```bash
# Make script executable
chmod +x multi-ssh.sh

# Check SSH keys
ssh-add -l
```

### Debug Mode

Enable verbose output for troubleshooting:

```bash
# Method 1: Command line option
./multi-ssh.sh -v host1 host2

# Method 2: Environment variable
VERBOSE=1 ./multi-ssh.sh host1 host2
```

## Integration Examples

### With Ansible Inventory

```bash
# Extract hosts from Ansible inventory
ansible-inventory --list | jq -r '.webservers.hosts[]' | ./multi-ssh.sh

# Or from inventory file
grep -E '^\[webservers\]' -A 10 inventory.ini | grep -v '^\[' | ./multi-ssh.sh
```

### With Docker Containers

```bash
# Connect to multiple Docker containers
docker ps --format "table {{.Names}}" | tail -n +2 | xargs -I {} ./multi-ssh.sh {}
```

## Security Considerations

- **SSH Keys**: Use SSH keys instead of passwords for automation
- **Host Verification**: Consider SSH host key verification settings
- **Session Names**: Avoid predictable session names in shared environments
- **Command Logging**: Be aware that commands are visible in tmux history

## Contributing

Feel free to submit issues and pull requests. Areas for improvement:

- Connection health checking
- SSH key management
- Host grouping and tagging
- Output logging to files
- Integration with configuration management tools

## License

This tool is provided as-is under the MIT License. Use at your own risk.

---

**Pro Tip**: Create aliases for common scenarios:
```bash
alias web-ssh='cat ~/config/web_hosts.txt | multi-ssh.sh -s web-servers'
alias db-ssh='cat ~/config/db_hosts.txt | multi-ssh.sh -s database-servers'
alias prod-check='cat ~/config/prod_hosts.txt | multi-ssh.sh -- "uptime && df -h /"'
```