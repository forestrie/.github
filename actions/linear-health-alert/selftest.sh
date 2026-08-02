#!/usr/bin/env bash
# Live lifecycle verification for linear-health-alert (plan 2608-06, Phase 1 gate).
#
#   LINEAR_API_KEY=… bash actions/linear-health-alert/selftest.sh
#
# Deliberately NOT wired into CI. It writes to the real Linear workspace — the
# only place the behaviour under test exists — so it runs on demand against a
# scratch alert key and cancels nothing: the issues it leaves behind are titled
# `[scratch] alerter self-test` and end Done. Cancel or delete them afterwards.
#
# Every step asserts the OBSERVABLE EFFECT (how many issues are open, how many
# comments exist), not merely that the script exited 0. An alerter that silently
# does nothing exits 0 too.
set -euo pipefail

ACTION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LINEAR_API_KEY="${LINEAR_API_KEY:?LINEAR_API_KEY required}"
export ALERT_KEY="${ALERT_KEY:-scratch-alerter-selftest}"
export TEAM_KEY="${TEAM_KEY:-FOR}"
export GITHUB_REPOSITORY=forestrie/.github
export GITHUB_WORKFLOW_REF='forestrie/.github/.github/workflows/selftest.yml@refs/heads/main'
export RUN_URL='https://example.invalid/run/1'

MARKER="health-alert-key: ${ALERT_KEY}"
fails=0
ISSUE_ID=""

gql() {
  curl -sS https://api.linear.app/graphql -H "Authorization: $LINEAR_API_KEY" \
    -H "Content-Type: application/json" -d "$1"
}

open_count() {
  gql "$(jq -nc --arg m "$MARKER" --arg t "$TEAM_KEY" '{
    query:"query($m:String!,$t:String!){issues(filter:{team:{key:{eq:$t}},description:{contains:$m},state:{type:{nin:[\"completed\",\"canceled\"]}}},first:50){nodes{id}}}",
    variables:{m:$m,t:$t}}')" | jq '.data.issues.nodes | length'
}

open_id() {
  gql "$(jq -nc --arg m "$MARKER" --arg t "$TEAM_KEY" '{
    query:"query($m:String!,$t:String!){issues(filter:{team:{key:{eq:$t}},description:{contains:$m},state:{type:{nin:[\"completed\",\"canceled\"]}}},first:1){nodes{id}}}",
    variables:{m:$m,t:$t}}')" | jq -r '.data.issues.nodes[0].id // empty'
}

# Counted on THE issue this run created, by id. Counting by marker would sweep
# in the resolved issues left by previous self-test runs.
comment_count() {
  gql "$(jq -nc --arg id "$ISSUE_ID" '{query:"query($id:String!){issue(id:$id){comments{nodes{id}}}}",variables:{id:$id}}')" |
    jq '.data.issue.comments.nodes | length'
}

run() { # run <expected-action> <VAR=VAL>...
  local expect="$1" out got
  shift
  out=$(mktemp)
  GITHUB_OUTPUT="$out" env "$@" bash "$ACTION_DIR/linear-health-alert.sh" >/dev/null
  got=$(grep -E '^action=' "$out" | tail -1 | cut -d= -f2)
  if [ "$got" = "$expect" ]; then echo "ok   action=$got"; else
    echo "FAIL expected action=$expect got action=${got:-<none>}"
    fails=$((fails + 1))
  fi
}

check() { # check <label> <expected> <actual>
  if [ "$2" = "$3" ]; then echo "ok   $1 = $3"; else
    echo "FAIL $1: expected $2, got $3"
    fails=$((fails + 1))
  fi
}

expect_failure() { # expect_failure <label> <VAR=VAL>...
  local label="$1"
  shift
  if GITHUB_OUTPUT=$(mktemp) env "$@" bash "$ACTION_DIR/linear-health-alert.sh" >/dev/null 2>&1; then
    echo "FAIL $label was tolerated"
    fails=$((fails + 1))
  else
    echo "ok   $label rejected"
  fi
}

echo "--- 1. first failing call creates exactly one issue"
run created STATE=failing TITLE='[scratch] alerter self-test' BODY_MD='Body v1.'
check "open issues" 1 "$(open_count)"
ISSUE_ID=$(open_id)
check "comments" 0 "$(comment_count)"

echo "--- 2. identical call writes nothing and never duplicates"
run unchanged STATE=failing TITLE='[scratch] alerter self-test' BODY_MD='Body v1.'
check "open issues" 1 "$(open_count)"
check "comments" 0 "$(comment_count)"

echo "--- 3. changed body edits the same issue and comments once"
run updated STATE=failing TITLE='[scratch] alerter self-test' BODY_MD='Body v2 - streak 3.'
check "open issues" 1 "$(open_count)"
check "comments" 1 "$(comment_count)"

echo "--- 4. same body, newer run link: edits, but does NOT comment again"
RUN_URL='https://example.invalid/run/2' \
  run updated STATE=failing TITLE='[scratch] alerter self-test' BODY_MD='Body v2 - streak 3.'
check "open issues" 1 "$(open_count)"
check "comments" 1 "$(comment_count)"

echo "--- 5. a key owned by another workflow is a hard error"
expect_failure "alert_key collision" GITHUB_REPOSITORY=forestrie/canopy \
  GITHUB_WORKFLOW_REF='forestrie/canopy/.github/workflows/other.yml@refs/heads/main' \
  STATE=failing TITLE=x BODY_MD=x

echo "--- 6. green resolves it, with a closing comment"
run resolved STATE=green
check "open issues" 0 "$(open_count)"
check "comments" 2 "$(comment_count)"

echo "--- 7. green with nothing open is a no-op success"
run noop STATE=green
check "open issues" 0 "$(open_count)"

echo "--- 8. misconfiguration is loud, never silent"
expect_failure "missing credential" LINEAR_API_KEY= STATE=green
expect_failure "non-slug alert_key" ALERT_KEY='Not A Slug' STATE=green
expect_failure "unknown state" STATE=amber
expect_failure "failing without a title" STATE=failing TITLE=''
expect_failure "unknown label" STATE=failing TITLE=x LABELS=no-such-label ALERT_KEY="${ALERT_KEY}-label"

if [ "$fails" -eq 0 ]; then
  printf '\nALL ASSERTIONS PASSED\n'
else
  printf '\n%d ASSERTION(S) FAILED\n' "$fails"
  exit 1
fi
