#!/usr/bin/env bash
# Linear issue lifecycle for scheduled-health alerts (plan-2608-02, FOR-517).
#
# Two silent red streaks happened in the same week — `qualify-dev` red for six
# days, the canopy metering canary red for three — and both were found by
# accident. Nothing in the estate notified anyone of anything. GitHub's built-in
# scheduled-failure email goes to whoever last committed the workflow file and
# fires per run, which under an hourly retry policy is spam, not a signal.
#
# So the alert is a Linear issue, because that is where the remediation work
# lives, and its unit is the FAILING THING, not the run:
#
#   failing  first call raises one issue carrying `alert_key`; every later call
#            EDITS that same issue (streak, changed suspect delta, newest run)
#            instead of raising another.
#   green    the open issue for `alert_key` is commented and closed, so a
#            recovered canary cleans up after itself.
#
# Loud by construction. A missing credential, an unknown label, a Linear API
# error or an alert_key already owned by a different workflow all exit non-zero,
# which fails the health run itself. An alerter that silently no-ops is the
# disease this exists to cure, so it is never allowed to be the quiet one.
#
# The key is read from the environment and never printed, never written to
# GITHUB_OUTPUT, and never crosses a job boundary — see docs/ci-policy.md.
#
# shellcheck disable=SC2016 # GraphQL documents are single-quoted on purpose: $team, $marker etc. are GraphQL variables, not shell ones
set -euo pipefail

: "${LINEAR_API_KEY:?LINEAR_API_KEY is empty. If this repo is PRIVATE, an org secret will not reach it on the free plan no matter how it is scoped — set a repo-level secret instead. See docs/ci-policy.md}"
: "${ALERT_KEY:?ALERT_KEY is required}"
: "${STATE:?STATE must be 'failing' or 'green'}"
: "${TEAM_KEY:=FOR}"

# The key lands inside an HTML comment that is also a substring filter. Keeping
# it to a boring charset means it can never terminate the comment or widen the
# search into unrelated issues.
if ! printf '%s' "$ALERT_KEY" | grep -Eq '^[a-z0-9][a-z0-9._-]{1,63}$'; then
  echo "::error::alert_key '${ALERT_KEY}' is not a slug — expected ^[a-z0-9][a-z0-9._-]{1,63}$" >&2
  exit 1
fi

case "$STATE" in
failing)
  : "${TITLE:?TITLE is required when state=failing}"
  ;;
green) ;;
*)
  echo "::error::state must be 'failing' or 'green' (got '${STATE}')" >&2
  exit 1
  ;;
esac

BODY_MD="${BODY_MD:-}"
RUN_URL="${RUN_URL:-}"
PROJECT_NAME="${PROJECT_NAME:-}"
LABELS="${LABELS:-}"

# Which workflow owns this key. Two workflows sharing an alert_key would fight
# over one issue — each resolving the other's alert — so ownership is recorded
# on the issue and a mismatch is a hard configuration error rather than a
# documented quirk. GITHUB_WORKFLOW_REF is `owner/repo/.github/workflows/x.yml@ref`.
workflow_path="${GITHUB_WORKFLOW_REF:-}"
workflow_path="${workflow_path%@*}"
workflow_path="${workflow_path#"${GITHUB_REPOSITORY:-}/"}"
OWNER="${GITHUB_REPOSITORY:-local} ${workflow_path:-${GITHUB_WORKFLOW:-manual}}"

summary() { printf '%s\n' "$*" >>"${GITHUB_STEP_SUMMARY:-/dev/stdout}"; }
emit() { [ -n "${GITHUB_OUTPUT:-}" ] && printf '%s=%s\n' "$1" "$2" >>"$GITHUB_OUTPUT"; return 0; }

# --- GraphQL -----------------------------------------------------------------
# Linear answers 200 with an `errors` array for most failures, so the HTTP code
# alone is not a verdict. Both are checked; either one failing stops the run.
gql() {
  local query="$1" variables="${2:-{\}}" payload response http body
  payload=$(jq -nc --arg q "$query" --argjson v "$variables" '{query:$q, variables:$v}')
  response=$(curl -sS -w $'\n%{http_code}' https://api.linear.app/graphql \
    -H "Authorization: ${LINEAR_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$payload") || {
    echo "::error::Linear API unreachable — the alerter cannot fail quietly, so this run fails" >&2
    exit 1
  }
  http="${response##*$'\n'}"
  body="${response%$'\n'*}"
  if [ "$http" != "200" ]; then
    echo "::error::Linear API returned HTTP ${http}: $(jq -rc '.errors // .' <<<"$body" 2>/dev/null || printf '%s' "$body")" >&2
    exit 1
  fi
  if jq -e '.errors' >/dev/null 2>&1 <<<"$body"; then
    echo "::error::Linear API error: $(jq -rc '.errors' <<<"$body")" >&2
    exit 1
  fi
  printf '%s' "$body"
}

key_marker="<!-- health-alert-key: ${ALERT_KEY} -->"

# --- Find the open issue for this key ----------------------------------------
existing=$(gql '
query Find($team: String!, $marker: String!) {
  issues(filter: {
    team: { key: { eq: $team } }
    description: { contains: $marker }
    state: { type: { nin: ["completed", "canceled"] } }
  }, first: 10) {
    nodes { id identifier url title description }
  }
}' "$(jq -nc --arg team "$TEAM_KEY" --arg marker "$key_marker" '{team:$team, marker:$marker}')" |
  jq -c '.data.issues.nodes')

count=$(jq 'length' <<<"$existing")
if [ "$count" -gt 1 ]; then
  echo "::error::${count} open issues carry alert key '${ALERT_KEY}' ($(jq -r 'map(.identifier)|join(", ")' <<<"$existing")) — close all but one; the alerter will not guess" >&2
  exit 1
fi

issue_id=$(jq -r '.[0].id // empty' <<<"$existing")
issue_url=$(jq -r '.[0].url // empty' <<<"$existing")
issue_ident=$(jq -r '.[0].identifier // empty' <<<"$existing")
issue_desc=$(jq -r '.[0].description // empty' <<<"$existing")

# Markers are HTML comments, which Linear stores verbatim — unlike the markdown
# around them. They are the only part of the description safe to compare against.
marker_value() { sed -n "s/^<!-- health-alert-$1: \\(.*\\) -->\$/\\1/p" <<<"$issue_desc" | head -1; }

if [ -n "$issue_id" ]; then
  prior_owner=$(marker_value owner)
  if [ -n "$prior_owner" ] && [ "$prior_owner" != "$OWNER" ]; then
    echo "::error::alert key '${ALERT_KEY}' is already owned by '${prior_owner}' but this run is '${OWNER}' (${issue_url}) — two workflows sharing a key would resolve each other's alerts; give this workflow its own key" >&2
    exit 1
  fi
fi

# --- green: resolve ----------------------------------------------------------
if [ "$STATE" = "green" ]; then
  if [ -z "$issue_id" ]; then
    echo "no open alert for '${ALERT_KEY}' — nothing to resolve"
    summary "## Health alert \`${ALERT_KEY}\`: green (no open alert)"
    emit action noop
    exit 0
  fi

  done_state=$(gql '
query DoneState($team: String!) {
  workflowStates(filter: { team: { key: { eq: $team } }, type: { eq: "completed" } }, first: 50) {
    nodes { id name position }
  }
}' "$(jq -nc --arg team "$TEAM_KEY" '{team:$team}')" |
    jq -r '.data.workflowStates.nodes | sort_by(.position) | .[0].id // empty')
  if [ -z "$done_state" ]; then
    echo "::error::team ${TEAM_KEY} has no workflow state of type 'completed' — cannot resolve ${issue_ident}" >&2
    exit 1
  fi

  gql '
mutation Comment($issueId: String!, $body: String!) {
  commentCreate(input: { issueId: $issueId, body: $body }) { success }
}' "$(jq -nc --arg issueId "$issue_id" \
    --arg body "Recovered — \`${ALERT_KEY}\` is green again.${RUN_URL:+ Qualifying run: ${RUN_URL}}" \
    '{issueId:$issueId, body:$body}')" >/dev/null

  gql '
mutation Resolve($id: String!, $stateId: String!) {
  issueUpdate(id: $id, input: { stateId: $stateId }) { success }
}' "$(jq -nc --arg id "$issue_id" --arg stateId "$done_state" '{id:$id, stateId:$stateId}')" >/dev/null

  echo "resolved ${issue_ident} — ${issue_url}"
  summary "## Health alert \`${ALERT_KEY}\`: resolved"
  summary ""
  summary "[${issue_ident}](${issue_url}) closed${RUN_URL:+ by [this run](${RUN_URL})}."
  emit action resolved
  emit issue_identifier "$issue_ident"
  emit issue_url "$issue_url"
  exit 0
fi

# --- failing: raise or edit --------------------------------------------------
# Two hashes, both stored as markers, because Linear NORMALISES markdown on the
# way in — a bare URL comes back as an autolink — so the description we wrote is
# never the description we read, and comparing the two would report "changed"
# forever. HTML comments survive verbatim, so the comparison is against values
# we control:
#
#   state  everything the caller passed. Identical => write nothing at all.
#   body   `body_md` alone. The run link moves every cycle and must not read as
#          new information; a changed body — a longer streak, a different
#          suspect pin delta — is what earns a comment.
sha() { printf '%s' "$1" | shasum -a 256 | cut -d' ' -f1; }
body_sha=$(sha "$BODY_MD")
state_sha=$(sha "${TITLE}"$'\n'"${BODY_MD}"$'\n'"${RUN_URL}"$'\n'"${OWNER}")

description=$(
  printf '%s\n' "$key_marker"
  printf '<!-- health-alert-owner: %s -->\n' "$OWNER"
  printf '<!-- health-alert-body-sha: %s -->\n' "$body_sha"
  printf '<!-- health-alert-state-sha: %s -->\n' "$state_sha"
  printf '\n'
  [ -n "$BODY_MD" ] && printf '%s\n\n' "$BODY_MD"
  [ -n "$RUN_URL" ] && printf 'Latest failing run: %s\n\n' "$RUN_URL"
  printf 'Raised automatically by `linear-health-alert` (%s). This issue closes itself when `%s` next reports green.\n' "$OWNER" "$ALERT_KEY"
)

if [ -n "$issue_id" ]; then
  if [ "$(marker_value state-sha)" = "$state_sha" ]; then
    echo "alert '${ALERT_KEY}' unchanged — ${issue_ident} ${issue_url}"
    summary "## Health alert \`${ALERT_KEY}\`: still failing"
    summary ""
    summary "[${issue_ident}](${issue_url}) already reflects this state; nothing written."
    emit action unchanged
    emit issue_identifier "$issue_ident"
    emit issue_url "$issue_url"
    exit 0
  fi

  gql '
mutation Edit($id: String!, $title: String!, $description: String!) {
  issueUpdate(id: $id, input: { title: $title, description: $description }) { success }
}' "$(jq -nc --arg id "$issue_id" --arg title "$TITLE" --arg description "$description" \
    '{id:$id, title:$title, description:$description}')" >/dev/null

  if [ "$(marker_value body-sha)" != "$body_sha" ]; then
    gql '
mutation Comment($issueId: String!, $body: String!) {
  commentCreate(input: { issueId: $issueId, body: $body }) { success }
}' "$(jq -nc --arg issueId "$issue_id" \
      --arg body "Alert detail changed.${RUN_URL:+ Run: ${RUN_URL}}"$'\n\n'"${BODY_MD}" \
      '{issueId:$issueId, body:$body}')" >/dev/null
  fi

  echo "updated ${issue_ident} — ${issue_url}"
  summary "## Health alert \`${ALERT_KEY}\`: still failing (updated)"
  summary ""
  summary "[${issue_ident}](${issue_url}) updated."
  emit action updated
  emit issue_identifier "$issue_ident"
  emit issue_url "$issue_url"
  exit 0
fi

# --- create ------------------------------------------------------------------
team_id=$(gql '
query Team($team: String!) { teams(filter: { key: { eq: $team } }, first: 1) { nodes { id } } }' \
  "$(jq -nc --arg team "$TEAM_KEY" '{team:$team}')" | jq -r '.data.teams.nodes[0].id // empty')
if [ -z "$team_id" ]; then
  echo "::error::no Linear team with key '${TEAM_KEY}'" >&2
  exit 1
fi

label_ids='[]'
if [ -n "$LABELS" ]; then
  known=$(gql '
query Labels($team: String!) {
  issueLabels(filter: { team: { key: { eq: $team } } }, first: 250) { nodes { id name } }
}' "$(jq -nc --arg team "$TEAM_KEY" '{team:$team}')" | jq -c '.data.issueLabels.nodes')
  while IFS= read -r label; do
    [ -z "$label" ] && continue
    id=$(jq -r --arg n "$label" '.[] | select(.name == $n) | .id' <<<"$known" | head -1)
    if [ -z "$id" ]; then
      echo "::error::label '${label}' does not exist on team ${TEAM_KEY} — create it or drop it from the action inputs" >&2
      exit 1
    fi
    label_ids=$(jq -c --arg id "$id" '. + [$id]' <<<"$label_ids")
  done < <(tr ',' '\n' <<<"$LABELS" | sed 's/^ *//; s/ *$//')
fi

project_id=""
if [ -n "$PROJECT_NAME" ]; then
  project_id=$(gql '
query Project($name: String!) {
  projects(filter: { name: { eq: $name } }, first: 2) { nodes { id name } }
}' "$(jq -nc --arg name "$PROJECT_NAME" '{name:$name}')" | jq -r '.data.projects.nodes[0].id // empty')
  if [ -z "$project_id" ]; then
    echo "::error::no Linear project named '${PROJECT_NAME}'" >&2
    exit 1
  fi
fi

created=$(gql '
mutation Create($input: IssueCreateInput!) {
  issueCreate(input: $input) { success issue { id identifier url } }
}' "$(jq -nc \
  --arg teamId "$team_id" \
  --arg title "$TITLE" \
  --arg description "$description" \
  --argjson labelIds "$label_ids" \
  --arg projectId "$project_id" \
  '{input: ({teamId:$teamId, title:$title, description:$description, labelIds:$labelIds}
            + (if $projectId == "" then {} else {projectId:$projectId} end))}')")

if [ "$(jq -r '.data.issueCreate.success' <<<"$created")" != "true" ]; then
  echo "::error::Linear refused to create the alert issue for '${ALERT_KEY}'" >&2
  exit 1
fi

issue_ident=$(jq -r '.data.issueCreate.issue.identifier' <<<"$created")
issue_url=$(jq -r '.data.issueCreate.issue.url' <<<"$created")

echo "raised ${issue_ident} — ${issue_url}"
summary "## Health alert \`${ALERT_KEY}\`: RAISED"
summary ""
summary "[${issue_ident}](${issue_url}) — ${TITLE}"
emit action created
emit issue_identifier "$issue_ident"
emit issue_url "$issue_url"
