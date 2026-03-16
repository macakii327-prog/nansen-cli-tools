#!/usr/bin/env bash
# ============================================================
# Whale Mirror — SM Trade Signal Generator
# Built with Nansen CLI for the #NansenCLI contest
# ============================================================
# Monitors SM DEX trades across chains, detects consensus
# (multiple whales buying same token), and generates signals.
# Designed for cron/daemon use with Discord/Telegram webhooks.
#
# Usage: ./whale-mirror.sh [--chains sol,eth,base] [--webhook URL]
# ============================================================

set -euo pipefail

CHAINS="solana,ethereum,base"
WEBHOOK=""
LIMIT=30
OUTPUT_DIR="./reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SIGNALS_FILE="$OUTPUT_DIR/signals-${TIMESTAMP}.json"
REPORT="$OUTPUT_DIR/whale-mirror-${TIMESTAMP}.md"

while [[ $# -gt 0 ]]; do
  case $1 in
    --chains) CHAINS="$2"; shift 2;;
    --webhook) WEBHOOK="$2"; shift 2;;
    --limit) LIMIT="$2"; shift 2;;
    *) echo "Unknown: $1"; exit 1;;
  esac
done

mkdir -p "$OUTPUT_DIR"
IFS=',' read -ra CHAIN_LIST <<< "$CHAINS"

echo "# 🐋 Whale Mirror — SM Trade Signals" > "$REPORT"
echo "_$(date -u '+%Y-%m-%d %H:%M UTC')_" >> "$REPORT"
echo "" >> "$REPORT"

# Collect all SM buys across chains
ALL_TRADES=$(mktemp)

for chain in "${CHAIN_LIST[@]}"; do
  echo "⏳ Fetching SM DEX trades on $chain..."
  
  trades=$(nansen research smart-money dex-trades \
    --chain "$chain" \
    --limit "$LIMIT" \
    --fields address,token_bought_symbol,token_bought_address,bought_amount_usd,token_sold_symbol,sold_amount_usd,label \
    2>&1) || true

  # Append chain info and normalize
  echo "$trades" | jq -c --arg chain "$chain" '.data[]? | . + {chain: $chain}' 2>/dev/null >> "$ALL_TRADES" || true
done

# --- Consensus Detection ---
# Count unique buyers per token_bought
echo "## 🎯 Consensus Signals (Multiple SM Buying Same Token)" >> "$REPORT"
echo "" >> "$REPORT"

# Group by token_bought_symbol, count unique addresses
consensus=$(cat "$ALL_TRADES" | jq -s '
  group_by(.token_bought_symbol)
  | map({
      token: .[0].token_bought_symbol,
      token_address: .[0].token_bought_address,
      chains: [.[].chain] | unique,
      buyers: [.[].address] | unique | length,
      total_usd: [.[].bought_amount_usd // 0 | tonumber] | add | round,
      labels: [.[].label // empty] | unique,
      trades: length
    })
  | sort_by(-.buyers)
  | [.[] | select(.buyers >= 2)]
' 2>/dev/null || echo "[]")

echo "$consensus" | jq -r '.[]? | "### \(.token) 🔥\n- **\(.buyers) unique SM wallets** bought across \(.chains | join(", "))\n- Total volume: $\(.total_usd)\n- Trades: \(.trades)\n- Labels: \(.labels | join(", "))\n"' 2>/dev/null >> "$REPORT" || true

if [ "$(echo "$consensus" | jq 'length' 2>/dev/null || echo 0)" = "0" ]; then
  echo "_No multi-wallet consensus signals detected._" >> "$REPORT"
fi

# --- All Recent Trades Table ---
echo "" >> "$REPORT"
echo "## 📊 All SM Trades (Sorted by Size)" >> "$REPORT"
echo "" >> "$REPORT"

for chain in "${CHAIN_LIST[@]}"; do
  echo "### $chain" >> "$REPORT"
  echo '```' >> "$REPORT"
  cat "$ALL_TRADES" | jq -r --arg c "$chain" '
    select(.chain == $c) |
    "\(.label // .address[0:10]): \(.token_sold_symbol // "?") → \(.token_bought_symbol // "?")  $\(.bought_amount_usd // 0 | tonumber | round)"
  ' 2>/dev/null | sort -t'$' -k2 -rn | head -15 >> "$REPORT" || true
  echo '```' >> "$REPORT"
  echo "" >> "$REPORT"
done

# --- Save signals as JSON for downstream use ---
echo "$consensus" > "$SIGNALS_FILE"

# --- Webhook notification (optional) ---
if [ -n "$WEBHOOK" ] && [ "$(echo "$consensus" | jq 'length' 2>/dev/null || echo 0)" != "0" ]; then
  top_signal=$(echo "$consensus" | jq -r '.[0] | "🐋 **\(.token)** — \(.buyers) SM wallets buying ($\(.total_usd) total) on \(.chains | join(", "))"' 2>/dev/null)
  curl -s -H "Content-Type: application/json" \
    -d "{\"content\": \"$top_signal\"}" \
    "$WEBHOOK" > /dev/null 2>&1 || true
fi

# --- Summary ---
total_trades=$(wc -l < "$ALL_TRADES" | tr -d ' ')
echo "---" >> "$REPORT"
echo "**${total_trades} trades analyzed** across ${#CHAIN_LIST[@]} chains" >> "$REPORT"
echo "**Signals:** $(echo "$consensus" | jq 'length' 2>/dev/null || echo 0) consensus patterns detected" >> "$REPORT"
echo "" >> "$REPORT"
echo "_Built with Nansen CLI v$(nansen --version 2>/dev/null || echo 'unknown') | #NansenCLI_" >> "$REPORT"

rm -f "$ALL_TRADES"

echo ""
echo "✅ Whale Mirror report: $REPORT"
echo "📊 Signals JSON: $SIGNALS_FILE"
cat "$REPORT"
