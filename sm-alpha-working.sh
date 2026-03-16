#!/usr/bin/env bash
# ============================================================
# SM Alpha Scanner (Working) — Multi-Chain SM Flow Analysis
# Built with Nansen CLI for the #NansenCLI contest
# ============================================================

set -euo pipefail

CHAINS="solana,ethereum,base"
LIMIT=10
OUTPUT_DIR="./reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT="$OUTPUT_DIR/sm-alpha-working-${TIMESTAMP}.md"

while [[ $# -gt 0 ]]; do
  case $1 in
    --chains) CHAINS="$2"; shift 2;;
    --limit) LIMIT="$2"; shift 2;;
    *) echo "Unknown: $1"; exit 1;;
  esac
done

mkdir -p "$OUTPUT_DIR"
IFS=',' read -ra CHAIN_LIST <<< "$CHAINS"

echo "# 🔍 Smart Money Alpha Scanner" > "$REPORT"
echo "_Generated: $(date -u '+%Y-%m-%d %H:%M UTC') | Built with Nansen CLI_" >> "$REPORT"
echo "" >> "$REPORT"

# --- SM Net Flows ---
echo "## 💰 Smart Money Net Flows (24h)" >> "$REPORT"
echo "_Positive = Smart Money buying, Negative = Smart Money selling_" >> "$REPORT"
echo "" >> "$REPORT"

for chain in "${CHAIN_LIST[@]}"; do
  echo "### 📈 $chain" >> "$REPORT"
  echo "" >> "$REPORT"
  
  echo "⏳ Scanning $chain..."
  
  result=$(nansen research smart-money netflow \
    --chain "$chain" \
    --limit "$LIMIT" \
    --fields token_symbol,token_address,net_flow_24h_usd,trader_count,market_cap_usd \
    --pretty 2>&1) || true

  if echo "$result" | jq '.success' >/dev/null 2>&1 && [ "$(echo "$result" | jq '.success')" = "true" ]; then
    echo "| Token | 24h Net Flow | Trader Count | Market Cap |" >> "$REPORT"
    echo "|-------|--------------|--------------|-----------|" >> "$REPORT"
    echo "$result" | jq -r '.data.data[]? | "| \(.token_symbol) | $\(.net_flow_24h_usd // 0 | round) | \(.trader_count) | $\(.market_cap_usd // 0 | round) |"' >> "$REPORT"
  else
    echo "```" >> "$REPORT"
    echo "Error: $result" >> "$REPORT"
    echo "```" >> "$REPORT"
  fi
  
  echo "" >> "$REPORT"
done

# --- Top Holdings ---
echo "## 🏆 Smart Money Holdings by Value" >> "$REPORT"
echo "" >> "$REPORT"

for chain in "${CHAIN_LIST[@]}"; do
  echo "### 💎 $chain Holdings" >> "$REPORT"
  echo "" >> "$REPORT"
  
  echo "⏳ Holdings $chain..."
  
  holdings=$(nansen research smart-money holdings \
    --chain "$chain" \
    --limit "$LIMIT" \
    --fields token_symbol,total_value_usd,holder_count \
    --sort total_value_usd:desc \
    --pretty 2>&1) || true

  if echo "$holdings" | jq '.success' >/dev/null 2>&1 && [ "$(echo "$holdings" | jq '.success')" = "true" ]; then
    echo "| Token | Total Value | Holder Count |" >> "$REPORT"
    echo "|-------|-------------|--------------|" >> "$REPORT"
    echo "$holdings" | jq -r '.data.data[]? | "| \(.token_symbol) | $\(.total_value_usd // 0 | round) | \(.holder_count // 0) |"' >> "$REPORT"
  else
    echo "```" >> "$REPORT"
    echo "Error: $holdings" >> "$REPORT"
    echo "```" >> "$REPORT"
  fi
  
  echo "" >> "$REPORT"
done

# --- Recent Trades ---
echo "## 🐋 Latest Smart Money DEX Trades" >> "$REPORT"
echo "_Real-time DEX trading activity by Smart Money wallets_" >> "$REPORT"
echo "" >> "$REPORT"

for chain in "${CHAIN_LIST[@]}"; do
  echo "### ⚡ $chain Recent Trades" >> "$REPORT"
  echo "" >> "$REPORT"
  
  echo "⏳ Trades $chain..."
  
  trades=$(nansen research smart-money dex-trades \
    --chain "$chain" \
    --limit 8 \
    --fields address,token_bought_symbol,token_sold_symbol,bought_amount_usd,label \
    --pretty 2>&1) || true

  if echo "$trades" | jq '.success' >/dev/null 2>&1 && [ "$(echo "$trades" | jq '.success')" = "true" ]; then
    echo "| Trader | Trade | Amount USD |" >> "$REPORT"
    echo "|--------|-------|------------|" >> "$REPORT"
    echo "$trades" | jq -r '.data.data[]? | "| \(.label // (.address[0:8] + "...")) | \(.token_sold_symbol // "?") → \(.token_bought_symbol // "?") | $\(.bought_amount_usd // 0 | round) |"' >> "$REPORT"
  else
    echo "```" >> "$REPORT"
    echo "Error: $trades" >> "$REPORT"
    echo "```" >> "$REPORT"
  fi
  
  echo "" >> "$REPORT"
done

# Summary
echo "---" >> "$REPORT"
echo "" >> "$REPORT"
echo "### 🎯 Key Insights" >> "$REPORT"
echo "" >> "$REPORT"
echo "This report analyzes **Smart Money flows, holdings, and trading activity** across ${#CHAIN_LIST[@]} major chains using the Nansen CLI." >> "$REPORT"
echo "" >> "$REPORT"
echo "**What is Smart Money?** Wallets identified by Nansen as belonging to VCs, funds, whales, and sophisticated traders." >> "$REPORT"
echo "" >> "$REPORT"
echo "**How to use this data:**" >> "$REPORT"
echo "- 💚 **Positive net flows** = Smart Money is accumulating" >> "$REPORT"
echo "- 🔴 **Negative net flows** = Smart Money is distributing" >> "$REPORT"
echo "- 📊 **High holder counts** = Distributed SM interest" >> "$REPORT"
echo "- ⚡ **Recent trades** = Current SM activity and sentiment" >> "$REPORT"
echo "" >> "$REPORT"
echo "_**Disclaimer:** Past performance does not indicate future results. This is research data, not investment advice._" >> "$REPORT"
echo "" >> "$REPORT"
echo "---" >> "$REPORT"
echo "**Built with:** \`nansen-cli v$(nansen --version 2>/dev/null || echo 'unknown')\` | **Contest:** #NansenCLI | **Agent:** AI-powered analysis" >> "$REPORT"

echo ""
echo "✅ SM Alpha Scanner Report: $REPORT"
echo "📊 Scanned ${#CHAIN_LIST[@]} chains for Smart Money alpha signals"

# Display result
cat "$REPORT"