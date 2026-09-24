#!/usr/bin/env bash
# forge.sh — bookkeeping for /fate:forge. The orchestrating agent calls these
# subcommands in order and follows the NEXT line each one prints.
#
#   forge.sh init [--out DIR] [--from PATH] [--rounds N] [--per-round K] [--fresh]
#   forge.sh questions [--out DIR]   pick this round's questions; print every path the agents need
#   forge.sh verdicts  [--out DIR]   read both reviews; decide CONVERGED / REVISE / STALLED
#   forge.sh next      [--out DIR]   validate the revised draft, log the round, advance
#   forge.sh finish    [--out DIR] [--draft]   write the final sheet with a forged header
#   forge.sh status    [--out DIR]   print the current state
#
# State lives in DIR/forge/state.json (flat; parsed with sed, no jq needed).
# Defaults: DIR=./.fate, N=8, K=4, starting draft = whatever find-sheet.sh resolves.
set -uo pipefail

SELF="$(printf '%s' "${BASH_SOURCE[0]}" | tr '\134' '/')"   # \134 is a backslash: tolerate Windows paths
HERE="$(cd "$(dirname "$SELF")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
BANK="$ROOT/data/forge-questions.md"

die() { echo "forge.sh: $*" >&2; exit 1; }

# ---- arguments --------------------------------------------------------------
CMD="${1:-status}"; [ $# -gt 0 ] && shift
OUT="./.fate"; FROM=""; ROUNDS_ARG=""; PER_ARG=""; FRESH=0; DRAFT_FLAG=0
while [ $# -gt 0 ]; do
  case "$1" in
    --out)        OUT="$2"; shift 2 ;;
    --out=*)      OUT="${1#--out=}"; shift ;;
    --from)       FROM="$2"; shift 2 ;;
    --from=*)     FROM="${1#--from=}"; shift ;;
    --rounds)     ROUNDS_ARG="$2"; shift 2 ;;
    --rounds=*)   ROUNDS_ARG="${1#--rounds=}"; shift ;;
    --per-round)  PER_ARG="$2"; shift 2 ;;
    --per-round=*) PER_ARG="${1#--per-round=}"; shift ;;
    --fresh)      FRESH=1; shift ;;
    --draft)      DRAFT_FLAG=1; shift ;;
    --converged)  shift ;;
    *) die "unknown argument: $1" ;;
  esac
done
FORGE="$OUT/forge"; STATE="$FORGE/state.json"
OUTARG=""; [ "$OUT" != "./.fate" ] && OUTARG=" --out $OUT"
FORGE_CMD="bash \"\${CLAUDE_PLUGIN_ROOT}/scripts/forge.sh\""

# ---- state ------------------------------------------------------------------
ROUND=0; CURSOR=0; ROUNDS=8; PER=4; SOURCE=""; STARTED=""
load_state() {
  [ -r "$STATE" ] || return 1
  ROUND=$(sed -n 's/.*"round": *\([0-9]*\).*/\1/p' "$STATE")
  CURSOR=$(sed -n 's/.*"cursor": *\([0-9]*\).*/\1/p' "$STATE")
  ROUNDS=$(sed -n 's/.*"rounds": *\([0-9]*\).*/\1/p' "$STATE")
  PER=$(sed -n 's/.*"per_round": *\([0-9]*\).*/\1/p' "$STATE")
  SOURCE=$(sed -n 's/.*"source": *"\([^"]*\)".*/\1/p' "$STATE")
  STARTED=$(sed -n 's/.*"started": *"\([^"]*\)".*/\1/p' "$STATE")
  return 0
}
save_state() {
  printf '{"round": %s, "cursor": %s, "rounds": %s, "per_round": %s, "source": "%s", "started": "%s"}\n' \
    "$ROUND" "$CURSOR" "$ROUNDS" "$PER" "$SOURCE" "$STARTED" > "$STATE"
}
have() { [ -s "$1" ] && echo yes || echo no; }

# ---- question bank ----------------------------------------------------------
questions_all() { grep -E '^[0-9]+\. ' "$BANK" | sed -E 's/^[0-9]+\. //'; }

# ---- review parsing ---------------------------------------------------------
verdict_of() { grep -m1 -E '^VERDICT:' "$1" | sed -E 's/^VERDICT: *//; s/[^A-Z].*//'; }
count_sev()  { local n; n=$(grep -cE "^- \[$2-[0-9]+\].*Severity: *$3" "$1" 2>/dev/null); echo "${n:-0}"; }
must_keys()  {   # $1 review file, $2 prefix S|B → sorted, normalized "Where:" keys of must items
  grep -E "^- \[$2-[0-9]+\].*Severity: *must" "$1" 2>/dev/null \
    | sed -E 's/^- \[[SB]-[0-9]+\] *Where: *//; s/ *\|.*$//' \
    | tr 'A-Z' 'a-z' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//' | sort -u
}

# ---- subcommands ------------------------------------------------------------
cmd_status() {
  load_state || { echo "STATE: no forge in progress under $OUT"; return 0; }
  echo "STATE: round $ROUND of $ROUNDS, cursor=$CURSOR, per_round=$PER, source=$SOURCE, started=$STARTED"
  echo "DRAFT: $FORGE/draft-v$ROUND.md"
  local d="$FORGE/round-$ROUND"
  echo "HAVE: questions=$(have "$d/questions.md") readings=$(have "$d/readings.md") skeptic=$(have "$d/skeptic.md") believer=$(have "$d/believer.md") resolution=$(have "$d/resolution.md") next_draft=$(have "$FORGE/draft-v$((ROUND+1)).md")"
}

cmd_init() {
  if [ "$FRESH" = 1 ] && [ -d "$FORGE" ]; then rm -rf "$FORGE"; fi
  if load_state; then
    echo "RESUMING: round $ROUND of $ROUNDS (draft $FORGE/draft-v$ROUND.md)"
    echo "NEXT: $FORGE_CMD questions$OUTARG"
    return 0
  fi
  mkdir -p "$FORGE"
  local start tier res label
  if [ -n "$FROM" ]; then
    start="$FROM"; tier="given"
  else
    res="$(bash "$HERE/find-sheet.sh")" || die "no starting sheet found"
    tier="${res%%|*}"; start="${res#*|}"
  fi
  [ -r "$start" ] || die "starting draft not readable: $start"
  # The log and state record where the draft came from. A sheet inside the plugin
  # is written as <plugin>/…, never as this machine's absolute path: the log ships.
  case "$start" in
    "$ROOT"/*) label="<plugin>/${start#"$ROOT"/}" ;;
    *)         label="$start" ;;
  esac
  cp "$start" "$FORGE/draft-v0.md"
  bash "$HERE/check-sheet.sh" "$FORGE/draft-v0.md" || die "starting draft fails check-sheet; fix it first"
  ROUND=0; CURSOR=0; ROUNDS="${ROUNDS_ARG:-8}"; PER="${PER_ARG:-4}"; SOURCE="$label"
  STARTED="$(date -u +%Y-%m-%dT%H:%MZ)"
  save_state
  {
    echo "# Forge log"
    echo
    echo "Started: $STARTED · source: $label ($tier) · max rounds: $ROUNDS · questions per round: $PER"
    echo
  } > "$FORGE/forge-log.md"
  echo "STATE: round 0 of $ROUNDS, source=$label ($tier), per_round=$PER"
  echo "DRAFT: $FORGE/draft-v0.md"
  echo "NEXT: $FORGE_CMD questions$OUTARG"
}

cmd_questions() {
  load_state || die "no forge in progress; run init first"
  local dir="$FORGE/round-$ROUND" qfile total i idx prev
  mkdir -p "$dir"; qfile="$dir/questions.md"
  if [ ! -s "$qfile" ]; then
    total=$(questions_all | wc -l | tr -d ' ')
    [ "$total" -gt 0 ] || die "question bank is empty: $BANK"
    : > "$qfile"
    for i in $(seq 0 $((PER - 1))); do
      idx=$(( (CURSOR + i) % total + 1 ))
      questions_all | sed -n "${idx}p" >> "$qfile"
    done
    CURSOR=$(( (CURSOR + PER) % total )); save_state
  fi
  echo "ROUND: $ROUND of $ROUNDS"
  echo "DRAFT: $FORGE/draft-v$ROUND.md"
  echo "ROUND_DIR: $dir"
  echo "QUESTIONS:"; sed 's/^/  - /' "$qfile"
  prev=$((ROUND - 1))
  if [ "$ROUND" -gt 0 ]; then
    echo "PREV_SKEPTIC: $FORGE/round-$prev/skeptic.md"
    echo "PREV_BELIEVER: $FORGE/round-$prev/believer.md"
    echo "PREV_RESOLUTION: $FORGE/round-$prev/resolution.md"
  else
    echo "PREV_SKEPTIC: none"; echo "PREV_BELIEVER: none"; echo "PREV_RESOLUTION: none"
  fi
  echo "HAVE: readings=$(have "$dir/readings.md") skeptic=$(have "$dir/skeptic.md") believer=$(have "$dir/believer.md")"
  echo "NEXT: spawn fate:mystic-forge (MODE: readings) unless readings=yes; then spawn fate:skeptic and fate:believer in parallel (skip any that already exist); then run: $FORGE_CMD verdicts$OUTARG"
}

cmd_verdicts() {
  load_state || die "no forge in progress"
  local dir="$FORGE/round-$ROUND" sv bv sm sn bm bn nxt
  [ -s "$dir/skeptic.md" ]  || die "missing $dir/skeptic.md"
  [ -s "$dir/believer.md" ] || die "missing $dir/believer.md"
  sv=$(verdict_of "$dir/skeptic.md");  bv=$(verdict_of "$dir/believer.md")
  sm=$(count_sev "$dir/skeptic.md" S must);  sn=$(count_sev "$dir/skeptic.md" S nice)
  bm=$(count_sev "$dir/believer.md" B must); bn=$(count_sev "$dir/believer.md" B nice)
  [ "$sm" -gt 0 ] && sv=REVISE; [ "$bm" -gt 0 ] && bv=REVISE      # APPROVE with must items is a REVISE
  [ "$sv" = APPROVE ] || sv=REVISE; [ "$bv" = APPROVE ] || bv=REVISE
  echo "SKEPTIC: $sv must=$sm nice=$sn"
  echo "BELIEVER: $bv must=$bm nice=$bn"
  printf '%s\n%s\n' "SKEPTIC: $sv must=$sm nice=$sn" "BELIEVER: $bv must=$bm nice=$bn" > "$dir/verdicts.txt"

  if [ "$sv" = APPROVE ] && [ "$bv" = APPROVE ]; then
    echo "DECISION: CONVERGED at round $ROUND"
    echo "FINAL: $FORGE/draft-v$ROUND.md"
    echo "NEXT: $FORGE_CMD finish$OUTARG"
    return 0
  fi

  # Stall: the same must-fix "Where:" from the same reviewer in this round and the two before it.
  if [ "$ROUND" -ge 2 ]; then
    local stalled="" p name f0 f1 f2 k
    for p in S B; do
      name=$([ "$p" = S ] && echo skeptic || echo believer)
      f0="$dir/$name.md"; f1="$FORGE/round-$((ROUND - 1))/$name.md"; f2="$FORGE/round-$((ROUND - 2))/$name.md"
      { [ -s "$f1" ] && [ -s "$f2" ]; } || continue
      k=$(comm -12 <(must_keys "$f0" $p) <(comm -12 <(must_keys "$f1" $p) <(must_keys "$f2" $p)))
      [ -n "$k" ] && stalled="$stalled$(printf '\n  %s: %s' "$name" "$(echo "$k" | paste -sd ';' -)")"
    done
    if [ -n "$stalled" ]; then
      echo "DECISION: STALLED. The same must-fix request has survived three rounds:$stalled"
      echo "NEXT: this needs a human ruling. If one is present, show both sides (the reviews and resolution notes under $FORGE/round-*/), ask them to rule, write the ruling as a note in Part I of a fresh copy at $FORGE/draft-v$((ROUND + 1)).md, then run: $FORGE_CMD next$OUTARG. If nobody can answer (non-interactive), run: $FORGE_CMD finish --draft$OUTARG and report the dispute."
      return 0
    fi
  fi

  nxt="$FORGE/draft-v$((ROUND + 1)).md"
  cp "$FORGE/draft-v$ROUND.md" "$nxt"
  echo "DECISION: REVISE"
  echo "NEXT_DRAFT: $nxt"
  echo "SKEPTIC_REVIEW: $dir/skeptic.md"
  echo "BELIEVER_REVIEW: $dir/believer.md"
  echo "READINGS: $dir/readings.md"
  echo "RESOLUTION: $dir/resolution.md"
  echo "NEXT: spawn fate:mystic-forge (MODE: revise) with DRAFT=NEXT_DRAFT and the four paths above; then run: $FORGE_CMD next$OUTARG"
}

cmd_next() {
  load_state || die "no forge in progress"
  local dir="$FORGE/round-$ROUND" nxt="$FORGE/draft-v$((ROUND + 1)).md" report
  [ -s "$nxt" ] || die "no revised draft at $nxt (run verdicts first)"
  if ! report=$(bash "$HERE/check-sheet.sh" "$nxt" 2>&1); then
    echo "CHECK_FAILED: $nxt"
    echo "$report"
    echo "NEXT: spawn fate:mystic-forge (MODE: repair) with DRAFT=$nxt and this report; then run: $FORGE_CMD next$OUTARG"
    return 1
  fi
  local qs cards sk bl applied rejected merged lines
  qs=$(sed 's/^/  - /' "$dir/questions.md" 2>/dev/null)
  cards=$(grep -oE '— [A-Za-z ]+ \((upright|reversed)\)' "$dir/readings.md" 2>/dev/null | sed 's/^— //' | paste -sd ',' - | sed 's/,/, /g')
  sk=$(sed -n '1p' "$dir/verdicts.txt" 2>/dev/null); bl=$(sed -n '2p' "$dir/verdicts.txt" 2>/dev/null)
  applied=$(grep -cE '^- \[[SBM]-[0-9]+\] *APPLIED' "$dir/resolution.md" 2>/dev/null);  applied=${applied:-0}
  rejected=$(grep -cE '^- \[[SBM]-[0-9]+\] *REJECTED' "$dir/resolution.md" 2>/dev/null); rejected=${rejected:-0}
  merged=$(grep -cE '^- \[[SBM]-[0-9]+\] *MERGED' "$dir/resolution.md" 2>/dev/null);    merged=${merged:-0}
  lines=$(wc -l < "$nxt" | tr -d ' ')
  {
    echo "## Round $ROUND: reviewed draft-v$ROUND.md, produced draft-v$((ROUND + 1)).md ($lines lines)"
    echo "Questions:"; echo "$qs"
    echo "Cards: ${cards:-?}"
    echo "$sk"; echo "$bl"
    echo "Editor: applied $applied, rejected $rejected, merged $merged (round-$ROUND/resolution.md)"
    echo
  } >> "$FORGE/forge-log.md"
  ROUND=$((ROUND + 1)); save_state
  if [ "$ROUND" -ge "$ROUNDS" ]; then
    echo "DONE: reached max rounds ($ROUNDS) without both approvals; the latest draft is $nxt (unreviewed)"
    echo "NEXT: $FORGE_CMD finish --draft$OUTARG"
  else
    echo "ADVANCED: round $ROUND of $ROUNDS"
    echo "NEXT: $FORGE_CMD questions$OUTARG"
  fi
}

cmd_finish() {
  load_state || die "no forge in progress"
  local final status stamp dest
  if [ "$DRAFT_FLAG" = 1 ]; then
    final=$(ls "$FORGE"/draft-v*.md | sed -E 's/.*draft-v([0-9]+)\.md$/\1 &/' | sort -n | tail -1 | cut -d' ' -f2-)
    status="NOT CONVERGED (draft)"
  else
    final="$FORGE/draft-v$ROUND.md"; status="converged"
  fi
  [ -s "$final" ] || die "final draft not found: $final"
  stamp=$(date -u +%Y-%m-%d)
  dest="$OUT/tarot-cheat-sheet.md"
  sed -E "s|^Version:.*|Version: forged v1 · $stamp · $ROUND round(s) · $status · re-forge with /fate:forge|" "$final" > "$dest"
  bash "$HERE/check-sheet.sh" "$dest" > /dev/null || die "final sheet fails check-sheet: $dest"
  { echo "## Finished"; echo "Status: $status · final: $(basename "$final") · written to $dest"; echo; } >> "$FORGE/forge-log.md"
  echo "FINAL: $dest ($status, after $ROUND round(s))"
  echo "LOG: $FORGE/forge-log.md"
  echo "SUMMARY:"
  grep -E '^(## Round|SKEPTIC|BELIEVER|Editor)' "$FORGE/forge-log.md" | sed 's/^/  /'
  echo "NEXT: DONE. Report the summary to the human. To ship, copy $dest to <plugin>/cheat-sheet/tarot-cheat-sheet.md and $FORGE/forge-log.md to <plugin>/cheat-sheet/forge-log.md."
}

case "$CMD" in
  init)      cmd_init ;;
  questions) cmd_questions ;;
  verdicts)  cmd_verdicts ;;
  next)      cmd_next ;;
  finish)    cmd_finish ;;
  status)    cmd_status ;;
  -h|--help) sed -n '2,14p' "$SELF" ;;
  *) die "unknown subcommand: $CMD (init|questions|verdicts|next|finish|status)" ;;
esac
