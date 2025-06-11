#!/usr/bin/env bash

# Multi-SSH connection tool with tmux
# Usage: 
#   echo -e 'host1\nhost2' | multi-ssh.sh [command]
#   multi-ssh.sh host1 host2 [command]
#   cat hostfile | multi-ssh.sh

set -euo pipefail

# Configuration
SSH_CMD="${SSH_CMD:-ssh -A}"
LAYOUT="${LAYOUT:-tiled}"
SESSION_NAME="${SESSION_NAME:-multi-ssh-$$}"
VERBOSE="${VERBOSE:-0}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    if [[ $VERBOSE -eq 1 ]]; then
        echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}" >&2
    fi
}

error() {
    echo -e "${RED}Error: $1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}Warning: $1${NC}" >&2
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS] [HOSTS...] [-- COMMAND]
       echo -e 'host1\nhost2' | $0 [OPTIONS] [-- COMMAND]

OPTIONS:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    -s, --session NAME  Use specific tmux session name
    -l, --layout LAYOUT Set tmux layout (default: tiled)
    -c, --ssh-cmd CMD   SSH command to use (default: tsh ssh -A)
    -n, --no-sync       Don't synchronize panes
    -k, --kill-session  Kill existing session if it exists

ENVIRONMENT VARIABLES:
    SSH_CMD             SSH command (default: tsh ssh -A)
    LAYOUT              Tmux layout (default: tiled)
    SESSION_NAME        Session name (default: multi-ssh-\$\$)
    VERBOSE             Enable verbose output (0/1)

EXAMPLES:
    $0 host1 host2 host3
    echo -e 'web1\nweb2\ndb1' | $0 -- htop
    $0 -v -l even-horizontal host1 host2
EOF
}

# Parse command line arguments
HOSTS=()
COMMAND=""
NO_SYNC=0
KILL_SESSION=0
PARSING_HOSTS=1

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -s|--session)
            SESSION_NAME="$2"
            shift 2
            ;;
        -l|--layout)
            LAYOUT="$2"
            shift 2
            ;;
        -c|--ssh-cmd)
            SSH_CMD="$2"
            shift 2
            ;;
        -n|--no-sync)
            NO_SYNC=1
            shift
            ;;
        -k|--kill-session)
            KILL_SESSION=1
            shift
            ;;
        --)
            PARSING_HOSTS=0
            shift
            COMMAND="$*"
            break
            ;;
        -*)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            if [[ $PARSING_HOSTS -eq 1 ]]; then
                HOSTS+=("$1")
            fi
            shift
            ;;
    esac
done

# Get hosts from stdin if none provided as arguments
if [[ ${#HOSTS[@]} -eq 0 ]]; then
    if [[ -t 0 ]]; then
        error "No hosts provided and no input from stdin"
        usage
        exit 1
    fi
    
    log "Reading hosts from stdin..."
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]] && HOSTS+=("$line")
    done
fi

# Validate we have hosts
if [[ ${#HOSTS[@]} -eq 0 ]]; then
    error "No valid hosts found"
    exit 1
fi

log "Found ${#HOSTS[@]} hosts: ${HOSTS[*]}"

# Check if tmux is available
if ! command -v tmux &> /dev/null; then
    error "tmux is required but not installed"
    exit 1
fi

# Ensure tmux server is running (optional - tmux will start it automatically)
if ! tmux info &>/dev/null; then
    log "Starting tmux server..."
    tmux start-server
fi

# Kill existing session if requested
if [[ $KILL_SESSION -eq 1 ]] && tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    log "Killing existing session: $SESSION_NAME"
    tmux kill-session -t "$SESSION_NAME"
fi

# Create or attach to session
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    warn "Session '$SESSION_NAME' already exists. Use -k to kill it first."
    log "Attaching to existing session"
    exec tmux attach-session -t "$SESSION_NAME"
fi

log "Creating new tmux session: $SESSION_NAME"

# Create the session with the first host
FIRST_HOST="${HOSTS[0]}"
FULL_CMD="$SSH_CMD $FIRST_HOST"
if [[ -n "$COMMAND" ]]; then
    FULL_CMD="$FULL_CMD $COMMAND"
fi

log "Starting first connection: $FULL_CMD"
tmux new-session -d -s "$SESSION_NAME" "$FULL_CMD"

# Add remaining hosts as split windows
for ((i=1; i<${#HOSTS[@]}; i++)); do
    HOST="${HOSTS[$i]}"
    FULL_CMD="$SSH_CMD $HOST"
    if [[ -n "$COMMAND" ]]; then
        FULL_CMD="$FULL_CMD $COMMAND"
    fi
    
    log "Adding connection $((i+1))/${#HOSTS[@]}: $HOST"
    tmux split-window -t "$SESSION_NAME" "$FULL_CMD"
done

# Set layout
log "Setting layout: $LAYOUT"
tmux select-layout -t "$SESSION_NAME" "$LAYOUT"

# Synchronize panes unless disabled
if [[ $NO_SYNC -eq 0 ]]; then
    log "Enabling pane synchronization"
    tmux set-window-option -t "$SESSION_NAME" synchronize-panes on
fi

# Set window title
tmux rename-window -t "$SESSION_NAME" "multi-ssh"

log "Setup complete. Attaching to session."

# Attach to the session
exec tmux attach-session -t "$SESSION_NAME"
