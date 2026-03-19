#!/usr/bin/env bash
# ============================================================
# SM Alpha Scanner Enhanced — Divergence Detection & Alerts
# Built with Nansen CLI for the #NansenCLI contest
# Now with: Price-Flow Divergence, Alert Thresholds, Smart Scoring
# ============================================================

set -euo pipefail

CHAINS="solana,ethereum,base"
LIMIT=15
OUTPUT_DIR="./reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT="$OUTPUT_DIR/sm-alpha-enhanced-${TIMESTAMP}.md"
WEBHOOK=""
MIN_FLOW_USD=50000  # Alert threshold
MIN_DIVERGENCE_SCORE=0.7  # Divergence strength (0-1)

while [[ $# -gt 0 ]]; do
  case $1 in
    --chains) CHAINS="$2"; shift 2;;
    --limit) LIMIT="$2"; shift 2;;
    --webhook) WEBHOOK="$2"; shift 2;;
    --min-flow) MIN_FLOW_USD="$2"; shift 2;;
    --min-divergence) MIN_DIVERGENCE_SCORE="$2"; shift 2;;
    *) echo "Unknown: $1"; exit 1;;
  esac
done

mkdir -p "$OUTPUT_DIR"
IFS=',' read -ra CHAIN_LIST <<< "$CHAINS"

echo "# 🔍 Smart Money Alpha Scanner Enhanced" > "$REPORT"
echo "_Generated: $(date -u '+%Y-%m-%d %H:%M UTC') | Built with Nansen CLI_" >> "$REPORT"
echo "_Now with Price-Flow Divergence Detection & Smart Alerts_" >> "$REPORT"
echo "" >> "$REPORT"

# Temp files for cross-analysis
ALL_FLOWS=$(mktemp)
ALERTS=$(mktemp)

echo "## 🚨 High-Priority Divergence Alerts" >> "$REPORT"
echo "_Tokens where Smart Money is buying during price weakness_" >> "$REPORT"
echo "" >> "$REPORT"

# --- Enhanced SM Net Flows with Divergence Detection ---
for chain in "${CHAIN_LIST[@]}"; do
  echo "⏳ Analyzing $chain for divergence patterns..."
  
  # Get net flows
  flows=$(nansen research smart-money netflow \
    --chain "$chain" \
    --limit "$LIMIT" \
    --fields token_symbol,token_address,net_flow_24h_usd,trader_count,market_cap_usd \
    --pretty 2>&1) || true

  # Get price data for correlation
  if echo "$flows" | jq '.success' >/dev/null 2>&1 && [ "$(echo "$flows" | jq '.success')" = "true" ]; then
    echo "$flows" | jq -c --arg chain "$chain" '.data.data[]? | . + {chain: $chain}' >> "$ALL_FLOWS" 2>/dev/null || true
    
    # Analyze each token for divergence
    echo "$flows" | jq -r '.data.data[]? | select(.net_flow_24h_usd > 0)' 2>/dev/null | while IFS= read -r token_data; do
      token_symbol=$(echo "$token_data" | jq -r '.token_symbol // "?"' 2>/dev/null)
      token_addr=$(echo "$token_data" | jq -r '.token_address // ""' 2>/dev/null)
      net_flow=$(echo "$token_data" | jq -r '.net_flow_24h_usd // 0' 2>/dev/null)
      
      if [ -n "$token_addr" ] && [ "${token_addr}" != "null" ] && (( $(echo "$net_flow > $MIN_FLOW_USD" | bc -l) )); then
        # Get recent OHLCV to check price trend
        ohlcv=$(nansen research token ohlcv --chain "$chain" --token "$token_addr" --timeframe 1h --limit 24 --pretty 2>&1) || true
        
        if echo "$ohlcv" | jq '.success' >/dev/null 2>&1; then
          # Calculate price change (24h)
          price_change=$(echo "$ohlcv" | jq -r '
            if .data and (.data | length > 0) then
              (.data[-1].close - .data[0].open) / .data[0].open * 100
            else 0 end
          ' 2>/dev/null || echo "0")
          
          # Divergence score: positive flow + negative/flat price = strong signal
          if (( $(echo "$price_change <= 5" | bc -l) )) && (( $(echo "$net_flow > 0" | bc -l) )); then
            divergence_score=$(echo "scale=2; (($net_flow / 100000) * (1 - ($price_change / 100))) / 10" | bc -l)
            
            if (( $(echo "$divergence_score > $MIN_DIVERGENCE_SCORE" | bc -l) )); then
              echo "🚨 **$token_symbol** ($chain)" >> "$ALERTS"
              echo "- Net SM Flow: $$(echo "$net_flow" | cut -d. -f1)" >> "$ALERTS"
              echo "- Price Change (24h): $(printf "%.1f" "$price_change")%" >> "$ALERTS"
              echo "- Divergence Score: $(printf "%.2f" "$divergence_score")" >> "$ALERTS"
              echo "" >> "$ALERTS"
              
              # Webhook alert for top signals
              if [ -n "$WEBHOOK" ] && (( $(echo "$divergence_score > 1.5" | bc -l) )); then
                curl -s -H "Content-Type: application/json" \
                  -d "{\"content\": \"🚨 **DIVERGENCE ALERT**: $token_symbol ($chain) - SM buying \$$net_flow while price down $(printf "%.1f" "$price_change")%\"}" \
                  "$WEBHOOK" > /dev/null 2>&1 || true
              fi
            fi
          fi
        fi
      fi
    done 2>/dev/null || true
  fi
done

# Add alerts to report
if [ -s "$ALERTS" ]; then
  cat "$ALERTS" >> "$REPORT"
else
  echo "_No high-priority divergence signals detected._" >> "$REPORT"
fi
echo "" >> "$REPORT"

# --- Standard Net Flows Analysis ---
echo "## 💰 Smart Money Net Flows Analysis" >> "$REPORT"
echo "" >> "$REPORT"

for chain in "${CHAIN_LIST[@]}"; do
  echo "### 📈 $chain Net Flows (24h)" >> "$REPORT"
  echo "" >> "$REPORT"
  
  # Use cached data from ALL_FLOWS
  chain_flows=$(cat "$ALL_FLOWS" | jq -r --arg c "$chain" 'select(.chain == $c)')
  
  if [ -n "$chain_flows" ]; then
    echo "| Token | 24h Net Flow | Traders | Market Cap | Signal |" >> "$REPORT"
    echo "|-------|--------------|---------|------------|---------|" >> "$REPORT"
    
    echo "$chain_flows" | jq -r '
      . as $token |
      "| \(.token_symbol) | $\(.net_flow_24h_usd // 0 | round) | \(.trader_count) | $\(.market_cap_usd // 0 | round) | \(
        if (.net_flow_24h_usd // 0) > 100000 then "🔥 Strong"
        elif (.net_flow_24h_usd // 0) > 10000 then "💡 Watch"  
        else "📊 Normal" end
      ) |"
    ' 2>/dev/null >> "$REPORT" || true
  else
    echo "_No data available for $chain_" >> "$REPORT"
  fi
  
  echo "" >> "$REPORT"
done

# --- Cross-Chain Flow Summary ---
echo "## 🌐 Cross-Chain Flow Summary" >> "$REPORT"
echo "" >> "$REPORT"

total_inflow=$(cat "$ALL_FLOWS" | jq '[.net_flow_24h_usd // 0 | select(. > 0)] | add // 0' 2>/dev/null || echo "0")
total_outflow=$(cat "$ALL_FLOWS" | jq '[.net_flow_24h_usd // 0 | select(. < 0)] | add // 0' 2>/dev/null || echo "0")
net_total=$(echo "$total_inflow + $total_outflow" | bc -l)

echo "- **Total SM Inflow**: \$$(echo "$total_inflow" | cut -d. -f1)" >> "$REPORT"
echo "- **Total SM Outflow**: \$$(echo "$total_outflow" | cut -d. -f1)" >> "$REPORT"  
echo "- **Net Flow**: \$$(echo "$net_total" | cut -d. -f1)" >> "$REPORT"
echo "- **Market Sentiment**: $([ $(echo "$net_total > 0" | bc -l) = 1 ] && echo "🟢 Bullish" || echo "🔴 Bearish")" >> "$REPORT"

echo "" >> "$REPORT"
echo "---" >> "$REPORT"
echo "" >> "$REPORT"

# --- Enhanced Key Insights ---
echo "### 🎯 Enhanced Alpha Insights" >> "$REPORT"
echo "" >> "$REPORT"
echo "This **Enhanced SM Alpha Scanner** now includes:" >> "$REPORT"
echo "" >> "$REPORT"
echo "✅ **Divergence Detection** — Find tokens where SM buys during price weakness" >> "$REPORT"
echo "✅ **Smart Alerts** — Threshold-based notifications for high-conviction signals" >> "$REPORT"  
echo "✅ **Signal Scoring** — Quantified divergence strength (0-10 scale)" >> "$REPORT"
echo "✅ **Cross-Chain Analysis** — Market-wide SM sentiment tracking" >> "$REPORT"
echo "" >> "$REPORT"
echo "**Alert Thresholds:**" >> "$REPORT"
echo "- Minimum Flow: \$$(printf "%'d" $MIN_FLOW_USD)" >> "$REPORT"
echo "- Divergence Score: $MIN_DIVERGENCE_SCORE+" >> "$REPORT"
echo "" >> "$REPORT"
echo "**How to interpret signals:**" >> "$REPORT"
echo "- 🚨 **Divergence Alert** = Classic alpha opportunity (buy the dip with smart money)" >> "$REPORT"
echo "- 🔥 **Strong Flow** = Major SM accumulation ongoing" >> "$REPORT"
echo "- 💡 **Watch** = Moderate SM interest, monitor for confirmation" >> "$REPORT"
echo "" >> "$REPORT"
echo "_This is research data, not financial advice._" >> "$REPORT"
echo "" >> "$REPORT"
echo "---" >> "$REPORT"
echo "**Built with:** \`nansen-cli v$(nansen --version 2>/dev/null || echo 'unknown')\` | **Enhanced for:** #NansenCLI Contest | **Agent:** Kuro 🐾" >> "$REPORT"

# Cleanup
rm -f "$ALL_FLOWS" "$ALERTS"

echo ""
echo "✅ Enhanced SM Alpha Scanner Report: $REPORT"
echo "📊 Analyzed ${#CHAIN_LIST[@]} chains with divergence detection"
echo "🚨 Alert threshold: \$$(printf "%'d" $MIN_FLOW_USD) minimum flow"

# Display result
cat "$REPORT"