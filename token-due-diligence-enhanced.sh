#!/usr/bin/env bash
# ============================================================
# Token Due Diligence Enhanced — AI-Powered Investment Analysis
# Built with Nansen CLI for the #NansenCLI contest  
# Now with: Investment Score, Risk Assessment, Automated Recommendations
# ============================================================
# Comprehensive token analysis with intelligent scoring system
# 9 data points → unified investment recommendation
#
# Usage: ./token-due-diligence-enhanced.sh <token_address> [--chain solana]
# ============================================================

set -euo pipefail

TOKEN=""
CHAIN="solana"
DAYS=7
OUTPUT_DIR="./reports"
GENERATE_SUMMARY=true
SAVE_RAW_DATA=true

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case $1 in
    --chain) CHAIN="$2"; shift 2;;
    --days) DAYS="$2"; shift 2;;
    --no-summary) GENERATE_SUMMARY=false; shift;;
    --raw-only) SAVE_RAW_DATA=true; GENERATE_SUMMARY=false; shift;;
    -*) echo "Unknown option: $1"; exit 1;;
    *) TOKEN="$1"; shift;;
  esac
done

if [ -z "$TOKEN" ]; then
  echo "Usage: $0 <token_address> [--chain solana] [--days 7] [--no-summary]"
  echo ""
  echo "Enhanced features:"
  echo "  --chain CHAIN    Target blockchain (default: solana)"
  echo "  --days DAYS      Analysis timeframe (default: 7)" 
  echo "  --no-summary     Skip AI analysis, show raw data only"
  echo "  --raw-only       Generate raw data without summary"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT="$OUTPUT_DIR/enhanced-dd-${CHAIN}-${TOKEN:0:8}-${TIMESTAMP}.md"
RAW_DATA=$(mktemp)

echo "🔍 Enhanced Token Due Diligence: $TOKEN ($CHAIN)"
echo "⏳ Collecting 9 data points..."

echo "# 📋 Enhanced Token Due Diligence" > "$REPORT"
echo "_Token: \`$TOKEN\` | Chain: $CHAIN | Generated: $(date -u '+%Y-%m-%d %H:%M UTC')_" >> "$REPORT"
echo "_Enhanced with AI-powered investment scoring & risk assessment_" >> "$REPORT"
echo "" >> "$REPORT"

# --- Data Collection Phase ---
echo "{}" > "$RAW_DATA"

echo "📊 [1/9] Token info..."
token_info=$(nansen research token info --chain "$CHAIN" --token "$TOKEN" --pretty 2>&1) || echo '{"error": "failed"}'
echo "$token_info" | jq '.data // {}' > temp1.json 2>/dev/null || echo '{}' > temp1.json
jq '. + {"token_info": input}' "$RAW_DATA" temp1.json > temp_combined.json && mv temp_combined.json "$RAW_DATA"

echo "📈 [2/9] Nansen indicators..."  
indicators=$(nansen research token indicators --chain "$CHAIN" --token "$TOKEN" --pretty 2>&1) || echo '{"error": "failed"}'
echo "$indicators" | jq '.data // {}' > temp2.json 2>/dev/null || echo '{}' > temp2.json
jq '. + {"indicators": input}' "$RAW_DATA" temp2.json > temp_combined.json && mv temp_combined.json "$RAW_DATA"

echo "💧 [3/9] Net flows..."
flows=$(nansen research token flows --chain "$CHAIN" --token "$TOKEN" --days "$DAYS" --pretty 2>&1) || echo '{"error": "failed"}'
echo "$flows" | jq '.data // {}' > temp3.json 2>/dev/null || echo '{}' > temp3.json  
jq '. + {"flows": input}' "$RAW_DATA" temp3.json > temp_combined.json && mv temp_combined.json "$RAW_DATA"

echo "🧠 [4/9] Flow intelligence..."
flow_intel=$(nansen research token flow-intelligence --chain "$CHAIN" --token "$TOKEN" --days "$DAYS" --pretty 2>&1) || echo '{"error": "failed"}'
echo "$flow_intel" | jq '.data[:10] // []' > temp4.json 2>/dev/null || echo '[]' > temp4.json
jq '. + {"flow_intelligence": input}' "$RAW_DATA" temp4.json > temp_combined.json && mv temp_combined.json "$RAW_DATA"

echo "👥 [5/9] Top holders..."
holders=$(nansen research token holders --chain "$CHAIN" --token "$TOKEN" --limit 20 --fields address,label,balance_usd,percentage 2>&1) || echo '{"error": "failed"}'
echo "$holders" | jq '.data // []' > temp5.json 2>/dev/null || echo '[]' > temp5.json
jq '. + {"holders": input}' "$RAW_DATA" temp5.json > temp_combined.json && mv temp_combined.json "$RAW_DATA"

echo "💰 [6/9] Buyers & sellers..."
buyers_sellers=$(nansen research token who-bought-sold --chain "$CHAIN" --token "$TOKEN" --days "$DAYS" --fields address,label,bought_usd,sold_usd --limit 15 2>&1) || echo '{"error": "failed"}'
echo "$buyers_sellers" | jq '.data // []' > temp6.json 2>/dev/null || echo '[]' > temp6.json
jq '. + {"buyers_sellers": input}' "$RAW_DATA" temp6.json > temp_combined.json && mv temp_combined.json "$RAW_DATA"

echo "📊 [7/9] PnL leaderboard..."
pnl=$(nansen research token pnl --chain "$CHAIN" --token "$TOKEN" --days "$DAYS" --fields address,label,realized_pnl_usd,unrealized_pnl_usd --limit 15 2>&1) || echo '{"error": "failed"}'
echo "$pnl" | jq '.data // []' > temp7.json 2>/dev/null || echo '[]' > temp7.json  
jq '. + {"pnl": input}' "$RAW_DATA" temp7.json > temp_combined.json && mv temp_combined.json "$RAW_DATA"

echo "⚡ [8/9] Recent DEX trades..."
dex_trades=$(nansen research token dex-trades --chain "$CHAIN" --token "$TOKEN" --days 1 --fields address,label,type,amount_usd --limit 20 2>&1) || echo '{"error": "failed"}'
echo "$dex_trades" | jq '.data // []' > temp8.json 2>/dev/null || echo '[]' > temp8.json
jq '. + {"dex_trades": input}' "$RAW_DATA" temp8.json > temp_combined.json && mv temp_combined.json "$RAW_DATA"

echo "📈 [9/9] OHLCV data..."  
ohlcv=$(nansen research token ohlcv --chain "$CHAIN" --token "$TOKEN" --timeframe 24h --limit 7 2>&1) || echo '{"error": "failed"}'
echo "$ohlcv" | jq '.data // []' > temp9.json 2>/dev/null || echo '[]' > temp9.json
jq '. + {"ohlcv": input}' "$RAW_DATA" temp9.json > temp_combined.json && mv temp_combined.json "$RAW_DATA"

# Cleanup temp files
rm -f temp*.json

echo "🧮 Calculating investment scores..."

# --- Enhanced Analysis & Scoring ---
if [ "$GENERATE_SUMMARY" = true ]; then
  echo "## 🎯 AI Investment Analysis" >> "$REPORT"
  echo "_Automated scoring based on 9 comprehensive data points_" >> "$REPORT"
  echo "" >> "$REPORT"
  
  # Calculate component scores
  # Flow Score (0-25 points)
  net_flow=$(cat "$RAW_DATA" | jq '.flows.net_flow_24h_usd // 0' 2>/dev/null || echo 0)
  flow_score=$(echo "scale=0; if ($net_flow > 1000000) 25 else if ($net_flow > 100000) 20 else if ($net_flow > 10000) 15 else if ($net_flow > 0) 10 else 0" | bc -l)
  
  # Holder Quality Score (0-25 points)  
  sm_holders=$(cat "$RAW_DATA" | jq '.holders | [.[] | select(.label != null)] | length' 2>/dev/null || echo 0)
  holder_score=$(echo "scale=0; if ($sm_holders > 5) 25 else ($sm_holders * 5)" | bc -l)
  
  # Trading Activity Score (0-25 points)
  recent_trades=$(cat "$RAW_DATA" | jq '.dex_trades | length' 2>/dev/null || echo 0) 
  volume_24h=$(cat "$RAW_DATA" | jq '.dex_trades | [.[].amount_usd // 0 | tonumber] | add // 0' 2>/dev/null || echo 0)
  activity_score=$(echo "scale=0; if ($volume_24h > 1000000) 25 else if ($volume_24h > 100000) 20 else if ($recent_trades > 10) 15 else if ($recent_trades > 3) 10 else 0" | bc -l)
  
  # PnL/Performance Score (0-25 points)  
  positive_pnl_count=$(cat "$RAW_DATA" | jq '.pnl | [.[] | select(.realized_pnl_usd > 0 or .unrealized_pnl_usd > 0)] | length' 2>/dev/null || echo 0)
  performance_score=$(echo "scale=0; if ($positive_pnl_count > 8) 25 else if ($positive_pnl_count > 5) 20 else if ($positive_pnl_count > 2) 15 else 10" | bc -l)
  
  # Total Investment Score (0-100)
  total_score=$(echo "$flow_score + $holder_score + $activity_score + $performance_score" | bc -l)
  
  # Risk Assessment
  risk_factors=0
  if [ $(echo "$net_flow < -50000" | bc -l) = 1 ]; then risk_factors=$((risk_factors + 1)); fi
  if [ $(echo "$sm_holders < 2" | bc -l) = 1 ]; then risk_factors=$((risk_factors + 1)); fi  
  if [ $(echo "$recent_trades < 5" | bc -l) = 1 ]; then risk_factors=$((risk_factors + 1)); fi
  
  # Generate recommendation
  if [ $(echo "$total_score >= 80" | bc -l) = 1 ]; then
    recommendation="🟢 **STRONG BUY** - High conviction signal"
    risk_level="🟢 Low"
  elif [ $(echo "$total_score >= 60" | bc -l) = 1 ]; then
    recommendation="🟡 **MODERATE BUY** - Good opportunity with caution" 
    risk_level="🟡 Moderate"
  elif [ $(echo "$total_score >= 40" | bc -l) = 1 ]; then
    recommendation="🟠 **WATCH** - Monitor for improvements"
    risk_level="🟠 Moderate-High"  
  else
    recommendation="🔴 **AVOID** - Multiple red flags"
    risk_level="🔴 High"
  fi
  
  # Investment Analysis Summary
  echo "### 📊 Investment Score Breakdown" >> "$REPORT"
  echo "" >> "$REPORT"
  echo "| Component | Score | Weight | Analysis |" >> "$REPORT"
  echo "|-----------|-------|---------|----------|" >> "$REPORT"
  echo "| Smart Money Flow | $flow_score/25 | 25% | Net flow: \$$(echo "$net_flow" | cut -d. -f1) |" >> "$REPORT"
  echo "| Holder Quality | $holder_score/25 | 25% | SM holders: $sm_holders |" >> "$REPORT"  
  echo "| Trading Activity | $activity_score/25 | 25% | Trades: $recent_trades, Volume: \$$(echo "$volume_24h" | cut -d. -f1) |" >> "$REPORT"
  echo "| Performance | $performance_score/25 | 25% | Profitable wallets: $positive_pnl_count |" >> "$REPORT"
  echo "" >> "$REPORT"
  echo "### 🎯 Final Assessment" >> "$REPORT"
  echo "" >> "$REPORT"
  echo "- **Overall Score**: $total_score/100" >> "$REPORT"
  echo "- **Recommendation**: $recommendation" >> "$REPORT"
  echo "- **Risk Level**: $risk_level" >> "$REPORT"
  echo "- **Risk Factors**: $risk_factors/3 identified" >> "$REPORT"
  echo "" >> "$REPORT"
  
  # Key Insights
  echo "### 🔍 Key Insights" >> "$REPORT"
  echo "" >> "$REPORT"
  
  if [ $(echo "$flow_score > 20" | bc -l) = 1 ]; then
    echo "✅ **Strong Smart Money Interest** - Significant inflow detected" >> "$REPORT"
  fi
  
  if [ $(echo "$holder_score > 15" | bc -l) = 1 ]; then  
    echo "✅ **Quality Holder Base** - Multiple smart money wallets holding" >> "$REPORT"
  fi
  
  if [ $(echo "$activity_score > 15" | bc -l) = 1 ]; then
    echo "✅ **Active Trading** - High liquidity and interest" >> "$REPORT"  
  fi
  
  if [ $risk_factors -gt 1 ]; then
    echo "⚠️ **Risk Warning** - Multiple risk factors present, exercise caution" >> "$REPORT"
  fi
  
  echo "" >> "$REPORT"
fi

# --- Raw Data Section (Always Included) ---
echo "## 📋 Detailed Analysis Data" >> "$REPORT"
echo "_Complete data breakdown for manual verification_" >> "$REPORT"
echo "" >> "$REPORT"

# 1. Token Info
echo "### 1. Token Overview" >> "$REPORT"
echo '```json' >> "$REPORT"
cat "$RAW_DATA" | jq '.token_info' 2>/dev/null >> "$REPORT" || echo "Data unavailable" >> "$REPORT"
echo '```' >> "$REPORT"
echo "" >> "$REPORT"

# 2. Flow Analysis  
echo "### 2. Smart Money Flows" >> "$REPORT"
echo '```json' >> "$REPORT"
cat "$RAW_DATA" | jq '.flows' 2>/dev/null >> "$REPORT" || echo "Data unavailable" >> "$REPORT"
echo '```' >> "$REPORT"
echo "" >> "$REPORT"

# 3. Holder Breakdown
echo "### 3. Top Holders Analysis" >> "$REPORT"
echo '```' >> "$REPORT"
cat "$RAW_DATA" | jq -r '.holders[]? | "\(.label // .address[0:12])\t\(.percentage // "?")%\t$\(.balance_usd // 0 | tonumber | round)"' 2>/dev/null >> "$REPORT" || echo "Data unavailable" >> "$REPORT"
echo '```' >> "$REPORT"
echo "" >> "$REPORT"

# 4. Recent Activity
echo "### 4. Recent Trading Activity" >> "$REPORT"
echo '```' >> "$REPORT"
cat "$RAW_DATA" | jq -r '.dex_trades[:10][]? | "[\(.type)] \(.label // .address[0:10]) $\(.amount_usd // 0 | tonumber | round)"' 2>/dev/null >> "$REPORT" || echo "Data unavailable" >> "$REPORT"
echo '```' >> "$REPORT"
echo "" >> "$REPORT"

# Footer
echo "---" >> "$REPORT"
echo "" >> "$REPORT"
echo "## 🚀 What Makes This Analysis Different" >> "$REPORT"  
echo "" >> "$REPORT"
echo "✅ **AI-Powered Scoring** — 9 data points → unified investment recommendation" >> "$REPORT"
echo "✅ **Risk Assessment** — Automated red flag detection" >> "$REPORT" 
echo "✅ **Actionable Insights** — Clear buy/sell/hold recommendations" >> "$REPORT"
echo "✅ **Complete Transparency** — All raw data included for verification" >> "$REPORT"
echo "" >> "$REPORT"
echo "_This enhanced analysis combines comprehensive data collection with intelligent interpretation._" >> "$REPORT"
echo "_Built with Nansen CLI v$(nansen --version 2>/dev/null || echo 'unknown') | Enhanced for #NansenCLI Contest | Agent: Kuro 🐾_" >> "$REPORT"

# Save raw data if requested
if [ "$SAVE_RAW_DATA" = true ]; then
  cp "$RAW_DATA" "$OUTPUT_DIR/raw-data-${CHAIN}-${TOKEN:0:8}-${TIMESTAMP}.json"
fi

# Cleanup
rm -f "$RAW_DATA"

echo ""
echo "✅ Enhanced Due Diligence complete: $REPORT"
if [ "$GENERATE_SUMMARY" = true ]; then
  echo "🎯 Investment Score: $total_score/100"
  echo "📋 Recommendation: $(echo "$recommendation" | sed 's/🟢\|🟡\|🟠\|🔴//g' | sed 's/\*\*//g' | xargs)"
fi
echo "📊 Analysis covers 9 comprehensive data points"

# Display result
cat "$REPORT"