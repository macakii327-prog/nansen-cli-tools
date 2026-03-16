#!/usr/bin/env bash
# ============================================================
# SM Alpha Scanner — Cross-Chain Smart Money Flow Detector
# Built with Nansen CLI for the #NansenCLI contest
# ============================================================
# Scans multiple chains for SM net flows, detects cross-chain
# rotation patterns, and surfaces alpha signals.
# Usage: ./sm-alpha-scanner.sh [--chains eth,sol,base] [--limit 20]
# ============================================================

set -euo pipefail

# --- Config ---
DEFAULT_CHAINS="ethereum,solana,base,arbitrum,bnb"
LIMIT=20
OUTPUT_DIR="./reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT="$OUTPUT_DIR/sm-alpha-${TIMESTAMP}.md"

# --- Parse args ---
CHAINS="$DEFAULT_CHAINS"
while [[ $# -gt 0 ]]; do
  case $1 in
    --chains) CHAINS="$2"; shift 2;;
    --limit) LIMIT="$2"; shift 2;;
    *) echo "Unknown: $1"; exit 1;;
  esac
done

mkdir -p "$OUTPUT_DIR"

IFS=',' read -ra CHAIN_LIST <<< "$CHAINS"

echo "# 🔍 SM Alpha Scanner Report" > "$REPORT"
echo "_Generated: $(date -u '+%Y-%m-%d %H:%M UTC')_" >> "$REPORT"
echo "" >> "$REPORT"

# --- Collect all token flows across chains ---
declare -A TOKEN_INFLOW
declare -A TOKEN_OUTFLOW
declare -A TOKEN_CHAINS

echo "## Cross-Chain Smart Money Net Flows" >> "$REPORT"
echo "" >> "$REPORT"

for chain in "${CHAIN_LIST[@]}"; do
  echo "⏳ Scanning $chain..."
  echo "### $chain" >> "$REPORT"
  echo '```' >> "$REPORT"

  # Get SM net flows
  result=$(nansen research smart-money netflow \
    --chain "$chain" \
    --limit "$LIMIT" \
    --fields token_symbol,token_address,net_flow_usd,inflow_usd,outflow_usd \
    2>&1) || true

  echo "$result" | jq -r '.data[]? | "\(.token_symbol)\t$\(.net_flow_usd // 0 | tonumber | round)\t in:$\(.inflow_usd // 0 | tonumber | round)\t out:$\(.outflow_usd // 0 | tonumber | round)"' 2>/dev/null >> "$REPORT" || echo "$result" >> "$REPORT"

  echo '```' >> "$REPORT"
  echo "" >> "$REPORT"

  # Track cross-chain appearances
  while IFS=$'\t' read -r sym addr net_flow _rest; do
    [ -z "$sym" ] && continue
    TOKEN_INFLOW["$sym"]=$(( ${TOKEN_INFLOW["$sym"]:-0} + $(echo "$net_flow" | tr -d '$' | cut -d. -f1) ))
    TOKEN_CHAINS["$sym"]="${TOKEN_CHAINS["$sym"]:-} $chain"
  done < <(echo "$result" | jq -r '.data[]? | "\(.token_symbol)\t\(.token_address)\t\(.net_flow_usd // 0)\t"' 2>/dev/null || true)
done

# --- Cross-chain rotation detection ---
echo "## 🔄 Cross-Chain Rotation Signals" >> "$REPORT"
echo "" >> "$REPORT"
echo "Tokens appearing on multiple chains with divergent flows:" >> "$REPORT"
echo "" >> "$REPORT"

rotation_found=false
for token in "${!TOKEN_CHAINS[@]}"; do
  chains="${TOKEN_CHAINS[$token]}"
  chain_count=$(echo "$chains" | tr ' ' '\n' | grep -c . || true)
  if [ "$chain_count" -ge 2 ]; then
    echo "- **$token** — seen on${chains} (aggregate net flow: \$${TOKEN_INFLOW[$token]:-0})" >> "$REPORT"
    rotation_found=true
  fi
done

if [ "$rotation_found" = false ]; then
  echo "_No cross-chain rotation detected in this scan._" >> "$REPORT"
fi

# --- Top SM DEX trades (most recent) ---
echo "" >> "$REPORT"
echo "## 🐋 Latest SM DEX Trades (Top Chains)" >> "$REPORT"
echo "" >> "$REPORT"

for chain in ethereum solana base; do
  echo "### $chain — Recent SM Trades" >> "$REPORT"
  echo '```' >> "$REPORT"

  trades=$(nansen research smart-money dex-trades \
    --chain "$chain" \
    --limit 10 \
    --fields address,token_bought_symbol,token_sold_symbol,bought_amount_usd,sold_amount_usd \
    2>&1) || true

  echo "$trades" | jq -r '.data[]? | "[\(.address[0:8])...] \(.token_sold_symbol) → \(.token_bought_symbol)  $\(.bought_amount_usd // 0 | tonumber | round)"' 2>/dev/null >> "$REPORT" || echo "$trades" >> "$REPORT"

  echo '```' >> "$REPORT"
  echo "" >> "$REPORT"
done

# --- SM Holdings concentration ---
echo "## 💰 SM Holdings Concentration" >> "$REPORT"
echo "" >> "$REPORT"

for chain in ethereum solana base; do
  echo "### $chain" >> "$REPORT"
  echo '```' >> "$REPORT"

  holdings=$(nansen research smart-money holdings \
    --chain "$chain" \
    --limit 10 \
    --fields token_symbol,holder_count,total_value_usd \
    --sort total_value_usd:desc \
    2>&1) || true

  echo "$holdings" | jq -r '.data[]? | "\(.token_symbol)\t\(.holder_count) holders\t$\(.total_value_usd // 0 | tonumber | round)"' 2>/dev/null >> "$REPORT" || echo "$holdings" >> "$REPORT"

  echo '```' >> "$REPORT"
  echo "" >> "$REPORT"
done

# --- Summary ---
TOTAL_CHAINS=${#CHAIN_LIST[@]}
echo "---" >> "$REPORT"
echo "**Scanned:** $TOTAL_CHAINS chains | **Limit:** $LIMIT tokens/chain" >> "$REPORT"
echo "**CLI:** nansen-cli v$(nansen --version 2>/dev/null || echo 'unknown')" >> "$REPORT"

echo ""
echo "✅ Report saved: $REPORT"
echo "📊 Scanned $TOTAL_CHAINS chains for SM alpha signals"
cat "$REPORT"
