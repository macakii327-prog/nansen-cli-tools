#!/usr/bin/env bash
# ============================================================
# SM Alpha Scanner (Simplified) — Multi-Chain SM Flow Analysis
# Built with Nansen CLI for the #NansenCLI contest
# ============================================================

set -euo pipefail

CHAINS="solana,ethereum,base"
LIMIT=10
OUTPUT_DIR="./reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT="$OUTPUT_DIR/sm-alpha-simple-${TIMESTAMP}.md"

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

# --- SM Net Flows ---
echo "## Smart Money Net Flows by Chain" >> "$REPORT"
echo "" >> "$REPORT"

for chain in "${CHAIN_LIST[@]}"; do
  echo "### $chain" >> "$REPORT"
  echo '```' >> "$REPORT"
  echo "⏳ Scanning $chain..."
  
  result=$(nansen research smart-money netflow \
    --chain "$chain" \
    --limit "$LIMIT" \
    --fields token_symbol,net_flow_usd,inflow_usd,outflow_usd \
    --pretty 2>&1) || true

  if echo "$result" | jq '.success' >/dev/null 2>&1 && [ "$(echo "$result" | jq '.success')" = "true" ]; then
    echo "$result" | jq -r '.data[]? | "\(.token_symbol)\tNet: $\(.net_flow_usd // 0 | round)\tIn: $\(.inflow_usd // 0 | round)\tOut: $\(.outflow_usd // 0 | round)"' >> "$REPORT"
  else
    echo "API Error: $result" >> "$REPORT"
  fi
  
  echo '```' >> "$REPORT"
  echo "" >> "$REPORT"
done

# --- SM Holdings ---
echo "## Smart Money Holdings Concentration" >> "$REPORT"
echo "" >> "$REPORT"

for chain in "${CHAIN_LIST[@]}"; do
  echo "### $chain Holdings" >> "$REPORT"
  echo '```' >> "$REPORT"
  echo "⏳ Holdings $chain..."
  
  holdings=$(nansen research smart-money holdings \
    --chain "$chain" \
    --limit "$LIMIT" \
    --fields token_symbol,total_value_usd,holder_count \
    --sort total_value_usd:desc \
    --pretty 2>&1) || true

  if echo "$holdings" | jq '.success' >/dev/null 2>&1 && [ "$(echo "$holdings" | jq '.success')" = "true" ]; then
    echo "$holdings" | jq -r '.data[]? | "\(.token_symbol)\t$\(.total_value_usd // 0 | round)\t(\(.holder_count // 0) holders)"' >> "$REPORT"
  else
    echo "API Error: $holdings" >> "$REPORT"
  fi
  
  echo '```' >> "$REPORT"
  echo "" >> "$REPORT"
done

# --- Recent SM DEX Trades ---
echo "## Latest Smart Money DEX Trades" >> "$REPORT"
echo "" >> "$REPORT"

for chain in "${CHAIN_LIST[@]}"; do
  echo "### $chain Recent Trades" >> "$REPORT"
  echo '```' >> "$REPORT"
  echo "⏳ Trades $chain..."
  
  trades=$(nansen research smart-money dex-trades \
    --chain "$chain" \
    --limit 5 \
    --fields address,token_bought_symbol,token_sold_symbol,bought_amount_usd \
    --pretty 2>&1) || true

  if echo "$trades" | jq '.success' >/dev/null 2>&1 && [ "$(echo "$trades" | jq '.success')" = "true" ]; then
    echo "$trades" | jq -r '.data[]? | "[\(.address[0:8])...] \(.token_sold_symbol // "?") → \(.token_bought_symbol // "?") ($\(.bought_amount_usd // 0 | round))"' >> "$REPORT"
  else
    echo "API Error: $trades" >> "$REPORT"
  fi
  
  echo '```' >> "$REPORT"
  echo "" >> "$REPORT"
done

# --- Summary ---
echo "---" >> "$REPORT"
echo "**Multi-chain SM Analysis** — ${#CHAIN_LIST[@]} chains scanned using \`nansen-cli v$(nansen --version 2>/dev/null || echo 'unknown')\`" >> "$REPORT"
echo "" >> "$REPORT"
echo "_Built with Nansen CLI | #NansenCLI contest submission_" >> "$REPORT"

echo "✅ Report saved: $REPORT"
cat "$REPORT"