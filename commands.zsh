#!/usr/bin/env zsh
# ─────────────────────────────────────────────────────────────
# Smart Terminal — Intelligent Command Dictionary
# Deterministic, fast, accurate. No LLM needed for 95%+ of queries.
# ─────────────────────────────────────────────────────────────

# ─── HELPERS ───

# Fuzzy folder finder: resolves partial/misspelled names to real paths
_st_find_folder() {
    local target="$1"
    local found=""

    # 1. Check well-known folders (case-insensitive)
    case "${(L)target}" in
        download*) found="$HOME/Downloads" ;;
        document*) found="$HOME/Documents" ;;
        desktop*) found="$HOME/Desktop" ;;
        project*) found="$HOME/Projects" ;;
        developer*) found="$HOME/Developer" ;;
        application*) found="/Applications" ;;
        music*) found="$HOME/Music" ;;
        picture*|photo*) found="$HOME/Pictures" ;;
        movie*|video*) found="$HOME/Movies" ;;
        library*) found="$HOME/Library" ;;
        home*) found="$HOME" ;;
        tmp*|temp*) found="/tmp" ;;
        root*) found="/" ;;
    esac

    if [[ -n "$found" ]] && [[ -d "$found" ]]; then
        echo "$found"; return 0
    fi

    # 2. Current directory children (immediate)
    local match=$(find . -maxdepth 1 -type d -iname "$target" 2>/dev/null | head -1)
    if [[ -n "$match" ]]; then
        echo "$match"; return 0
    fi

    # 3. Search the entire home directory (up to depth 4, fast timeout)
    match=$(find "$HOME" -maxdepth 4 -type d -iname "$target" \
        -not -path "*/.*" \
        -not -path "*/node_modules/*" \
        -not -path "*/Library/*" \
        -not -path "*/.Trash/*" \
        2>/dev/null | head -1)
    if [[ -n "$match" ]]; then
        echo "$match"; return 0
    fi

    # 4. Fuzzy: prefix match across home
    match=$(find "$HOME" -maxdepth 3 -type d -iname "${target}*" \
        -not -path "*/.*" \
        -not -path "*/node_modules/*" \
        -not -path "*/Library/*" \
        -not -path "*/.Trash/*" \
        2>/dev/null | head -1)
    if [[ -n "$match" ]]; then
        echo "$match"; return 0
    fi

    return 1
}

# Extract a number from query
_st_extract_number() {
    echo "$1" | grep -oE '[0-9]+' | tail -1
}

# Extract file extension pattern from query
_st_extract_extension() {
    local q="$1"
    case "$q" in
        *python*|*".py"*) echo "*.py" ;;
        *javascript*|*" js "*|*".js"*) echo "*.js" ;;
        *typescript*|*" ts "*|*".ts"*) echo "*.ts" ;;
        *swift*) echo "*.swift" ;;
        *rust*|*".rs"*) echo "*.rs" ;;
        *java*) echo "*.java" ;;
        *ruby*|*".rb"*) echo "*.rb" ;;
        *go*|*golang*|*".go"*) echo "*.go" ;;
        *css*) echo "*.css" ;;
        *html*) echo "*.html" ;;
        *json*) echo "*.json" ;;
        *yaml*|*yml*) echo "*.yml" ;;
        *markdown*|*" md "*|*".md"*) echo "*.md" ;;
        *text*|*" txt "*|*".txt"*) echo "*.txt" ;;
        *log*) echo "*.log" ;;
        *image*|*png*|*jpg*) echo "*.{png,jpg,jpeg,gif,webp}" ;;
        *pdf*) echo "*.pdf" ;;
        *zip*|*archive*) echo "*.{zip,tar.gz,tgz,rar}" ;;
        *) echo "" ;;
    esac
}

# Extract search term from "search for X" / "grep X" / "find X in files"
_st_extract_search_term() {
    local q="$1"
    local term=""
    # "search for TERM" / "search TERM"
    if [[ "$q" =~ "search for (.+)" ]]; then
        term="${match[1]}"
    elif [[ "$q" =~ "search (.+) in" ]]; then
        term="${match[1]}"
    elif [[ "$q" =~ "grep (.+)" ]]; then
        term="${match[1]}"
    elif [[ "$q" =~ "find (.+) in files" ]]; then
        term="${match[1]}"
    elif [[ "$q" =~ "containing (.+)" ]]; then
        term="${match[1]}"
    fi
    # Clean up common suffixes
    term="${term% in *}"
    term="${term% from *}"
    term="${term% across *}"
    echo "$term"
}

# Extract folder target from "in FOLDER" / "from FOLDER"
_st_extract_location() {
    local q="$1"
    local loc=""
    if [[ "$q" =~ "in ([a-zA-Z0-9_/~.-]+)" ]]; then
        loc="${match[1]}"
    elif [[ "$q" =~ "from ([a-zA-Z0-9_/~.-]+)" ]]; then
        loc="${match[1]}"
    fi
    # Skip common false matches
    case "$loc" in
        files|all|the|this|my|finder|terminal) loc="" ;;
    esac
    echo "$loc"
}

# ─── PROJECT TYPE DETECTION ───

_st_detect_project() {
    # Returns: node, python, rust, go, java, ruby, docker, unknown
    if [[ -f "package.json" ]]; then echo "node"
    elif [[ -f "requirements.txt" ]] || [[ -f "setup.py" ]] || [[ -f "pyproject.toml" ]] || [[ -f "Pipfile" ]]; then echo "python"
    elif [[ -f "Cargo.toml" ]]; then echo "rust"
    elif [[ -f "go.mod" ]]; then echo "go"
    elif [[ -f "pom.xml" ]] || [[ -f "build.gradle" ]]; then echo "java"
    elif [[ -f "Gemfile" ]]; then echo "ruby"
    elif [[ -f "docker-compose.yml" ]] || [[ -f "docker-compose.yaml" ]] || [[ -f "Dockerfile" ]]; then echo "docker"
    elif [[ -f "Makefile" ]]; then echo "make"
    else echo "unknown"
    fi
}

# Smart entry point finder for Python projects
_st_find_python_entry() {
    # 1. Check pyproject.toml for scripts
    if [[ -f "pyproject.toml" ]]; then
        local script=$(grep -A5 '\[project.scripts\]' pyproject.toml 2>/dev/null | grep '=' | head -1 | cut -d'=' -f1 | tr -d ' ')
        if [[ -n "$script" ]]; then
            echo "$script"; return 0
        fi
    fi

    # 2. Check Makefile for a run target
    if [[ -f "Makefile" ]]; then
        if grep -q '^run:' Makefile 2>/dev/null; then
            echo "make run"; return 0
        fi
    fi

    # 3. Check Procfile
    if [[ -f "Procfile" ]]; then
        local cmd=$(grep '^web:' Procfile 2>/dev/null | cut -d':' -f2- | sed 's/^ //')
        if [[ -n "$cmd" ]]; then
            echo "$cmd"; return 0
        fi
    fi

    # 4. Scan for files with if __name__ == "__main__"
    local main_files=()
    for f in *.py **/*.py; do
        [[ -f "$f" ]] || continue
        # Skip test files, setup files, __init__
        [[ "$f" == test_* ]] || [[ "$f" == *test*.py ]] || [[ "$f" == setup.py ]] || [[ "$f" == conftest.py ]] || [[ "$f" == __* ]] && continue
        if grep -q '__name__.*__main__\|if __name__' "$f" 2>/dev/null; then
            main_files+=("$f")
        fi
    done

    # If exactly one main file found, use it
    if [[ ${#main_files[@]} -eq 1 ]]; then
        echo "python3 ${main_files[1]}"; return 0
    fi

    # If multiple, prefer common names
    for name in main.py app.py server.py run.py cli.py; do
        for f in "${main_files[@]}"; do
            if [[ "$(basename $f)" == "$name" ]]; then
                echo "python3 $f"; return 0
            fi
        done
    done

    # If still multiple, use the first one (usually top-level)
    if [[ ${#main_files[@]} -gt 0 ]]; then
        echo "python3 ${main_files[1]}"; return 0
    fi

    # 5. Fallback: check for common entry point names
    for f in main.py app.py server.py run.py manage.py cli.py; do
        if [[ -f "$f" ]]; then
            echo "python3 $f"; return 0
        fi
    done

    # 6. Check subdirectories one level deep
    for f in */main.py */app.py */cli.py; do
        if [[ -f "$f" ]]; then
            echo "python3 $f"; return 0
        fi
    done

    echo "python3 ."; return 0
}

# Smart entry point for Node.js projects
_st_find_node_entry() {
    # 1. Check package.json scripts
    if [[ -f "package.json" ]]; then
        # Check for dev script
        if grep -q '"dev"' package.json 2>/dev/null; then
            echo "npm run dev"; return 0
        fi
        # Check for start script
        if grep -q '"start"' package.json 2>/dev/null; then
            echo "npm start"; return 0
        fi
        # Check main field
        local main_file=$(grep '"main"' package.json 2>/dev/null | head -1 | cut -d'"' -f4)
        if [[ -n "$main_file" ]] && [[ -f "$main_file" ]]; then
            echo "node $main_file"; return 0
        fi
    fi
    echo "npm start"; return 0
}

# ─── MAIN LOOKUP FUNCTION ───

_st_lookup_command() {
    local q="${(L)1}"  # lowercase the query

    # ─── CONTEXT-AWARE COMMANDS ───
    # "run", "test", "build", "start", "install deps" etc. adapt to project type
    local project_type=$(_st_detect_project)

    case "$q" in
        "run"|*"run project"*|*"run app"*|*"start app"*|*"run server"*|*"start server"*|*"run this"*)
            case "$project_type" in
                node) _st_find_node_entry; return 0 ;;
                python) _st_find_python_entry; return 0 ;;
                rust) echo "cargo run"; return 0 ;;
                go) echo "go run ."; return 0 ;;
                java) echo "./gradlew run 2>/dev/null || mvn exec:java"; return 0 ;;
                ruby) echo "bundle exec rails server 2>/dev/null || ruby main.rb"; return 0 ;;
                docker) echo "docker compose up -d"; return 0 ;;
                make) echo "make run"; return 0 ;;
                *) ;;
            esac ;;
        "test"|*"run test"*|*"run the test"*|*"execute test"*)
            case "$project_type" in
                node) echo "npm test"; return 0 ;;
                python) echo "pytest"; return 0 ;;
                rust) echo "cargo test"; return 0 ;;
                go) echo "go test ./..."; return 0 ;;
                java) echo "./gradlew test 2>/dev/null || mvn test"; return 0 ;;
                ruby) echo "bundle exec rspec"; return 0 ;;
                make) echo "make test"; return 0 ;;
                *) ;;
            esac ;;
        "build"|*"build project"*|*"build this"*|*"compile"*)
            case "$project_type" in
                node) echo "npm run build"; return 0 ;;
                python) echo "python3 -m build"; return 0 ;;
                rust) echo "cargo build"; return 0 ;;
                go) echo "go build ./..."; return 0 ;;
                java) echo "./gradlew build 2>/dev/null || mvn package"; return 0 ;;
                make) echo "make"; return 0 ;;
                docker) echo "docker compose build"; return 0 ;;
                *) ;;
            esac ;;
        *"install"*"dep"*|*"install"*"package"*|"install")
            case "$project_type" in
                node) echo "npm install"; return 0 ;;
                python)
                    if [[ -f "requirements.txt" ]]; then echo "pip3 install -r requirements.txt"
                    elif [[ -f "pyproject.toml" ]]; then echo "pip3 install -e ."
                    elif [[ -f "Pipfile" ]]; then echo "pipenv install"
                    else echo "pip3 install"
                    fi; return 0 ;;
                rust) echo "cargo fetch"; return 0 ;;
                go) echo "go mod download"; return 0 ;;
                ruby) echo "bundle install"; return 0 ;;
                *) ;;
            esac ;;
        "lint"|*"run lint"*|*"check lint"*|*"lint"*"code"*)
            case "$project_type" in
                node) echo "npm run lint"; return 0 ;;
                python) echo "ruff check . 2>/dev/null || flake8 ."; return 0 ;;
                rust) echo "cargo clippy"; return 0 ;;
                go) echo "golangci-lint run"; return 0 ;;
                *) ;;
            esac ;;
        "format"|*"format code"*|*"prettify"*|*"auto format"*)
            case "$project_type" in
                node) echo "npx prettier --write ."; return 0 ;;
                python) echo "ruff format . 2>/dev/null || black ."; return 0 ;;
                rust) echo "cargo fmt"; return 0 ;;
                go) echo "gofmt -w ."; return 0 ;;
                *) ;;
            esac ;;
        "clean"|*"clean project"*|*"clean build"*)
            case "$project_type" in
                node) echo "rm -rf node_modules dist .next out"; return 0 ;;
                python) echo "find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null; rm -rf dist build *.egg-info"; return 0 ;;
                rust) echo "cargo clean"; return 0 ;;
                go) echo "go clean"; return 0 ;;
                java) echo "./gradlew clean 2>/dev/null || mvn clean"; return 0 ;;
                docker) echo "docker compose down --rmi local -v"; return 0 ;;
                make) echo "make clean"; return 0 ;;
                *) ;;
            esac ;;
    esac

    # ─── EARLY macOS PATTERNS (must come before navigation) ───
    case "$q" in
        *"open"*"system"*"pref"*|*"open"*"settings"*|*"system preferences"*|*"system settings"*)
            echo "open 'x-apple.systempreferences:'"; return 0 ;;
        *"open"*"terminal"*)
            echo "open -a Terminal"; return 0 ;;
        *"open"*"safari"*)
            echo "open -a Safari"; return 0 ;;
        *"open"*"chrome"*)
            echo "open -a 'Google Chrome'"; return 0 ;;
        *"open"*"vscode"*|*"open"*"code"*)
            echo "code ."; return 0 ;;
    esac

    # ─── NAVIGATION (smart path resolution) ───
    # Patterns: "go to X", "cd X", "open X", just "X" (single word folder name)
    local nav_target=""
    if [[ "$q" =~ "^(go to|cd|navigate to|switch to|change to|move to|open) (.+)" ]]; then
        nav_target="${match[2]}"
        # Strip trailing "folder", "directory", "dir"
        nav_target="${nav_target% folder}"
        nav_target="${nav_target% directory}"
        nav_target="${nav_target% dir}"
        nav_target="${nav_target% in finder}"
    fi

    # "open X in finder" → open command
    if [[ "$q" =~ "open (.+) in finder" ]]; then
        local open_target="${match[1]}"
        open_target="${open_target% folder}"
        local resolved=$(_st_find_folder "$open_target")
        if [[ -n "$resolved" ]]; then
            echo "open $resolved"; return 0
        fi
        echo "open ."; return 0
    fi

    # Navigation with target
    if [[ -n "$nav_target" ]]; then
        # Special cases
        case "$nav_target" in
            back|".."|-) echo "cd .."; return 0 ;;
            home|"~") echo "cd ~"; return 0 ;;
            previous) echo "cd -"; return 0 ;;
        esac
        local resolved=$(_st_find_folder "$nav_target")
        if [[ -n "$resolved" ]]; then
            echo "cd $resolved"; return 0
        fi
        # Last resort: try as literal path
        echo "cd ~/$nav_target"; return 0
    fi

    # Single word that matches a known/findable folder
    if [[ "$q" =~ "^[a-z][a-z0-9_-]+$" ]] && [[ ! "$q" =~ "^(clear|history|whoami|uptime|date|time|battery|caffeinate|stash|push|pull|mute|unmute|sleep|shutdown|reboot|alias|hostname|explain)$" ]]; then
        local resolved=$(_st_find_folder "$q")
        if [[ -n "$resolved" ]]; then
            echo "cd $resolved"; return 0
        fi
        # Folder not found anywhere — don't fall through to unrelated patterns
        return 1
    fi

    # "open here" / "open ." / "open current"
    case "$q" in
        "open here"|"open ."|"open current"*|"open this"*|"finder"|"open finder")
            echo "open ."; return 0 ;;
        "go back"|"back"|"cd .."|"..")
            echo "cd .."; return 0 ;;
        "go home"|"home"|"cd"|"cd ~")
            echo "cd ~"; return 0 ;;
    esac

    # ─── DOCKER ───
    case "$q" in
        *"docker"*"status"*|*"status"*"docker"*|*"is docker running"*|*"docker running"*|*"check docker"*|*"docker info"*|*"docker"*"up"*)
            echo "docker info 2>/dev/null && echo 'Docker is running' || echo 'Docker is not running'"; return 0 ;;
        *"restart docker desktop"*|*"restart docker"*|*"reboot docker"*)
            echo "osascript -e 'quit app \"Docker\"' && sleep 2 && open -a Docker"; return 0 ;;
        *"start docker"*|*"open docker"*|*"launch docker"*)
            echo "open -a Docker"; return 0 ;;
        *"stop docker"*|*"quit docker"*|*"close docker"*)
            echo "osascript -e 'quit app \"Docker\"'"; return 0 ;;
        *"list"*"running"*"container"*|*"running containers"*|*"docker ps"*|*"show containers"*)
            echo "docker ps"; return 0 ;;
        *"list"*"all"*"container"*|*"all containers"*|*"docker ps -a"*)
            echo "docker ps -a"; return 0 ;;
        *"stop all"*"container"*|*"stop all docker"*|*"stop everything"*)
            echo 'docker stop $(docker ps -q)'; return 0 ;;
        *"remove"*"stopped"*"container"*|*"prune"*"container"*|*"clean"*"container"*)
            echo "docker container prune -f"; return 0 ;;
        *"remove"*"all"*"container"*)
            echo 'docker rm $(docker ps -aq)'; return 0 ;;
        *"docker"*"log"*|*"container"*"log"*|*"show log"*"docker"*)
            echo "docker logs --tail 100 -f"; return 0 ;;
        *"docker"*"disk"*|*"docker"*"space"*|*"docker"*"usage"*|*"docker"*"size"*)
            echo "docker system df"; return 0 ;;
        *"docker"*"clean"*|*"docker"*"prune"*|*"docker cleanup"*)
            echo "docker system prune -f"; return 0 ;;
        *"build"*"docker"*"image"*|*"docker build"*)
            echo "docker build -t myapp ."; return 0 ;;
        *"restart"*"compose"*|*"restart"*"docker compose"*)
            echo "docker compose down && docker compose up -d"; return 0 ;;
        *"compose up"*|*"start compose"*|*"docker compose start"*|*"start"*"containers"*)
            echo "docker compose up -d"; return 0 ;;
        *"compose down"*|*"stop compose"*|*"docker compose stop"*)
            echo "docker compose down"; return 0 ;;
        *"compose log"*|*"compose output"*|*"docker compose log"*)
            echo "docker compose logs -f"; return 0 ;;
        *"compose build"*|*"rebuild compose"*|*"rebuild container"*)
            echo "docker compose build"; return 0 ;;
        *"compose pull"*)
            echo "docker compose pull"; return 0 ;;
        *"docker images"*|*"list"*"image"*|*"show images"*)
            echo "docker images"; return 0 ;;
        *"remove"*"dangling"*"image"*|*"prune"*"image"*|*"clean"*"image"*)
            echo "docker image prune -f"; return 0 ;;
        *"docker version"*|*"version"*"docker"*)
            echo "docker --version"; return 0 ;;
        *"docker exec"*|*"enter container"*|*"shell"*"container"*|*"exec into"*)
            echo "docker exec -it"; return 0 ;;
        *"docker stats"*|*"container stats"*|*"container resource"*)
            echo "docker stats --no-stream"; return 0 ;;
        *"docker network"*|*"list network"*)
            echo "docker network ls"; return 0 ;;
        *"docker volume"*|*"list volume"*)
            echo "docker volume ls"; return 0 ;;
    esac

    # ─── PORTS & NETWORKING ───
    case "$q" in
        *"stop"*"port"*|*"free"*"port"*|*"release"*"port"*|*"free up port"*)
            local pn=$(_st_extract_number "$q")
            [[ -n "$pn" ]] && echo "lsof -ti :${pn} | xargs kill -9" || echo "lsof -ti :<PORT> | xargs kill -9"
            return 0 ;;
        *"what"*"port"*|*"using port"*|*"on port"*|*"check port"*|*"port "*[0-9]*)
            local pn=$(_st_extract_number "$q")
            [[ -n "$pn" ]] && echo "lsof -i :${pn}" || echo "lsof -i :<PORT>"
            return 0 ;;
        *"open port"*|*"listening port"*|*"all port"*|*"list"*"port"*|*"active port"*)
            echo "lsof -i -P -n | grep LISTEN"; return 0 ;;
        *"my ip"*|*"ip address"*|*"local ip"*|*"show"*"ip"*|*"what"*"my ip"*)
            echo "ipconfig getifaddr en0"; return 0 ;;
        *"public ip"*|*"external ip"*|*"wan ip"*)
            echo "curl -s ifconfig.me"; return 0 ;;
        *"wifi"*"name"*|*"wifi"*"network"*|*"ssid"*|*"connected"*"wifi"*|*"which wifi"*)
            echo "networksetup -getairportnetwork en0"; return 0 ;;
        *"wifi"*"password"*)
            echo "security find-generic-password -wa Wi-Fi"; return 0 ;;
        *"wifi off"*|*"disable wifi"*|*"turn off wifi"*)
            echo "networksetup -setairportpower en0 off"; return 0 ;;
        *"wifi on"*|*"enable wifi"*|*"turn on wifi"*)
            echo "networksetup -setairportpower en0 on"; return 0 ;;
        *"dns lookup"*|*"resolve"*|*"nslookup"*)
            echo "dig"; return 0 ;;
        *"ping"*)
            echo "ping -c 4"; return 0 ;;
        *"open connection"*|*"network connection"*|*"active connection"*)
            echo "lsof -i -P -n"; return 0 ;;
        *"flush dns"*|*"clear dns"*|*"reset dns"*)
            echo "sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder"; return 0 ;;
        *"speed test"*|*"internet speed"*|*"bandwidth"*)
            echo "curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -"; return 0 ;;
        *"download"*"url"*|*"curl"*|*"wget"*)
            echo "curl -O"; return 0 ;;
    esac

    # ─── SYSTEM INFO ───
    case "$q" in
        *"ram"*|*"memory"*"usage"*|*"memory"*"used"*|*"how much memory"*|*"free memory"*|*"available memory"*)
            echo "memory_pressure"; return 0 ;;
        *"cpu"*"usage"*|*"cpu"*"load"*|*"show cpu"*|*"cpu"*"percent"*)
            echo "top -l 1 -n 0 | grep 'CPU usage'"; return 0 ;;
        *"battery"*|*"power"*"status"*|*"charge"*"level"*|*"how much charge"*)
            echo "pmset -g batt"; return 0 ;;
        *"uptime"*|*"how long"*"running"*|*"since"*"boot"*)
            echo "uptime"; return 0 ;;
        *"disk"*"usage"*"folder"*|*"disk"*"usage"*"by"*|*"folder size"*|*"directory size"*)
            echo "du -sh */ 2>/dev/null | sort -hr | head -20"; return 0 ;;
        *"disk"*"space"*|*"disk"*"free"*|*"storage"*|*"how much space"*|*"how much disk"*)
            echo "df -h /"; return 0 ;;
        *"running process"*|*"all process"*|*"list process"*|*"show process"*)
            echo "ps aux | head -30"; return 0 ;;
        *"top process"*|*"most cpu"*|*"cpu hog"*|*"what"*"using cpu"*)
            echo "ps -eo pid,pcpu,pmem,comm -r | head -15"; return 0 ;;
        *"most memory"*|*"memory hog"*|*"what"*"using memory"*|*"what"*"eating memory"*)
            echo "ps -eo pid,pcpu,pmem,comm -m | head -15"; return 0 ;;
        *"macos version"*|*"os version"*|*"system version"*|*"what version"*"mac"*)
            echo "sw_vers"; return 0 ;;
        *"hostname"*|*"computer name"*|*"machine name"*)
            echo "hostname"; return 0 ;;
        *"serial number"*|*"hardware info"*)
            echo "system_profiler SPHardwareDataType"; return 0 ;;
    esac

    # ─── FILES & SEARCH (smart extraction) ───
    # Handle "find X files", "find files larger than X", "search for X"
    local ext=$(_st_extract_extension "$q")
    local loc=$(_st_extract_location "$q")
    local search_path="."
    if [[ -n "$loc" ]]; then
        local resolved=$(_st_find_folder "$loc")
        [[ -n "$resolved" ]] && search_path="$resolved"
    fi

    case "$q" in
        *"find"*"larger"*|*"find"*"bigger"*|*"large files"*|*"big files"*|*"files over"*)
            local size=$(_st_extract_number "$q")
            [[ -z "$size" ]] && size="100"
            echo "find $search_path -type f -size +${size}M 2>/dev/null | head -20"; return 0 ;;
        *"find"*"file"*|*"find all"*"file"*)
            if [[ -n "$ext" ]]; then
                echo "find $search_path -type f -name '$ext' 2>/dev/null"; return 0
            fi ;;
        *"find"*"folder"*|*"find"*"director"*|*"find"*"dir"*)
            local target=""
            if [[ "$q" =~ "find.*(folder|director|dir)[a-z]* (.+)" ]]; then
                target="${match[2]}"
                target="${target%% *}"
            fi
            if [[ -n "$target" ]]; then
                echo "find . -type d -iname '*${target}*' 2>/dev/null"; return 0
            fi
            echo "find . -type d 2>/dev/null | head -30"; return 0 ;;
        *"search"*|*"grep"*|*"find"*"in files"*|*"find"*"containing"*)
            local term=$(_st_extract_search_term "$q")
            if [[ -n "$term" ]]; then
                echo "grep -rn '$term' $search_path 2>/dev/null | head -30"; return 0
            fi
            echo "grep -rn '' $search_path 2>/dev/null | head -30"; return 0 ;;
        *"count"*"file"*|*"how many file"*)
            if [[ -n "$ext" ]]; then
                echo "find $search_path -type f -name '$ext' | wc -l"
            else
                echo "find $search_path -type f | wc -l"
            fi; return 0 ;;
        *"count"*"line"*|*"how many line"*|*"line count"*)
            echo "wc -l"; return 0 ;;
        *"count"*"word"*|*"word count"*)
            echo "wc -w"; return 0 ;;
        *"recent"*"file"*|*"recently"*"modified"*|*"last modified"*)
            echo "find $search_path -type f -mtime -1 2>/dev/null | head -20"; return 0 ;;
        *"empty file"*|*"find empty"*)
            echo "find $search_path -type f -empty 2>/dev/null"; return 0 ;;
        *"duplicate"*|*"find duplicate"*)
            echo "find . -type f -exec md5 {} + | sort | uniq -d -w 32"; return 0 ;;
        *"tree"*|*"folder structure"*|*"directory structure"*|*"show structure"*)
            if command -v tree &>/dev/null; then
                echo "tree -L 2"
            else
                echo "find . -type d -maxdepth 2 | head -30"
            fi; return 0 ;;
        *"compress"*|*"zip"*|*"tar"*|*"archive"*)
            echo "tar -czf archive.tar.gz"; return 0 ;;
        *"extract"*|*"unzip"*|*"untar"*|*"uncompress"*)
            echo "tar -xzf"; return 0 ;;
    esac

    # ─── GIT ───
    case "$q" in
        *"what"*"change"*|*"what did i change"*|*"my changes"*|*"diff summary"*|*"summarize"*"diff"*|*"summarize"*"changes"*|*"explain"*"changes"*)
            echo "git-changes"; return 0 ;;
        *"what did i change today"*|*"today"*"changes"*|*"today"*"commit"*)
            echo "git-changes today"; return 0 ;;
        *"what did i change this week"*|*"week"*"changes"*)
            echo "git-changes week"; return 0 ;;
        *"last commit"*"change"*|*"what was"*"last commit"*|*"explain last commit"*)
            echo "git-changes last"; return 0 ;;
        *"staged changes"*|*"what"*"staged"*|*"what"*"about to commit"*)
            echo "git-changes staged"; return 0 ;;
        *"git status"*|*"show status"*|*"repo status"*)
            echo "git status"; return 0 ;;
        *"git log"*|*"recent commit"*|*"commit history"*|*"show commits"*)
            echo "git log --oneline -10"; return 0 ;;
        *"last commit"*|*"latest commit"*)
            echo "git log --oneline -1"; return 0 ;;
        *"git diff"*|*"show diff"*|*"what"*"different"*)
            echo "git diff"; return 0 ;;
        *"git branch"*|*"list branch"*|*"all branch"*|*"show branch"*|*"current branch"*)
            echo "git branch -a"; return 0 ;;
        *"switch"*"branch"*|*"checkout"*"branch"*)
            echo "git checkout"; return 0 ;;
        *"new branch"*|*"create branch"*)
            echo "git checkout -b"; return 0 ;;
        *"merge"*"branch"*)
            echo "git merge"; return 0 ;;
        *"delete"*"branch"*)
            echo "git branch -d"; return 0 ;;
        *"undo"*"commit"*|*"uncommit"*|*"reset last commit"*)
            echo "git reset --soft HEAD~1"; return 0 ;;
        *"undo"*"change"*|*"discard"*"change"*|*"reset"*"change"*)
            echo "git checkout -- ."; return 0 ;;
        *"stash"*"save"*|*"stash"*"change"*|"stash")
            echo "git stash"; return 0 ;;
        *"stash"*"pop"*|*"stash"*"apply"*|*"unstash"*)
            echo "git stash pop"; return 0 ;;
        *"stash"*"list"*)
            echo "git stash list"; return 0 ;;
        *"git pull"*|*"pull latest"*|*"pull"*"remote"*|*"update repo"*)
            echo "git pull"; return 0 ;;
        *"git push"*|*"push"*"remote"*|*"push"*"change"*)
            echo "git push"; return 0 ;;
        *"git clone"*|*"clone"*"repo"*)
            echo "git clone"; return 0 ;;
        *"git add"*|*"stage"*"file"*|*"stage"*"change"*|*"stage all"*|*"add all"*)
            echo "git add -A"; return 0 ;;
        *"git remote"*|*"show remote"*|*"remote url"*)
            echo "git remote -v"; return 0 ;;
        *"blame"*|*"who wrote"*|*"who changed"*)
            echo "git blame"; return 0 ;;
        *"git tag"*|*"list tag"*|*"show tag"*)
            echo "git tag -l"; return 0 ;;
    esac

    # ─── PACKAGE MANAGERS & DEV TOOLS ───
    case "$q" in
        *"update brew"*|*"brew update"*|*"upgrade brew"*|*"brew upgrade"*)
            echo "brew update && brew upgrade"; return 0 ;;
        *"install"*"brew"*|*"brew install"*)
            echo "brew install"; return 0 ;;
        *"list"*"brew"*|*"installed packages"*|*"brew list"*|*"what"*"installed"*"brew"*)
            echo "brew list"; return 0 ;;
        *"brew search"*|*"search brew"*|*"find package"*)
            echo "brew search"; return 0 ;;
        *"brew cleanup"*|*"clean brew"*|*"brew clean"*)
            echo "brew cleanup"; return 0 ;;
        *"brew info"*|*"package info"*)
            echo "brew info"; return 0 ;;
        *"outdated"*"brew"*|*"brew outdated"*)
            echo "brew outdated"; return 0 ;;
        *"npm install"*|*"install"*"packages"*|*"install"*"dependencies"*)
            echo "npm install"; return 0 ;;
        *"npm run"*"dev"*|*"start dev"*"server"*|*"run dev"*)
            echo "npm run dev"; return 0 ;;
        *"npm run"*"build"*|*"build"*"project"*|*"run build"*)
            echo "npm run build"; return 0 ;;
        *"npm run"*"test"*|*"run test"*|*"npm test"*)
            echo "npm test"; return 0 ;;
        *"npm run"*|*"run script"*)
            echo "npm run"; return 0 ;;
        *"list npm"*|*"npm packages"*|*"npm list"*|*"installed npm"*)
            echo "npm list --depth=0"; return 0 ;;
        *"npm outdated"*|*"outdated npm"*|*"outdated packages"*)
            echo "npm outdated"; return 0 ;;
        *"pip install"*|*"pip3 install"*)
            echo "pip3 install"; return 0 ;;
        *"pip list"*|*"pip3 list"*|*"installed python"*"package"*)
            echo "pip3 list"; return 0 ;;
        *"pip freeze"*|*"requirements"*"txt"*)
            echo "pip3 freeze > requirements.txt"; return 0 ;;
        *"venv"*"create"*|*"create"*"venv"*|*"create"*"virtual"*"env"*|*"virtual"*"env"*"create"*|*"new"*"virtual"*"env"*)
            echo "python3 -m venv venv"; return 0 ;;
        *"activate"*"venv"*|*"source"*"venv"*)
            echo "source venv/bin/activate"; return 0 ;;
    esac

    # ─── COMMON TASKS ───
    case "$q" in
        *"clear"*"terminal"*|*"clear screen"*|"clear"|*"cls"*)
            echo "clear"; return 0 ;;
        *"date"*|*"today"*"date"*|*"what day"*|*"current date"*)
            echo "date"; return 0 ;;
        *"time"*|*"what time"*|*"current time"*)
            echo "date '+%H:%M:%S'"; return 0 ;;
        *"whoami"*|*"who am i"*|*"current user"*|*"my username"*)
            echo "whoami"; return 0 ;;
        *"environment variable"*|*"show env"*|*"env var"*|*"print env"*)
            echo "env | sort"; return 0 ;;
        *"edit zshrc"*|*"open zshrc"*|*"edit shell"*"config"*)
            echo "open ~/.zshrc"; return 0 ;;
        *"reload"*"terminal"*|*"reload"*"shell"*|*"reload"*"zsh"*|*"source zshrc"*|*"refresh shell"*)
            echo "source ~/.zshrc"; return 0 ;;
        *"show path"*|*"echo path"*|*"print path"*|*"list path"*)
            printf '%s\n' 'echo $PATH | tr ":" "\n"'; return 0 ;;
        *"node version"*|*"version"*"node"*|*"node -v"*)
            echo "node --version"; return 0 ;;
        *"python version"*|*"version"*"python"*|*"python -v"*|*"python3 -v"*)
            echo "python3 --version"; return 0 ;;
        *"npm version"*|*"version"*"npm"*)
            echo "npm --version"; return 0 ;;
        *"which python"*|*"where"*"python"*)
            echo "which python3"; return 0 ;;
        *"which node"*|*"where"*"node"*)
            echo "which node"; return 0 ;;
        *"which"*)
            echo "which"; return 0 ;;
        *"make executable"*|*"chmod"*"executable"*|*"make"*"runnable"*)
            echo "chmod +x"; return 0 ;;
        *"file permission"*|*"show permission"*|*"list detail"*|*"ls -l"*)
            echo "ls -la"; return 0 ;;
        *"delete"*"node_modules"*|*"remove"*"node_modules"*|*"clean"*"node_modules"*)
            echo "find . -name 'node_modules' -type d -prune -exec rm -rf {} +"; return 0 ;;
        *"history"*|*"command history"*|*"recent commands"*|*"last commands"*)
            echo "history | tail -30"; return 0 ;;
        *"alias"*|*"show alias"*|*"list alias"*)
            echo "alias"; return 0 ;;
        *"watch"*"file"*|*"monitor"*"file"*|*"watch"*"change"*)
            echo "fswatch ."; return 0 ;;
        *"tail"*"log"*|*"follow"*"log"*|*"watch"*"log"*)
            echo "tail -f"; return 0 ;;
        *"stop"*"all node"*|*"stop"*"node process"*)
            echo "pkill -f node"; return 0 ;;
        *"stop"*"all python"*|*"stop"*"python process"*)
            echo "pkill -f python"; return 0 ;;
        *"stop"*"process"*|*"end"*"process"*)
            echo "pkill -f"; return 0 ;;
        *"size of"*|*"how big is"*|*"file size"*|*"folder size"*)
            echo "du -sh"; return 0 ;;
        *"disk usage"*|*"disk space"*)
            echo "df -h /"; return 0 ;;
        *"rename"*"file"*|"mv "*)
            echo "mv"; return 0 ;;
        *"copy"*"file"*|"cp "*)
            echo "cp"; return 0 ;;
        *"remove"*"file"*|*"delete"*"file"*|"rm "*)
            echo "rm"; return 0 ;;
        *"create"*"file"*|*"touch"*|*"new file"*)
            echo "touch"; return 0 ;;
        *"create"*"folder"*|*"new folder"*|*"mkdir"*|*"create"*"directory"*|*"new directory"*)
            echo "mkdir -p"; return 0 ;;
    esac

    # ─── macOS SPECIFIC ───
    case "$q" in
        *"summarize"*|*"summary of"*|*"tldr"*"file"*)
            echo "summarize"; return 0 ;;
        *"screenshot"*"area"*|*"screenshot"*"select"*)
            echo "screencapture -i ~/Desktop/screenshot.png"; return 0 ;;
        *"screenshot"*"full"*|*"screenshot"*"screen"*|*"screenshot"*)
            echo "screencapture ~/Desktop/screenshot.png"; return 0 ;;
        *"lock screen"*|*"lock mac"*|*"lock computer"*)
            echo "pmset displaysleepnow"; return 0 ;;
        *"show hidden"*|*"hidden file"*|*"show dot file"*)
            echo "defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder"; return 0 ;;
        *"hide hidden"*|*"hide dot file"*)
            echo "defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder"; return 0 ;;
        *"trash"*"size"*|*"how big"*"trash"*)
            echo "du -sh ~/.Trash"; return 0 ;;
        *"empty trash"*|*"clear trash"*|*"clean trash"*)
            echo "rm -rf ~/.Trash/*"; return 0 ;;
        *"open"*"app"*|*"launch"*"app"*|*"start"*"app"*)
            echo "open -a"; return 0 ;;
        *"sleep"*|*"put to sleep"*|*"sleep mac"*)
            echo "pmset sleepnow"; return 0 ;;
        *"keep awake"*|*"keep"*"awake"*|*"no sleep"*|*"caffeinate"*|*"prevent sleep"*|*"stay awake"*)
            echo "caffeinate -d"; return 0 ;;
        *"shutdown"*|*"power off"*|*"turn off"*)
            echo "sudo shutdown -h now"; return 0 ;;
        *"restart"*"mac"*|*"reboot"*"mac"*|*"reboot"*"computer"*)
            echo "sudo shutdown -r now"; return 0 ;;
        *"eject"*|*"unmount"*)
            echo "diskutil unmount"; return 0 ;;
        *"dark mode"*"on"*|*"enable dark"*)
            echo "osascript -e 'tell app \"System Events\" to tell appearance preferences to set dark mode to true'"; return 0 ;;
        *"dark mode"*"off"*|*"disable dark"*|*"light mode"*)
            echo "osascript -e 'tell app \"System Events\" to tell appearance preferences to set dark mode to false'"; return 0 ;;
        *"notification"*"off"*|*"do not disturb"*|*"dnd"*"on"*)
            echo "shortcuts run 'Focus'"; return 0 ;;
        *"bluetooth"*"off"*|*"disable bluetooth"*)
            echo "blueutil --power 0"; return 0 ;;
        *"bluetooth"*"on"*|*"enable bluetooth"*)
            echo "blueutil --power 1"; return 0 ;;
        *"volume"*"up"*|*"louder"*)
            echo "osascript -e 'set volume output volume ((output volume of (get volume settings)) + 10)'"; return 0 ;;
        *"volume"*"down"*|*"quieter"*|*"softer"*)
            echo "osascript -e 'set volume output volume ((output volume of (get volume settings)) - 10)'"; return 0 ;;
        *"mute"*|*"volume"*"off"*|*"silence"*)
            echo "osascript -e 'set volume output muted true'"; return 0 ;;
        *"unmute"*|*"volume"*"on"*)
            echo "osascript -e 'set volume output muted false'"; return 0 ;;
        *"brightness"*"up"*)
            echo "brightness 0.8"; return 0 ;;
        *"brightness"*"down"*)
            echo "brightness 0.4"; return 0 ;;
        *"open"*"system"*"pref"*|*"open"*"settings"*)
            echo "open 'x-apple.systempreferences:'"; return 0 ;;
        *"list app"*|*"installed app"*|*"all app"*)
            echo "ls /Applications/"; return 0 ;;
        *"running app"*|*"open app"*|*"active app"*)
            echo "osascript -e 'tell application \"System Events\" to get name of every process whose background only is false'"; return 0 ;;
        *"force quit"*|*"force close"*|*"force stop"*)
            echo "osascript -e 'tell application \"System Events\" to set frontApp to name of first application process whose frontmost is true' -e 'tell application frontApp to quit'"; return 0 ;;
    esac

    # ─── SSH / REMOTE ───
    case "$q" in
        *"ssh"*"key"*"generate"*|*"generate"*"ssh"*|*"new ssh key"*|*"create ssh key"*)
            echo "ssh-keygen -t ed25519 -C \"\$(whoami)@\$(hostname)\""; return 0 ;;
        *"ssh"*"key"*|*"show"*"ssh"*"key"*|*"public key"*|*"cat ssh"*)
            echo "cat ~/.ssh/id_ed25519.pub 2>/dev/null || cat ~/.ssh/id_rsa.pub"; return 0 ;;
        *"ssh"*"copy"*|*"copy"*"ssh"*"key"*|*"ssh key"*"clipboard"*)
            echo "pbcopy < ~/.ssh/id_ed25519.pub 2>/dev/null || pbcopy < ~/.ssh/id_rsa.pub"; return 0 ;;
        *"ssh"*)
            echo "ssh"; return 0 ;;
    esac

    # No match
    return 1
}
