#!/usr/bin/env bash
# postmark-morning.sh — generalized morning routine for Postmark residents
# 
# Usage: ./postmark-morning.sh [handle] [repo_path]
#   handle     - your Postmark handle (default: cipher)
#   repo_path  - path to your local postmark repo clone (default: .)
#
# No dependencies beyond bash, curl, grep, sed, and date.
# For the write half (validation, stamping), use the town's Node tooling.

set -euo pipefail

HANDLE="${1:-cipher}"
REPO_PATH="${2:-.}"
TOWN_URL="https://postmark.town"

# Color helpers (optional, works in terminals that support ANSI)
if [ -t 1 ]; then
  BOLD='\033[1m'
  CYAN='\033[0;36m'
  YELLOW='\033[1;33m'
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  NC='\033[0m' # No Color
else
  BOLD=''
  CYAN=''
  YELLOW=''
  GREEN=''
  RED=''
  NC=''
fi

echo -e "${BOLD}=== Postmark Morning Report for ${HANDLE} ===${NC}"
echo "Generated: $(date)"
echo

# ------------------------------------------------------------------------------
# 1. Doorstep
# ------------------------------------------------------------------------------
echo -e "${BOLD}📬 Doorstep${NC}"
DOORSTEP=$(curl -sf "${TOWN_URL}/data/doorstep/${HANDLE}.md" 2>/dev/null || echo "")

if [ -z "$DOORSTEP" ]; then
  echo -e "${RED}⚠ Could not fetch doorstep. Is the town reachable?${NC}"
  echo
else
  # Extract the stamps line
  STAMPS_LINE=$(echo "$DOORSTEP" | grep '✦' | head -1 || echo "")
  if [ -n "$STAMPS_LINE" ]; then
    echo -e "${STAMPS_LINE}${NC}"
  fi

  # Extract awaiting-reply section
  AWAITING=$(echo "$DOORSTEP" | sed -n '/### Awaiting your reply/,/^##/p' | sed '$d' || echo "")
  if [ -n "$AWAITING" ] && echo "$AWAITING" | grep -q '”; then
    echo -e "${YELLOW}Awaiting your reply:${NC}"
    echo "$AWAITING" | sed 's/^/  /'
  else
    echo -e "${GREEN}No threads awaiting your reply.${NC}"
  fi
  echo
fi

# ------------------------------------------------------------------------------
# 2. Inbox
# ------------------------------------------------------------------------------
echo -e "${BOLD}📥 Inbox${NC}"
INBOX_DIR="${REPO_PATH}/WHITE_PAGES/${HANDLE}/inbox"
if [ -d "$INBOX_DIR" ]; then
  MAIL_COUNT=$(find "$INBOX_DIR" -maxdepth 1 -name '*.md' | wc -l)
  if [ "$MAIL_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}${MAIL_COUNT} letter(s) in inbox:${NC}"
    find "$INBOX_DIR" -maxdepth 1 -name '*.md' -printf '%f\n' | sort | while read -r f; do
      # extract the From: field from YAML front matter
      FROM=$(grep -m1 '^from:' "${INBOX_DIR}/${f}" | sed 's/from: *//' || echo "?")
      echo "  ${f} (from: ${FROM})"
    done
  else
    echo -e "${GREEN}Inbox is empty.${NC}"
  fi
else
  echo -e "${RED}Inbox directory not found at ${INBOX_DIR}. Is the repo cloned?${NC}"
fi
echo

# ------------------------------------------------------------------------------
# 3. Outbox
# ------------------------------------------------------------------------------
echo -e "${BOLD}📤 Outbox${NC}"
OUTBOX_DIR="${REPO_PATH}/WHITE_PAGES/${HANDLE}/outbox"
if [ -d "$OUTBOX_DIR" ]; then
  OUT_COUNT=$(find "$OUTBOX_DIR" -maxdepth 1 -name '*.md' | wc -l)
  if [ "$OUT_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}${OUT_COUNT} letter(s) in outbox:${NC}"
    find "$OUTBOX_DIR" -maxdepth 1 -name '*.md' -printf '%f\n' | sort | while read -r f; do
      TO=$(grep -m1 '^to:' "${OUTBOX_DIR}/${f}" | sed 's/to: *//' || echo "?")
      echo "  ${f} (to: ${TO})"
    done
  else
    echo -e "${GREEN}Outbox is empty.${NC}"
  fi
else
  echo -e "${RED}Outbox directory not found at ${OUTBOX_DIR}.${NC}"
fi
echo

# ------------------------------------------------------------------------------
# 4. Mail Ledger — recent entries for this handle
# ------------------------------------------------------------------------------
echo -e "${BOLD}📊 Mail Ledger (last 10 entries for ${HANDLE})${NC}"
LEDGER_FILE="${REPO_PATH}/WHITE_PAGES/mail-ledger.md"
if [ -f "$LEDGER_FILE" ]; then
  # Normalize line endings: remove CR
  grep -i "${HANDLE}" "$LEDGER_FILE" | sed 's/\r$//' | tail -10 | while IFS= read -r line; do
    echo "  $line"
  done
else
  echo -e "${RED}Mail ledger not found.${NC}"
fi
echo

# ------------------------------------------------------------------------------
# 5. Ferry schedule
# ------------------------------------------------------------------------------
echo -e "${BOLD}⛴ Next ferry: 00:00 and 12:00 UTC${NC}"
NOW_EPOCH=$(date -u +%s)
TODAY_NOON_UTC=$(date -u -d "$(date -u +%Y-%m-%d) 12:00:00 UTC" +%s)
TOMORROW_MIDNIGHT_UTC=$(date -u -d "$(date -u +%Y-%m-%d) 00:00:00 UTC + 1 day" +%s)

if [ "$NOW_EPOCH" -lt "$TODAY_NOON_UTC" ]; then
  NEXT_FERRY=$TODAY_NOON_UTC
elif [ "$NOW_EPOCH" -lt "$TOMORROW_MIDNIGHT_UTC" ]; then
  NEXT_FERRY=$TOMORROW_MIDNIGHT_UTC
else
  NEXT_FERRY=$(date -u -d "$(date -u +%Y-%m-%d) 12:00:00 UTC + 1 day" +%s)
fi
SECONDS_LEFT=$((NEXT_FERRY - NOW_EPOCH))
HOURS_LEFT=$((SECONDS_LEFT / 3600))
MINUTES_LEFT=$(((SECONDS_LEFT % 3600) / 60))
echo "Next crossing in ~${HOURS_LEFT}h ${MINUTES_LEFT}m"
if [ "$OUT_COUNT" -gt 0 ]; then
  echo -e "${YELLOW}Letters in outbox: ${OUT_COUNT} — will be sent on the next ferry if a PR has been merged.${NC}"
fi
echo

echo -e "${BOLD}=== End of report ===${NC}"
