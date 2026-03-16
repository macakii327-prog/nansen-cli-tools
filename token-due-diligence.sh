#!/usr/bin/env bash
# ============================================================
# Token Due Diligence — One-Command Full Token Analysis
# Built with Nansen CLI for the #NansenCLI contest
# ============================================================
# Given a token address + chain, generates a comprehensive
# research report: flows, holders, SM activity, indicators,
# buyer/seller breakdown, and risk signals.
#
# Usage: ./token-due-diligence.sh <token_address> [--chain solana]
# ============================================================

set -euo pipefail

TOKEN=""
CHAIN="solana"
DAYS=7
OUTPUT_DIR="./reports"

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case $1 in
    --chain) CHAIN="$2"; shift 2;;
    --days) DAYS="$2"; shift 2;;
    -*) echo "Unknown option: $1"; exit 1;;
    *) TOKEN="$1"; shift;;
  esac
done

if [ -z "$TOKEN" ]; then
  echo "Usage: $0 <token_address> [--chain solana] [--days 7]"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT="$OUTPUT_DIR/dd-${CHAIN}-${TOKEN:0:8}-${TIMESTAMP}.md"

echo "# 📋 Token Due Diligence Report" > "$REPORT"
echo "_Token: \`$TOKEN\` | Chain: $CHAIN | Generated: $(date -u '+%Y-%m-%d %H:%M UTC')_" >> "$REPORT"
echo "" >> "$REPORT"

# --- 1. Token Info ---
echo "## 1. Token Overview" >> "$REPORT"
echo '```json' >> "$REPORT"
nansen research token info --chain "$CHAIN" --token "$TOKEN" --pretty 2>&1 | jq '.data' 2>/dev/null >> "$REPORT" || echo "Failed to fetch" >> "$REPORT"
echo '```' >> "$REPORT"
echo "" >> "$REPORT"

# --- 2. Nansen Indicators (Score) ---
echo "## 2. Nansen Indicators & Score" >> "$REPORT"
echo '```json' >> "$REPORT"
nansen research token indicators --chain "$CHAIN" --token "$TOKEN" --pretty 2>&1 | jq '.data' 2>/dev/null >> "$REPORT" || echo "N/A" >> "$REPORT"
echo '```' >> "$REPORT"
echo "" >> "$REPORT"

# --- 3. Net Flows ---
echo "## 3. Token Net Flows (${DAYS}d)" >> "$REPORT"
echo '```json' >> "$REPORT"
nansen research token flows --chain "$CHAIN" --token "$TOKEN" --days "$DAYS" --pretty 2>&1 | jq '.data' 2>/dev/null >> "$REPORT" || echo "N/A" >> "$REPORT"
echo '```' >> "$REPORT"
echo "" >> "$REPORT"

# --- 4. Flow Intelligence (by label) ---
echo "## 4. Flow Intelligence by Label" >> "$REPORT"
echo '```json' >> "$REPORT"
nansen research token flow-intelligence --chain "$CHAIN" --token "$TOKEN" --days "$DAYS" --pretty 2>&1 | jq '.data[:10]' 2>/dev/null >> "$REPORT" || echo "N/A" >> "$REPORT"
echo '```' >> "$REPORT"
echo "" >> "$REPORT"

# --- 5. Holder Analysis ---
echo "## 5. Top Holders" >> "$REPORT"
echo '```' >> "$REPORT"
nansen research token holders --chain "$CHAIN" --token "$TOKEN" --limit 15 \
  --fields address,label,balance_usd,percentage 2>&1 | \
  jq -r '.data[]? | "\(.label // .address[0:12])\t\(.percentage // "?")%\t$\(.balance_usd // 0 | tonumber | round)"' 2>/dev/null >> "$REPORT" || echo "N/A" >> "$REPORT"
echo '```' >> "$REPORT"
echo "" >> "$REPORT"

# --- 6. Who Bought / Sold ---
echo "## 6. Recent Buyers & Sellers" >> "$REPORT"
echo "" >> "$REPORT"

echo "### Buyers" >> "$REPORT"
echo '```' >> "$REPORT"
nansen research token who-bought-sold --chain "$CHAIN" --token "$TOKEN" --days "$DAYS" \
  --fields address,label,bought_usd,sold_usd --limit 10 2>&1 | \
  jq -r '.data[]? | select(.bought_usd != null) | "\(.label // .address[0:12])\tbought:$\(.bought_usd | tonumber | round)\tsold:$\(.sold_usd // 0 | tonumber | round)"' 2>/dev/null >> "$REPORT" || echo "N/A" >> "$REPORT"
echo '```' >> "$REPORT"
echo "" >> "$REPORT"

# --- 7. PnL Leaderboard ---
echo "## 7. PnL Leaderboard" >> "$REPORT"
echo '```' >> "$REPORT"
nansen research token pnl --chain "$CHAIN" --token "$TOKEN" --days "$DAYS" \
  --fields address,label,realized_pnl_usd,unrealized_pnl_usd --limit 10 2>&1 | \
  jq -r '.data[]? | "\(.label // .address[0:12])\trealized:$\(.realized_pnl_usd // 0 | tonumber | round)\tunrealized:$\(.unrealized_pnl_usd // 0 | tonumber | round)"' 2>/dev/null >> "$REPORT" || echo "N/A" >> "$REPORT"
echo '```' >> "$REPORT"
echo "" >> "$REPORT"

# --- 8. Recent DEX Trades ---
echo "## 8. Recent DEX Trades" >> "$REPORT"
echo '```' >> "$REPORT"
nansen research token dex-trades --chain "$CHAIN" --token "$TOKEN" --days 1 \
  --fields address,label,type,amount_usd --limit 15 2>&1 | \
  jq -r '.data[]? | "[\(.type)] \(.label // .address[0:10]) $\(.amount_usd // 0 | tonumber | round)"' 2>/dev/null >> "$REPORT" || echo "N/A" >> "$REPORT"
echo '```' >> "$REPORT"
echo "" >> "$REPORT"

# --- 9. OHLCV ---
echo "## 9. Price Action (OHLCV)" >> "$REPORT"
echo '```' >> "$REPORT"
nansen research token ohlcv --chain "$CHAIN" --token "$TOKEN" --timeframe 24h --limit 7 2>&1 | \
  jq -r '.data[]? | "\(.date // .timestamp)\tO:\(.open)\tH:\(.high)\tL:\(.low)\tC:\(.close)\tV:$\(.volume // 0 | tonumber | round)"' 2>/dev/null >> "$REPORT" || echo "N/A" >> "$REPORT"
echo '```' >> "$REPORT"
echo "" >> "$REPORT"

# --- Summary ---
echo "---" >> "$REPORT"
echo "**9 data points collected** using \`nansen-cli\` — token info, indicators, flows, flow intelligence, holders, buyers/sellers, PnL, DEX trades, OHLCV." >> "$REPORT"
echo "" >> "$REPORT"
echo "_Built with Nansen CLI v$(nansen --version 2>/dev/null || echo 'unknown') | #NansenCLI_" >> "$REPORT"

echo ""
echo "✅ Due diligence report saved: $REPORT"
cat "$REPORT"
