#!/usr/bin/env bash
# Push the release tags a merge implies, so nobody has to remember to
# (plans 2608-01 Q4 and 2608-05 Q1, FOR-517).
#
# `@forestrie/canopy-e2e-kit` sat at npm 0.6.1 while the repo reached 0.9.1 —
# three unpublished versions spanning exactly the window in which the platform
# contract changed, so every consumer of the published kit, the T3 qualification
# harness included, silently exercised the old contract. The publish workflows
# were fine. They are tag-triggered, and the tags were the step a human had to
# remember. In one 24h period five tags were pushed by hand, remembered only
# because the sessions doing the bumps happened to be paying attention.
#
# Two shapes, one mechanism:
#
#   service   a merge to main cuts the next patch release tag (vX.Y.Z+1). Tags
#             are cheap CANDIDATES — qualification is the quality gate — so
#             nothing can silently run ahead of its published tags again.
#             Suppressed by a marker in the merge commit message.
#
#   packages  a merge that changes a declared package's `package.json` version
#             pushes `<prefix>-v<version>`. Bump == publish intent: no marker,
#             no second decision point, npm can never trail the repo again.
#
# Both are idempotent — an existing tag is a skip, never an error — so a re-run
# of the same merge does nothing.
set -euo pipefail

: "${GH_TOKEN:?GH_TOKEN is required — and read the note about GITHUB_TOKEN below}"
: "${MODE:?MODE must be 'service' or 'packages'}"
: "${GITHUB_REPOSITORY:?}"
: "${GITHUB_SHA:?}"

TAG_PREFIX="${TAG_PREFIX:-v}"
SKIP_MARKER="${SKIP_MARKER:-[no-release]}"
CONFIG="${CONFIG:-.github/auto-tag-packages.json}"

summary() { printf '%s\n' "$*" >>"${GITHUB_STEP_SUMMARY:-/dev/stdout}"; }
created=()
skipped=()

# Every tag already on the remote whose name starts with $1. `matching-refs`
# answers with an empty array rather than 404 when nothing matches, so an
# unreleased repo is not a special case.
existing_tags() {
  gh api --paginate "/repos/${GITHUB_REPOSITORY}/git/matching-refs/tags/$1" \
    --jq '.[].ref | sub("^refs/tags/"; "")'
}

# Idempotent create. A tag that already exists is a skip: re-running the same
# merge must be a no-op, not a failure.
push_tag() {
  local tag="$1" sha="$2"
  if gh api "/repos/${GITHUB_REPOSITORY}/git/ref/tags/${tag}" >/dev/null 2>&1; then
    echo "tag ${tag} already exists — nothing to do"
    skipped+=("${tag} (already exists)")
    return 0
  fi
  gh api --method POST "/repos/${GITHUB_REPOSITORY}/git/refs" \
    -f "ref=refs/tags/${tag}" -f "sha=${sha}" >/dev/null
  echo "pushed ${tag} -> ${sha}"
  created+=("${tag}")
}

case "$MODE" in
service)
  head_msg=$(gh api "/repos/${GITHUB_REPOSITORY}/commits/${GITHUB_SHA}" --jq '.commit.message')
  if [[ "$head_msg" == *"$SKIP_MARKER"* ]]; then
    echo "skip marker '${SKIP_MARKER}' present in the merge commit — no release tag"
    summary "## auto-tag: suppressed"
    summary ""
    summary "The merge commit carries \`${SKIP_MARKER}\`, so no release tag was cut."
    exit 0
  fi

  # Already tagged (a hand-cut tag, or a re-run) — nothing to do. Only release
  # tags count: an unrelated tag family sharing the prefix must not suppress a
  # real release.
  on_head=$(gh api --paginate "/repos/${GITHUB_REPOSITORY}/git/matching-refs/tags/${TAG_PREFIX}" \
    --jq ".[] | select(.object.sha == \"${GITHUB_SHA}\") | .ref | sub(\"^refs/tags/\"; \"\")" |
    grep -E "^${TAG_PREFIX}[0-9]+\.[0-9]+\.[0-9]+\$" | head -1 || true)
  if [ -n "$on_head" ]; then
    echo "${GITHUB_SHA} already carries ${on_head} — nothing to do"
    summary "## auto-tag: already tagged"
    summary ""
    summary "\`${GITHUB_SHA}\` already carries \`${on_head}\`."
    exit 0
  fi

  # Highest existing vX.Y.Z. Prereleases and other tag families are excluded by
  # the anchored pattern: bumping off `v1.0.0-rc.1` would produce nonsense.
  latest=$(existing_tags "$TAG_PREFIX" |
    grep -E "^${TAG_PREFIX}[0-9]+\.[0-9]+\.[0-9]+\$" |
    sort -V | tail -1 || true)

  if [ -z "$latest" ]; then
    next="${TAG_PREFIX}0.0.1"
    echo "no ${TAG_PREFIX}X.Y.Z tag exists yet — starting at ${next}"
  else
    core="${latest#"$TAG_PREFIX"}"
    major="${core%%.*}"
    rest="${core#*.}"
    minor="${rest%%.*}"
    patch="${rest#*.}"
    next="${TAG_PREFIX}${major}.${minor}.$((patch + 1))"
  fi

  push_tag "$next" "$GITHUB_SHA"
  ;;

packages)
  if [ ! -f "$CONFIG" ]; then
    echo "::error::${CONFIG} not found — packages mode needs the declared package list (see the action README)" >&2
    exit 1
  fi
  if ! jq -e '.packages | type == "array" and length > 0' "$CONFIG" >/dev/null; then
    echo "::error::${CONFIG} declares no packages — an empty list means every bump ships unpublished, which is the failure this exists to prevent" >&2
    exit 1
  fi

  while IFS=$'\t' read -r dir prefix; do
    manifest="${dir%/}/package.json"
    # A declared package that is not there is config rot, and config rot in
    # this action is silently unpublished releases. Fail, do not skip.
    if [ ! -f "$manifest" ]; then
      echo "::error::${CONFIG} declares '${dir}' but ${manifest} does not exist" >&2
      exit 1
    fi
    version=$(jq -r '.version // empty' "$manifest")
    if [ -z "$version" ]; then
      echo "::error::${manifest} has no version field" >&2
      exit 1
    fi
    push_tag "${prefix}-v${version}" "$GITHUB_SHA"
  done < <(jq -r '.packages[] | [.dir, .tag_prefix] | @tsv' "$CONFIG")
  ;;

*)
  echo "::error::mode must be 'service' or 'packages' (got '${MODE}')" >&2
  exit 1
  ;;
esac

if [ ${#created[@]} -gt 0 ]; then
  summary "## auto-tag: pushed ${#created[@]} tag(s)"
  summary ""
  for t in "${created[@]}"; do summary "- \`${t}\` → \`${GITHUB_SHA}\`"; done
  summary ""
  # Worth restating on every run that pushes a tag, because the failure is
  # invisible: a tag created by GITHUB_TOKEN triggers no workflow at all.
  summary "These tags must trigger the tag-triggered release/publish workflows."
  summary "If nothing ran, the token was \`GITHUB_TOKEN\` — see the action README."
else
  summary "## auto-tag: nothing to push"
  summary ""
  for t in "${skipped[@]+"${skipped[@]}"}"; do summary "- ${t}"; done
fi

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  printf 'tags=%s\n' "$(printf '%s\n' "${created[@]+"${created[@]}"}" | paste -sd, -)" >>"$GITHUB_OUTPUT"
fi
