#!/bin/bash
# Ollama Fleet Manager — manage Ollama across BlackRoad Pi nodes
# Usage: ./fleet.sh <command> [args]

set -e

NODES=("192.168.4.96" "192.168.4.101" "192.168.4.38")
NODE_NAMES=("Cecilia" "Octavia" "Lucidia")
OLLAMA_PORT=11434
PINK='\033[38;5;205m'
GREEN='\033[38;5;82m'
AMBER='\033[38;5;214m'
RED='\033[38;5;196m'
RESET='\033[0m'

log() { echo -e "${PINK}[fleet]${RESET} $*"; }
ok()  { echo -e "  ${GREEN}OK${RESET} $*"; }
err() { echo -e "  ${RED}FAIL${RESET} $*"; }

cmd_status() {
    log "Checking Ollama status across fleet..."
    for i in "${!NODES[@]}"; do
        node="${NODES[$i]}"
        name="${NODE_NAMES[$i]}"
        if curl -sf --connect-timeout 3 "http://$node:$OLLAMA_PORT/api/tags" > /dev/null 2>&1; then
            models=$(curl -sf "http://$node:$OLLAMA_PORT/api/tags" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('models',[])))" 2>/dev/null || echo "?")
            ok "$name ($node) — online, $models models"
        else
            err "$name ($node) — offline or unreachable"
        fi
    done
}

cmd_list() {
    log "Listing models across fleet..."
    for i in "${!NODES[@]}"; do
        node="${NODES[$i]}"
        name="${NODE_NAMES[$i]}"
        echo -e "\n${AMBER}$name ($node):${RESET}"
        resp=$(curl -sf --connect-timeout 3 "http://$node:$OLLAMA_PORT/api/tags" 2>/dev/null)
        if [ -n "$resp" ]; then
            echo "$resp" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for m in data.get('models', []):
    name = m['name']
    size = m.get('size', 0)
    size_gb = size / (1024**3)
    print(f'  {name:40s} {size_gb:.1f}GB')
" 2>/dev/null || echo "  (parse error)"
        else
            echo "  (unreachable)"
        fi
    done
}

cmd_pull() {
    local model="$1"
    if [ -z "$model" ]; then
        echo "Usage: fleet.sh pull <model>"
        exit 1
    fi
    log "Pulling $model to all nodes..."
    for i in "${!NODES[@]}"; do
        node="${NODES[$i]}"
        name="${NODE_NAMES[$i]}"
        log "Pulling on $name ($node)..."
        if curl -sf --connect-timeout 5 -X POST "http://$node:$OLLAMA_PORT/api/pull" \
            -d "{\"name\":\"$model\",\"stream\":false}" > /dev/null 2>&1; then
            ok "$name — pulled $model"
        else
            err "$name — failed to pull $model"
        fi
    done
}

cmd_benchmark() {
    local model="${1:-qwen2.5:1.5b}"
    local prompt="Explain what BlackRoad OS is in exactly two sentences."
    log "Benchmarking $model across fleet..."
    for i in "${!NODES[@]}"; do
        node="${NODES[$i]}"
        name="${NODE_NAMES[$i]}"
        start_ms=$(python3 -c "import time; print(int(time.time()*1000))")
        resp=$(curl -sf --connect-timeout 10 -X POST "http://$node:$OLLAMA_PORT/api/generate" \
            -d "{\"model\":\"$model\",\"prompt\":\"$prompt\",\"stream\":false}" 2>/dev/null)
        end_ms=$(python3 -c "import time; print(int(time.time()*1000))")
        if [ -n "$resp" ]; then
            elapsed=$(( end_ms - start_ms ))
            tokens=$(echo "$resp" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('eval_count',0))" 2>/dev/null || echo "?")
            eval_dur=$(echo "$resp" | python3 -c "import sys,json; d=json.load(sys.stdin); dur=d.get('eval_duration',0); print(f'{dur/1e9:.2f}s')" 2>/dev/null || echo "?")
            tps=$(echo "$resp" | python3 -c "
import sys,json
d=json.load(sys.stdin)
tokens=d.get('eval_count',0)
dur=d.get('eval_duration',1)
print(f'{tokens/(dur/1e9):.1f}')
" 2>/dev/null || echo "?")
            ok "$name — ${elapsed}ms total, $tokens tokens, $tps tok/s, eval: $eval_dur"
        else
            err "$name — no response (model may not be available)"
        fi
    done
}

cmd_run() {
    local model="${1:-qwen2.5:1.5b}"
    local prompt="${2:-Hello from BlackRoad}"
    local node="${NODES[0]}"
    log "Running on ${NODE_NAMES[0]} ($node)..."
    curl -sf -X POST "http://$node:$OLLAMA_PORT/api/generate" \
        -d "{\"model\":\"$model\",\"prompt\":\"$prompt\",\"stream\":false}" 2>/dev/null | \
        python3 -c "import sys,json; print(json.load(sys.stdin).get('response','(no response)'))"
}

case "${1:-help}" in
    status)    cmd_status ;;
    list)      cmd_list ;;
    pull)      cmd_pull "$2" ;;
    benchmark) cmd_benchmark "$2" ;;
    run)       cmd_run "$2" "$3" ;;
    *)
        echo "Ollama Fleet Manager — BlackRoad OS"
        echo ""
        echo "Usage: ./fleet.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  status              Check all nodes"
        echo "  list                List models on all nodes"
        echo "  pull <model>        Pull model to all nodes"
        echo "  benchmark [model]   Run inference benchmark"
        echo "  run [model] [prompt] Run a prompt on first available node"
        ;;
esac
