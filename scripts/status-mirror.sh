#!/usr/bin/env bash
# Public mirror of a private workflow's verdict (plan-2607-40 slice 05).
#
# The Status: Forestrie badges point at forest-1 and release-orchestrator, both
# private. GitHub serves `badge.svg` for a private repo only to viewers who can
# see the repo, so an anonymous visitor to github.com/forestrie gets 404 and a
# broken image while signed-in org members see the real state. There is no
# native way to expose a private workflow's status; the verdict has to be
# mirrored into a public one.
#
# Two modes, both ending in this workflow's own run conclusion — which is what
# the badge renders:
#
#   report  a repository_dispatch arrived from the private source workflow.
#           Exit 0/1 to match the conclusion it reported.
#
#   verify  a scheduled tick. Read the most recent completed `report` run of
#           this same workflow and fail if it is missing, stale, or was itself
#           a failure.
#
# The `verify` mode is the important half. A mirror that simply replays
# dispatches goes silently stale the moment the source stops dispatching —
# freezing green — which is the exact failure this whole exercise exists to
# remove (a Lane B badge that showed no status while Lane B was failing). With
# the staleness check the badge goes RED when reports stop arriving, so silence
# is never mistaken for health.
set -euo pipefail

: "${MODE:?MODE must be report or verify}"
: "${LABEL:?}"
: "${SOURCE:?}"
: "${WORKFLOW_FILE:?}"
: "${MAX_AGE_HOURS:?}"

summary() { printf '%s\n' "$*" >>"${GITHUB_STEP_SUMMARY:-/dev/stdout}"; }

case "$MODE" in
report)
  conclusion="${REPORTED_CONCLUSION:-}"
  run_url="${REPORTED_RUN_URL:-}"
  detail="${REPORTED_DETAIL:-}"

  if [ -z "$conclusion" ]; then
    echo "::error::${SOURCE} dispatched without a conclusion in client_payload" >&2
    summary "## ${LABEL}: malformed report"
    summary "\`${SOURCE}\` dispatched with no \`client_payload.conclusion\`."
    exit 1
  fi

  summary "## ${LABEL}: ${conclusion}"
  summary ""
  summary "Reported by \`${SOURCE}\`."
  [ -n "$run_url" ] && summary "Source run: ${run_url}"
  [ -n "$detail" ] && summary "" && summary "${detail}"

  if [ "$conclusion" != "success" ]; then
    echo "::error::${SOURCE} reported ${conclusion}${run_url:+ — ${run_url}}" >&2
    exit 1
  fi
  echo "${SOURCE} reported success${run_url:+ — ${run_url}}"
  ;;

verify)
  : "${GH_TOKEN:?GH_TOKEN required to read the mirror run history}"

  row=$(gh run list \
    --repo "${GITHUB_REPOSITORY}" \
    --workflow "${WORKFLOW_FILE}" \
    --event repository_dispatch \
    --status completed \
    --limit 1 \
    --json conclusion,createdAt,url \
    --jq '.[0] // empty')

  if [ -z "$row" ]; then
    echo "::error::${SOURCE} has never reported a verdict — the badge has no basis to be green" >&2
    summary "## ${LABEL}: never reported"
    summary ""
    summary "No \`repository_dispatch\` run of \`${WORKFLOW_FILE}\` exists yet."
    summary "Confirm \`${SOURCE}\` has the mirror dispatch step and that the"
    summary "GitHub App installation can write to this repository."
    exit 1
  fi

  conclusion=$(jq -r '.conclusion' <<<"$row")
  url=$(jq -r '.url' <<<"$row")
  # jq's fromdateiso8601 rather than `date -d`: the latter is a GNU extension,
  # so this stays runnable (and testable) off an ubuntu runner.
  created_epoch=$(jq -r '.createdAt | fromdateiso8601' <<<"$row")
  age_hours=$((($(date -u +%s) - created_epoch) / 3600))

  summary "## ${LABEL}: last report ${conclusion} (${age_hours}h ago)"
  summary ""
  summary "Source: \`${SOURCE}\` · [mirror run](${url}) · staleness limit ${MAX_AGE_HOURS}h."

  if [ "$age_hours" -gt "$MAX_AGE_HOURS" ]; then
    echo "::error::last verdict from ${SOURCE} is ${age_hours}h old (limit ${MAX_AGE_HOURS}h) — reporting has stopped, so this badge is stale, not healthy" >&2
    exit 1
  fi

  if [ "$conclusion" != "success" ]; then
    echo "::error::last verdict from ${SOURCE} was ${conclusion} — ${url}" >&2
    exit 1
  fi

  echo "${SOURCE} last reported success ${age_hours}h ago (limit ${MAX_AGE_HOURS}h)"
  ;;

*)
  echo "::error::unknown MODE '${MODE}' (expected report or verify)" >&2
  exit 1
  ;;
esac
