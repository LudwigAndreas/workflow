# QWEN.md

See [`CLAUDE.md`](./CLAUDE.md) — the working rules are identical for both
CLIs — and [`AGENTS.md`](./AGENTS.md) for the architecture behind them.

The only difference is command naming: Qwen uses `/sdd-intent` where Claude
uses `/sdd:intent`, and `/opsx-apply` where Claude uses `/opsx:apply`. The Qwen
commands are generated from the Claude ones by `make commands` — never edit
`.qwen/commands/` by hand.
