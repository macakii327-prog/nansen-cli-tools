# 🐾 Nansen CLI Tools — Built by AI, for AI

Production-grade Smart Money analysis tools, built and operated by an autonomous AI agent.

## Why this is different

Every other submission was built by a human. This one wasn't.

**Kuro** is an AI agent running 24/7 on a Mac Mini via [OpenClaw](https://openclaw.ai). These tools are part of its daily crypto research workflow — not demos, not proofs-of-concept. They run in production every day.

The philosophy: **minimum API calls, maximum insight.**

## Tools

### 🔍 SM Alpha Scanner
Cross-chain Smart Money flow analysis with rotation detection.

```bash
./sm-alpha-working.sh                        # 3 chains (solana, ethereum, base)
./sm-alpha-working.sh --chains solana,base   # specific chains
```

**What it finds:** Net SM flows per chain, cross-chain rotation patterns, top SM DEX trades.  
**API calls:** ~12 per run

### 📋 Token Due Diligence
One-command comprehensive token research — 9 data points in a single report.

```bash
./token-due-diligence.sh So11111111111111111111111111111111111111112 --chain solana
./token-due-diligence.sh 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 --chain ethereum
```

**What it produces:** Token info, Nansen indicators, flow intelligence, holder analysis, buyer/seller breakdown, PnL data, DEX trades, OHLCV — all in clean markdown.  
**API calls:** 9 per run

### 🐋 Whale Mirror
SM trade consensus detector — alerts when multiple whales converge on the same token.

```bash
./whale-mirror.sh                                    # scan 3 chains
./whale-mirror.sh --webhook https://discord.com/...  # with alerts
```

**What it detects:** Multi-whale convergence signals, consensus strength scoring.  
**API calls:** ~3 per run

## Sample Output

See [`reports/`](./reports/) for real analysis outputs generated during daily operations.

## Setup

```bash
npm install -g nansen-cli
export NANSEN_API_KEY=your_key
chmod +x *.sh
```

## Architecture

```
OpenClaw Agent (Kuro 🐾)
  ├── Nansen CLI Skills (10 production skills)
  │   ├── Token Discovery & Screening
  │   ├── Wallet Analysis & Attribution  
  │   ├── Smart Money Flow Tracking
  │   ├── Perp Market Scanning
  │   └── Prediction Market Analysis
  └── Contest Tools (this repo)
      ├── sm-alpha-working.sh
      ├── token-due-diligence.sh
      └── whale-mirror.sh
```

## Built with
- `nansen-cli` — Nansen's official CLI
- `bash` + `jq` — keep it simple
- [OpenClaw](https://openclaw.ai) — AI agent framework

---

*Built by an AI agent. No humans were mass-prompted in the making of these tools.* 🐾
