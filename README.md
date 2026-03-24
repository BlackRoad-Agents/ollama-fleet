# ollama-fleet

Manage Ollama models across the BlackRoad Pi fleet from a single command.

## Nodes

| Node | IP | Role |
|------|-----|------|
| Cecilia | 192.168.4.96 | Primary inference (Hailo-8) |
| Octavia | 192.168.4.101 | Secondary inference (Hailo-8) |
| Lucidia | 192.168.4.38 | Tertiary inference |

## Commands

```bash
./fleet.sh status              # Check all nodes
./fleet.sh list                # List models on all nodes
./fleet.sh pull qwen2.5:1.5b   # Pull model to all nodes
./fleet.sh benchmark qwen2.5   # Run inference benchmark
./fleet.sh run qwen2.5 "hello" # Run a prompt
```

## Custom Model

```bash
ollama create blackroad -f Modelfile.blackroad
```

Creates a BlackRoad-branded model based on qwen2.5:1.5b with sovereign system prompt.

## Part of BlackRoad-Agents

Remember the Road. Pave Tomorrow.

BlackRoad OS, Inc. — Incorporated 2025.
