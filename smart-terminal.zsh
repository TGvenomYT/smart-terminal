#!/usr/bin/env zsh
# ─────────────────────────────────────────────────────────────
# Smart Terminal — powered by Apfel (local Apple Intelligence)
# https://github.com/TGvenomYT/smart-terminal
#
# Source this in your .zshrc:
#   source ~/.smart-terminal/smart-terminal.zsh
# ─────────────────────────────────────────────────────────────

# Resolve install directory (where this script lives)
typeset -g SMART_TERMINAL_DIR="${0:A:h}"

# Colors
typeset -g ST_RED='\033[0;31m'
typeset -g ST_GREEN='\033[0;32m'
typeset -g ST_YELLOW='\033[0;33m'
typeset -g ST_CYAN='\033[0;36m'
typeset -g ST_DIM='\033[2m'
typeset -g ST_BOLD='\033[1m'
typeset -g ST_RESET='\033[0m'

# Load command dictionary
source "${SMART_TERMINAL_DIR}/commands.zsh"

# Load user's custom commands if they exist
if [[ -f "${SMART_TERMINAL_DIR}/custom-commands.zsh" ]]; then
    source "${SMART_TERMINAL_DIR}/custom-commands.zsh"
fi

# ─────────────────────────────────────────────────────────────
# Markdown renderer — pipes output through glow if available
# ─────────────────────────────────────────────────────────────
_st_render_md() {
    if command -v glow &>/dev/null; then
        local tmpfile=$(mktemp /tmp/st_md_XXXXXX.md)
        cat > "$tmpfile"
        glow "$tmpfile"
        rm -f "$tmpfile"
    else
        # Fallback: basic ANSI formatting
        sed \
            -e 's/^# \(.*\)/\x1b[1;36m\1\x1b[0m/' \
            -e 's/^## \(.*\)/\x1b[1;33m\1\x1b[0m/' \
            -e 's/^### \(.*\)/\x1b[1;32m\1\x1b[0m/' \
            -e 's/\*\*\([^*]*\)\*\*/\x1b[1m\1\x1b[0m/g' \
            -e 's/`\([^`]*\)`/\x1b[36m\1\x1b[0m/g' \
            -e 's/^- /  • /g' \
            -e 's/^\* /  • /g'
    fi
}

# ─────────────────────────────────────────────────────────────
# 1. NL Query: translate natural language → shell command
#    Usage: ? find files larger than 100MB
#    Or:    ask find files larger than 100MB
# ─────────────────────────────────────────────────────────────
function ask() {
    local query="$*"
    if [[ -z "$query" ]]; then
        echo "${ST_YELLOW}Usage:${ST_RESET} ? <natural language query>"
        echo "${ST_DIM}Example: ? find files larger than 100MB${ST_RESET}"
        return 1
    fi

    echo "${ST_CYAN}⟩ Thinking...${ST_RESET}"

    # Try user's custom commands first
    local cmd
    if typeset -f _st_custom_lookup &>/dev/null; then
        cmd=$(_st_custom_lookup "$query")
    fi

    # Then try the built-in command dictionary
    if [[ $? -ne 0 ]] || [[ -z "$cmd" ]]; then
        cmd=$(_st_lookup_command "$query")
    fi

    # Fallback to LLM for queries not in dictionary
    if [[ $? -ne 0 ]] || [[ -z "$cmd" ]]; then
        if ! command -v apfel &>/dev/null; then
            echo "${ST_RED}✗ apfel not installed. Install from: https://github.com/Arthur-Ficial/apfel${ST_RESET}"
            echo "${ST_DIM}Without apfel, only dictionary commands work.${ST_RESET}"
            return 1
        fi

        local ctx="User: $(whoami). Home: $HOME. Current directory: $(pwd). OS: macOS. Shell: zsh. Common folders: ~/Downloads, ~/Documents, ~/Desktop, ~/Projects, ~/Developer."
        local system_prompt_file="${SMART_TERMINAL_DIR}/system-prompt.txt"
        local full_prompt="${ctx} Convert this to a shell command: ${query}"

        cmd=$(apfel -q --permissive --system-file "$system_prompt_file" "$full_prompt" 2>/dev/null | perl -pe 's/\e\[[0-9;]*[a-zA-Z]//g' | sed 's/^\$ //' | sed 's/^```.*//;s/^```//' | sed 's/^`//;s/`$//' | sed 's/^[[:space:]]*//' | sed '/^$/d' | head -1)
    fi

    if [[ -z "$cmd" ]]; then
        echo "${ST_RED}✗ Could not translate query to a command.${ST_RESET}"
        return 1
    fi

    # Check for dangerous patterns
    local dangerous=0
    if [[ "$cmd" =~ "rm -rf /" ]] || [[ "$cmd" =~ "mkfs" ]] || [[ "$cmd" =~ "dd if=" ]] || \
       [[ "$cmd" =~ "> /dev/" ]] || [[ "$cmd" =~ "chmod -R 777" ]] || \
       [[ "$cmd" =~ ":(){ :|:& };:" ]]; then
        dangerous=1
    fi

    # Display the translated command
    echo ""
    if [[ $dangerous -eq 1 ]]; then
        echo "${ST_RED}${ST_BOLD}⚠ DANGEROUS COMMAND:${ST_RESET}"
        echo "${ST_RED}  $cmd${ST_RESET}"
        echo ""
        echo -n "${ST_RED}Are you sure? [y/N]:${ST_RESET} "
    else
        echo "${ST_GREEN}  $cmd${ST_RESET}"
        echo ""
        echo -n "${ST_DIM}Run it? [Y/n]:${ST_RESET} "
    fi

    # Read confirmation
    local confirm
    read -r confirm

    if [[ $dangerous -eq 1 ]]; then
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            echo ""
            _st_remember "$query" "$cmd"
            eval "$cmd"
        else
            echo "${ST_DIM}Cancelled.${ST_RESET}"
        fi
    else
        if [[ "$confirm" =~ ^[Nn]$ ]]; then
            echo "${ST_DIM}Cancelled.${ST_RESET}"
        else
            echo ""
            _st_remember "$query" "$cmd"
            eval "$cmd"
        fi
    fi
}

# ─────────────────────────────────────────────────────────────
# 2. Port check shortcut
#    Usage: port 8080
# ─────────────────────────────────────────────────────────────
function port() {
    local p="$1"
    if [[ -z "$p" ]]; then
        echo "${ST_YELLOW}Usage:${ST_RESET} port <port_number>"
        echo "${ST_DIM}Example: port 3000${ST_RESET}"
        return 1
    fi
    if command -v apfel-port &>/dev/null; then
        apfel-port "$p"
    else
        lsof -i :"$p"
    fi
}

# ─────────────────────────────────────────────────────────────
# 3. Explain shortcut — explain an error or pipe output into it
#    Usage: explain "command not found: xyz"
#    Or:    some-command 2>&1 | explain
# ─────────────────────────────────────────────────────────────
function explain() {
    if [[ -t 0 ]]; then
        if [[ -z "$*" ]]; then
            echo "${ST_YELLOW}Usage:${ST_RESET} explain <error message>"
            echo "${ST_DIM}  or:  some-command 2>&1 | explain${ST_RESET}"
            return 1
        fi
        if command -v apfel-explain &>/dev/null; then
            echo "$*" | apfel-explain
        elif command -v apfel &>/dev/null; then
            echo "$*" | apfel -q -s "Explain this error message concisely. What went wrong and how to fix it."
        else
            echo "${ST_RED}✗ apfel not installed${ST_RESET}"
            return 1
        fi
    else
        if command -v apfel-explain &>/dev/null; then
            apfel-explain
        elif command -v apfel &>/dev/null; then
            apfel -q -s "Explain this error message concisely. What went wrong and how to fix it."
        else
            echo "${ST_RED}✗ apfel not installed${ST_RESET}"
            return 1
        fi
    fi
}

# ─────────────────────────────────────────────────────────────
# 4. Auto error interception
#    Automatically explains failed commands inline.
#    Set SMART_TERMINAL_AUTO_EXPLAIN=1 to enable (default: on)
#    Set SMART_TERMINAL_AUTO_EXPLAIN=0 to disable
# ─────────────────────────────────────────────────────────────
typeset -g SMART_TERMINAL_AUTO_EXPLAIN=${SMART_TERMINAL_AUTO_EXPLAIN:-1}
typeset -g _ST_LAST_CMD=""

function _st_preexec() {
    _ST_LAST_CMD="$1"
}

function _st_precmd() {
    local exit_code=$?

    # Skip if succeeded or no last command
    if [[ $exit_code -eq 0 ]] || [[ -z "$_ST_LAST_CMD" ]]; then
        _ST_LAST_CMD=""
        return
    fi

    # Skip our own functions and common non-errors
    if [[ "$_ST_LAST_CMD" =~ "^(\?|ask|explain|port|summarize|git-changes|ai |smart-commit)" ]]; then
        _ST_LAST_CMD=""
        return
    fi

    # Skip grep/find returning "not found" (exit 1 is normal)
    if [[ $exit_code -eq 1 ]] && [[ "$_ST_LAST_CMD" =~ "^(grep|find|which|command)" ]]; then
        _ST_LAST_CMD=""
        return
    fi

    # Store for explain-last
    typeset -g _ST_FAILED_CMD="$_ST_LAST_CMD"
    typeset -g _ST_FAILED_EXIT="$exit_code"

    if [[ $SMART_TERMINAL_AUTO_EXPLAIN -eq 1 ]] && command -v apfel &>/dev/null; then
        # Re-run silently to capture stderr, then explain
        echo ""
        echo "${ST_YELLOW}⟩ Command failed (exit $exit_code). Explaining...${ST_RESET}"
        local err_text
        err_text=$(eval "$_ST_LAST_CMD" 2>&1 >/dev/null 2>&1 | tail -5)
        # If re-run didn't produce output, construct context from the command itself
        if [[ -z "$err_text" ]]; then
            err_text="Command '$_ST_LAST_CMD' exited with code $exit_code"
        fi
        local explanation
        explanation=$(apfel -q --permissive -s "Explain this shell error in 1-2 short sentences. What went wrong and how to fix it. Be direct and practical." "$err_text" 2>/dev/null)
        if [[ -n "$explanation" ]]; then
            echo "${ST_DIM}  $explanation${ST_RESET}"
        fi
    else
        echo ""
        echo "${ST_YELLOW}⟩ Command failed (exit $exit_code).${ST_RESET} ${ST_DIM}Run 'explain-last' to get an explanation.${ST_RESET}"
    fi

    _ST_LAST_CMD=""
}

function explain-last() {
    if [[ -z "$_ST_FAILED_CMD" ]]; then
        echo "${ST_DIM}No recent failed command to explain.${ST_RESET}"
        return 1
    fi

    echo "${ST_CYAN}⟩ Explaining:${ST_RESET} ${ST_DIM}$_ST_FAILED_CMD${ST_RESET}"
    echo ""

    local err
    err=$(eval "$_ST_FAILED_CMD" 2>&1 >/dev/null)

    if [[ -n "$err" ]]; then
        echo "$err" | explain
    else
        echo "${ST_DIM}No error output captured. The command may have failed silently.${ST_RESET}"
    fi
}

# ─────────────────────────────────────────────────────────────
# 5. Git utilities
# ─────────────────────────────────────────────────────────────

function what-did-i-do() {
    local since="${1:-yesterday}"
    if command -v apfel-gitsum &>/dev/null; then
        git log --since="$since" --author="$(git config user.name)" --oneline 2>/dev/null | apfel-gitsum
    else
        git log --since="$since" --author="$(git config user.name)" --oneline 2>/dev/null
    fi
}

function smart-commit() {
    local msg
    if command -v apfel-gitsum &>/dev/null; then
        msg=$(git diff --cached | apfel-gitsum 2>/dev/null)
    elif command -v apfel &>/dev/null; then
        msg=$(git diff --cached | apfel -q -s "Generate a concise git commit message for this diff. Output only the message, no explanation." 2>/dev/null)
    fi

    if [[ -z "$msg" ]]; then
        echo "${ST_RED}✗ No staged changes or could not generate message.${ST_RESET}"
        return 1
    fi

    echo "${ST_GREEN}Suggested commit message:${ST_RESET}"
    echo "  $msg"
    echo ""
    echo -n "${ST_DIM}Use this message? [Y/n/e(dit)]:${ST_RESET} "

    local confirm
    read -r confirm

    case "$confirm" in
        [Nn]) echo "${ST_DIM}Cancelled.${ST_RESET}" ;;
        [Ee]) git commit -e -m "$msg" ;;
        *)    git commit -m "$msg" ;;
    esac
}

# ─────────────────────────────────────────────────────────────
# 6. Command Memory
#    Remembers commands you run via ? and lets you recall them.
#    Usage: recall deploy    → shows last command matching "deploy"
#           recall           → shows recent smart-terminal commands
# ─────────────────────────────────────────────────────────────
typeset -g _ST_MEMORY_FILE="${SMART_TERMINAL_DIR}/memory.log"

# Save a command to memory (called internally after ? executes)
_st_remember() {
    local query="$1"
    local cmd="$2"
    [[ -z "$cmd" ]] && return
    # Store as: timestamp | query | command
    echo "$(date '+%Y-%m-%d %H:%M') | $query | $cmd" >> "$_ST_MEMORY_FILE"
    # Keep only last 200 entries
    if [[ $(wc -l < "$_ST_MEMORY_FILE" 2>/dev/null) -gt 200 ]]; then
        tail -100 "$_ST_MEMORY_FILE" > "${_ST_MEMORY_FILE}.tmp" && mv "${_ST_MEMORY_FILE}.tmp" "$_ST_MEMORY_FILE"
    fi
}

# Recall a previous command by keyword
function recall() {
    if [[ ! -f "$_ST_MEMORY_FILE" ]]; then
        echo "${ST_DIM}No command history yet. Use ? to run some commands first.${ST_RESET}"
        return 1
    fi

    if [[ -z "$1" ]]; then
        # Show last 10
        echo "${ST_CYAN}Recent commands:${ST_RESET}"
        tail -10 "$_ST_MEMORY_FILE" | while IFS='|' read -r ts query cmd; do
            echo "  ${ST_DIM}$ts${ST_RESET} ${ST_GREEN}$cmd${ST_RESET}  ${ST_DIM}($query)${ST_RESET}"
        done
        return 0
    fi

    # Search by keyword
    local keyword="${(L)1}"
    local matches=$(grep -i "$keyword" "$_ST_MEMORY_FILE" | tail -5)
    if [[ -z "$matches" ]]; then
        echo "${ST_DIM}No commands matching '$1' in memory.${ST_RESET}"
        return 1
    fi

    echo "${ST_CYAN}Commands matching '$1':${ST_RESET}"
    echo "$matches" | while IFS='|' read -r ts query cmd; do
        echo "  ${ST_DIM}$ts${ST_RESET} ${ST_GREEN}$cmd${ST_RESET}  ${ST_DIM}($query)${ST_RESET}"
    done

    # Offer to run the last match
    local last_cmd=$(echo "$matches" | tail -1 | cut -d'|' -f3 | sed 's/^ //')
    echo ""
    echo -n "${ST_DIM}Run '$last_cmd'? [Y/n]:${ST_RESET} "
    local confirm
    read -r confirm
    if [[ ! "$confirm" =~ ^[Nn]$ ]]; then
        eval "$last_cmd"
    fi
}

# Tab completion for recall — completes from command history keywords
_st_recall_completion() {
    if [[ -f "$_ST_MEMORY_FILE" ]]; then
        local -a words
        words=(${(f)"$(cut -d'|' -f2 "$_ST_MEMORY_FILE" 2>/dev/null | tr ' ' '\n' | sort -u | grep -v '^$')"})
        compadd -a words
    fi
}
# ─────────────────────────────────────────────────────────────
# Register hooks
# ─────────────────────────────────────────────────────────────
autoload -Uz add-zsh-hook
add-zsh-hook preexec _st_preexec
add-zsh-hook precmd _st_precmd

if (( $+functions[compdef] )); then
    compdef _st_recall_completion recall
else
    # Defer until compinit is loaded
    autoload -Uz compinit
    _st_deferred_compdef() {
        compdef _st_recall_completion recall
        add-zsh-hook -d precmd _st_deferred_compdef
    }
    add-zsh-hook precmd _st_deferred_compdef
fi

# ─────────────────────────────────────────────────────────────
# Alias: ? → ask (noglob prevents zsh from treating ? as a glob)
# ─────────────────────────────────────────────────────────────
alias '?'='noglob ask'

# ─────────────────────────────────────────────────────────────
# 7. Smart Terminal meta commands
# ─────────────────────────────────────────────────────────────
function smart-terminal() {
    local version=$(cat "${SMART_TERMINAL_DIR}/VERSION" 2>/dev/null || echo "unknown")
    case "${1:-}" in
        --version|-v|version)
            echo "smart-terminal v${version}"
            ;;
        update)
            echo "${ST_CYAN}⟩ Updating Smart Terminal...${ST_RESET}"
            local repo_dir=""
            # Find the git repo
            if [[ -d "${SMART_TERMINAL_DIR}/.git" ]]; then
                repo_dir="${SMART_TERMINAL_DIR}"
            else
                # Search for the cloned repo
                repo_dir=$(find "$HOME" -maxdepth 4 -type d -name "smart-terminal" -path "*/.git/.." 2>/dev/null | head -1)
                if [[ -z "$repo_dir" ]]; then
                    repo_dir=$(find "$HOME" -maxdepth 4 -type d -name "smart-terminal" 2>/dev/null | while read d; do [[ -d "$d/.git" ]] && echo "$d" && break; done)
                fi
            fi
            if [[ -z "$repo_dir" ]] || [[ ! -d "$repo_dir/.git" ]]; then
                echo "${ST_RED}✗ Could not find smart-terminal git repo.${ST_RESET}"
                echo "${ST_DIM}Clone it first: git clone https://github.com/TGvenomYT/smart-terminal.git${ST_RESET}"
                return 1
            fi
            echo "${ST_DIM}  Pulling latest from $repo_dir...${ST_RESET}"
            (cd "$repo_dir" && git pull 2>&1) || {
                echo "${ST_RED}✗ git pull failed${ST_RESET}"
                return 1
            }
            echo "${ST_DIM}  Reinstalling...${ST_RESET}"
            (cd "$repo_dir" && ./install.sh)
            echo ""
            echo "${ST_GREEN}✓ Updated to v$(cat "${SMART_TERMINAL_DIR}/VERSION" 2>/dev/null || echo "?")${ST_RESET}"
            echo "${ST_DIM}Reload your shell: source ~/.zshrc${ST_RESET}"
            ;;
        help|--help|-h|"")
            local v=$(cat "${SMART_TERMINAL_DIR}/VERSION" 2>/dev/null || echo "?")
            echo "smart-terminal v${v} — Local AI-powered shell for macOS"
            echo ""
            echo "Commands:"
            echo "  smart-terminal --version    Show version"
            echo "  smart-terminal update       Pull latest and reinstall"
            echo "  smart-terminal help         Show this help"
            echo ""
            echo "Shell commands:"
            echo "  ? <query>                   Natural language → shell command"
            echo "  ask <query>                 Same as ?"
            echo "  recall [keyword]            Recall previous commands"
            echo "  explain <error>             Explain an error"
            echo "  explain-last                Explain the last failed command"
            echo "  port <number>               Check what's using a port"
            echo "  smart-commit                Generate git commit message"
            echo "  what-did-i-do [since]       Summarize git activity"
            echo ""
            echo "CLI tools:"
            echo "  ai [question]               Chat with local AI"
            echo "  summarize <file>            Summarize a document"
            echo "  git-changes [mode]          Explain code changes"
            echo "  ocr-explain [image]         Screenshot → OCR → explain"
            ;;
        *)
            echo "${ST_RED}Unknown command: $1${ST_RESET}"
            echo "${ST_DIM}Run 'smart-terminal help' for usage.${ST_RESET}"
            return 1
            ;;
    esac
}

# ─────────────────────────────────────────────────────────────
# Startup
# ─────────────────────────────────────────────────────────────
if [[ "${SMART_TERMINAL_QUIET:-0}" -ne 1 ]]; then
    echo "${ST_DIM}Smart Terminal loaded. Try: ? show disk usage by folder${ST_RESET}"
fi
