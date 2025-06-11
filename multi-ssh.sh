#!/usr/bin/env bash

# Multi-SSH connection tool with screen
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

# Cleanup function to kill screen session if script exits unexpectedly
cleanup() {
    if [[ -n "${SESSION_NAME:-}" ]] && screen -list | grep -q "$SESSION_NAME"; then
        log "Cleaning up screen session: $SESSION_NAME"
        screen -S "$SESSION_NAME" -X quit || true
    fi
}

# Set up trap to call cleanup on script exit
trap cleanup EXIT

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
    -c, --ssh-cmd CMD   SSH command to use (default: ssh -A)
    -k, --kill-session  Kill existing session if it exists

ENVIRONMENT VARIABLES:
    SSH_CMD             SSH command (default: ssh -A)
    LAYOUT              Tmux layout (default: tiled)
    SESSION_NAME        Session name (default: multi-ssh-$$)
    VERBOSE             Enable verbose output (0/1)

EXAMPLES:
    $0 host1 host2 host3
    echo -e 'web1\nweb2\ndb1' | $0 -- htop
EOF
}

# Parse command line arguments
HOSTS=()
COMMAND=""
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

# If not running inside tmux, ask the user to start tmux manually
if [[ -z "${TMUX:-}" ]]; then
    error "This script must be run inside a tmux session. Please start tmux first (e.g., run 'tmux'), then run this script inside a tmux pane."
    exit 1
fi

log "Adding panes to current tmux window."
FIRST_HOST="${HOSTS[0]}"
FULL_CMD="$SSH_CMD $FIRST_HOST"
if [[ -n "$COMMAND" ]]; then
    FULL_CMD="$FULL_CMD $COMMAND"
fi
tmux send-keys "$FULL_CMD" Enter
for ((i=1; i<${#HOSTS[@]}; i++)); do
    HOST="${HOSTS[$i]}"
    FULL_CMD="$SSH_CMD $HOST"
    if [[ -n "$COMMAND" ]]; then
        FULL_CMD="$FULL_CMD $COMMAND"
    fi
    tmux split-window "$FULL_CMD"
    tmux select-layout "$LAYOUT"
done
log "Enabling pane synchronization"
tmux set-window-option synchronize-panes on
log "All panes added to current tmux window."