#!/usr/bin/env bash
# ============================================================
# Whale Mirror Enhanced — Real-Time SM Consensus Monitor
# Built with Nansen CLI for the #NansenCLI contest
# Now with: $20K+ Filters, Real-time Monitoring, Consensus Scoring
# ============================================================
# Advanced SM consensus detection with institutional-grade filtering
# Designed for continuous monitoring with intelligent alerting
#
# Usage: ./whale-mirror-enhanced.sh [--monitor] [--min-usd 20000] [--webhook URL]
# ============================================================

set -euo pipefail

CHAINS="solana,ethereum,base"
WEBHOOK=""
LIMIT=50
OUTPUT_DIR="./reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SIGNALS_FILE="$OUTPUT_DIR/enhanced-signals-${TIMESTAMP}.json"
REPORT="$OUTPUT_DIR/whale-mirror-enhanced-${TIMESTAMP}.md"

# Enhanced filtering
MIN_TRADE_USD=20000      # Institutional threshold (like AnthroAlert)
MIN_CONSENSUS_WALLETS=2  # Minimum wallets for consensus
MIN_TOTAL_VOLUME=100000  # Minimum total volume for alert
MONITOR_MODE=false       # Continuous monitoring
CHECK_INTERVAL=1800      # 30 minutes (in seconds)

while [[ $# -gt 0 ]]; do
  case $1 in
    --chains) CHAINS="$2"; shift 2;;
    --webhook) WEBHOOK="$2"; shift 2;;
    --limit) LIMIT="$2"; shift 2;;
    --min-usd) MIN_TRADE_USD="$2"; shift 2;;
    --min-consensus) MIN_CONSENSUS_WALLETS="$2"; shift 2;;
    --monitor) MONITOR_MODE=true; shift;;
    --interval) CHECK_INTERVAL="$2"; shift 2;;
    *) echo "Unknown: $1"; exit 1;;
  esac
done

mkdir -p "$OUTPUT_DIR"
IFS=',' read -ra CHAIN_LIST <<< "$CHAINS"

# Function to run analysis
run_analysis() {
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local report="$OUTPUT_DIR/whale-mirror-enhanced-${timestamp}.md"
  local signals_file="$OUTPUT_DIR/enhanced-signals-${timestamp}.json"
  
  echo "🐋 Starting Enhanced Whale Mirror Analysis at $(date)"
  
  echo "# 🐋 Whale Mirror Enhanced — Real-Time Consensus" > "$report"
  echo "_$(date -u '+%Y-%m-%d %H:%M UTC') | Institutional-Grade Filtering_" >> "$report"
  echo "" >> "$report"
  echo "**Enhanced Filters:**" >> "$report"
  echo "- Minimum Trade: \$$(printf "%'d" $MIN_TRADE_USD)" >> "$report"  
  echo "- Consensus Threshold: $MIN_CONSENSUS_WALLETS+ wallets" >> "$report"
  echo "- Alert Volume: \$$(printf "%'d" $MIN_TOTAL_VOLUME)+" >> "$report"
  echo "" >> "$report"

  # Collect all significant SM trades
  local all_trades=$(mktemp)
  local high_value_trades=$(mktemp)

  for chain in "${CHAIN_LIST[@]}"; do
    echo "⏳ Scanning $chain for institutional trades..."
    
    trades=$(nansen research smart-money dex-trades \
      --chain "$chain" \
      --limit "$LIMIT" \
      --fields address,token_bought_symbol,token_bought_address,bought_amount_usd,token_sold_symbol,sold_amount_usd,label,timestamp \
      2>&1) || true

    # Filter for high-value trades and append chain info
    echo "$trades" | jq -c --arg chain "$chain" --argjson min_usd "$MIN_TRADE_USD" '
      .data[]? | select(.bought_amount_usd >= $min_usd) | . + {chain: $chain}
    ' 2>/dev/null >> "$high_value_trades" || true
    
    # Also collect all trades for broader analysis
    echo "$trades" | jq -c --arg chain "$chain" '.data[]? | . + {chain: $chain}' 2>/dev/null >> "$all_trades" || true
  done

  # --- Enhanced Consensus Detection with Scoring ---
  echo "## 🎯 Institutional Consensus Signals" >> "$report"
  echo "_Multi-wallet convergence with $MIN_TRADE_USD+ trade filtering_" >> "$report"
  echo "" >> "$report"

  # Advanced consensus analysis with scoring
  consensus=$(cat "$high_value_trades" | jq -s --argjson min_wallets "$MIN_CONSENSUS_WALLETS" '
    group_by(.token_bought_symbol)
    | map({
        token: .[0].token_bought_symbol,
        token_address: .[0].token_bought_address,
        chains: [.[].chain] | unique,
        unique_wallets: [.[].address] | unique | length,
        total_volume_usd: [.[].bought_amount_usd // 0 | tonumber] | add | round,
        avg_trade_size: ([.[].bought_amount_usd // 0 | tonumber] | add / length) | round,
        trade_count: length,
        labels: [.[].label // empty] | unique,
        latest_timestamp: [.[].timestamp // empty] | max,
        consensus_score: (([.[].address] | unique | length) * ([.[].bought_amount_usd // 0 | tonumber] | add / 100000))
      })
    | map(select(.unique_wallets >= $min_wallets))
    | sort_by(-.consensus_score)
  ' 2>/dev/null || echo "[]")

  # Display high-conviction signals
  echo "$consensus" | jq -r '.[]? | 
    "### 🔥 \(.token) \(if .consensus_score > 10 then "⚡" else "" end)\n" +
    "- **Consensus Score**: \(.consensus_score | round) (higher = stronger signal)\n" + 
    "- **\(.unique_wallets) institutional wallets** buying across \(.chains | join(\", \"))\n" +
    "- **Total Volume**: $\(.total_volume_usd | tostring)\n" +
    "- **Avg Trade Size**: $\(.avg_trade_size | tostring)\n" +
    "- **Trade Count**: \(.trade_count)\n" +
    "- **Key Labels**: \(.labels[:3] | join(\", \"))\n"
  ' 2>/dev/null >> "$report" || true

  if [ "$(echo "$consensus" | jq 'length' 2>/dev/null || echo 0)" = "0" ]; then
    echo "_No institutional consensus signals detected above thresholds._" >> "$report"
  fi

  # --- Whale Activity Heatmap ---
  echo "" >> "$report"
  echo "## 📊 Whale Activity Heatmap (All Chains)" >> "$report"
  echo "" >> "$report"

  # Cross-chain whale activity summary
  cat "$all_trades" | jq -s '
    group_by(.chain) | map({
      chain: .[0].chain,
      total_trades: length,
      institutional_trades: [.[] | select(.bought_amount_usd >= 20000)] | length,
      total_volume: [.[].bought_amount_usd // 0 | tonumber] | add | round,
      avg_trade_size: ([.[].bought_amount_usd // 0 | tonumber] | add / length) | round,
      unique_wallets: [.[].address] | unique | length
    })
  ' 2>/dev/null | jq -r '.[] | 
    "**\(.chain | ascii_upcase)**:\n" +
    "- Total Trades: \(.total_trades) (\(.institutional_trades) institutional)\n" +
    "- Volume: $\(.total_volume | tostring)\n" +
    "- Avg Size: $\(.avg_trade_size | tostring)\n" +
    "- Active Wallets: \(.unique_wallets)\n"
  ' 2>/dev/null >> "$report" || true

  # --- Alert Generation ---
  # Generate alerts for top signals
  local top_signals=$(echo "$consensus" | jq '[.[] | select(.consensus_score > 5)][:3]' 2>/dev/null)
  
  if [ -n "$WEBHOOK" ] && [ "$(echo "$top_signals" | jq 'length' 2>/dev/null || echo 0)" != "0" ]; then
    local alert_msg=$(echo "$top_signals" | jq -r '.[0] | 
      "🐋 **WHALE CONSENSUS**: \(.token) - \(.unique_wallets) institutional wallets buying ($\(.total_volume) total) | Score: \(.consensus_score | round)"
    ' 2>/dev/null)
    
    curl -s -H "Content-Type: application/json" \
      -d "{\"content\": \"$alert_msg\"}" \
      "$WEBHOOK" > /dev/null 2>&1 || true
      
    echo "📬 Alert sent: $alert_msg"
  fi

  # --- Save signals for downstream analysis ---
  echo "$consensus" > "$signals_file"

  # --- Enhanced Summary ---
  local total_trades=$(wc -l < "$all_trades" | tr -d ' ')
  local institutional_trades=$(wc -l < "$high_value_trades" | tr -d ' ')
  local consensus_count=$(echo "$consensus" | jq 'length' 2>/dev/null || echo 0)
  
  echo "" >> "$report"
  echo "---" >> "$report"
  echo "## 📈 Analysis Summary" >> "$report"
  echo "" >> "$report"
  echo "- **Total Trades Analyzed**: $total_trades" >> "$report"
  echo "- **Institutional Trades** (\$${MIN_TRADE_USD}+): $institutional_trades" >> "$report"
  echo "- **Consensus Signals**: $consensus_count patterns detected" >> "$report"
  echo "- **Chains Monitored**: ${#CHAIN_LIST[@]} ($(IFS=','; echo "${CHAIN_LIST[*]}"))" >> "$report"
  echo "- **Analysis Quality**: $([ $institutional_trades -gt 20 ] && echo "🟢 High" || echo "🟡 Moderate") data volume" >> "$report"
  echo "" >> "$report"
  echo "**What makes this different:**" >> "$report"  
  echo "- ✅ **Institutional Focus**: $MIN_TRADE_USD+ trade filtering (vs retail noise)" >> "$report"
  echo "- ✅ **Smart Scoring**: Consensus strength algorithm (volume × wallets)" >> "$report"
  echo "- ✅ **Real-time Ready**: Designed for continuous monitoring" >> "$report"
  echo "- ✅ **Cross-chain Intelligence**: Multi-chain whale pattern detection" >> "$report"
  echo "" >> "$report"
  echo "_Built with Nansen CLI v$(nansen --version 2>/dev/null || echo 'unknown') | Enhanced for #NansenCLI Contest | Agent: Kuro 🐾_" >> "$report"

  # Cleanup
  rm -f "$all_trades" "$high_value_trades"
  
  echo ""
  echo "✅ Enhanced Whale Mirror report: $report" 
  echo "📊 Signals JSON: $signals_file"
  echo "🎯 Consensus signals: $consensus_count | Institutional trades: $institutional_trades"
  
  # Show report if not in monitor mode
  if [ "$MONITOR_MODE" = false ]; then
    cat "$report"
  fi
}

# Main execution
if [ "$MONITOR_MODE" = true ]; then
  echo "🔄 Starting continuous monitoring mode (interval: ${CHECK_INTERVAL}s)"
  echo "💡 Use Ctrl+C to stop monitoring"
  echo ""
  
  while true; do
    run_analysis
    echo ""
    echo "😴 Sleeping for $CHECK_INTERVAL seconds..."
    echo "   Next scan at: $(date -d "+$CHECK_INTERVAL seconds" 2>/dev/null || date -v+${CHECK_INTERVAL}S 2>/dev/null || echo "$(($CHECK_INTERVAL/60)) minutes")"
    sleep "$CHECK_INTERVAL"
  done
else
  run_analysis
fi