#!/usr/bin/env bash
# Offline behaviour tests for auto-tag (plans 2608-01 Q4 / 2608-05 Q1 verification).
#
#   bash actions/auto-tag/selftest.sh
#
# `gh` is replaced by a stub that serves canned refs and RECORDS every ref
# creation, so the assertions are about which tags would be pushed — the actual
# effect — rather than about the script surviving to the end. Testing this
# against a real repository is not an option: the effect under test is an
# irreversible tag push.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fails=0

mkdir -p "$WORK/bin"
cat >"$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
# Minimal `gh api` stub. Faithful where it matters: matching-refs really runs
# the caller's --jq filter over a real JSON array, so a filter bug still shows.
set -euo pipefail
method=GET url="" filter="" ref="" sha=""
while [ $# -gt 0 ]; do
  case "$1" in
    api|--paginate) ;;
    --method) method="$2"; shift ;;
    --jq) filter="$2"; shift ;;
    -f) case "$2" in ref=*) ref="${2#ref=}" ;; sha=*) sha="${2#sha=}" ;; esac; shift ;;
    *) [ -z "$url" ] && url="$1" ;;
  esac
  shift
done

if [ "$method" = POST ]; then
  printf '%s %s\n' "$ref" "$sha" >>"$STUB_POST_LOG"
  echo '{}'
  exit 0
fi

case "$url" in
  */commits/*)
    printf '%s\n' "${STUB_COMMIT_MSG:-chore: a merge}"
    ;;
  */git/matching-refs/tags/*)
    prefix="${url##*/git/matching-refs/tags/}"
    {
      printf '['
      first=1
      for t in ${STUB_TAGS:-}; do
        case "$t" in "$prefix"*) ;; *) continue ;; esac
        sha=othersha0000000000000000000000000000000
        for h in ${STUB_TAGS_ON_HEAD:-}; do [ "$h" = "$t" ] && sha="$GITHUB_SHA"; done
        [ $first -eq 1 ] || printf ','
        first=0
        printf '{"ref":"refs/tags/%s","object":{"sha":"%s"}}' "$t" "$sha"
      done
      printf ']'
    } | jq -r "${filter:-.}"
    ;;
  */git/ref/tags/*)
    want="${url##*/git/ref/tags/}"
    for t in ${STUB_TAGS:-}; do
      if [ "$t" = "$want" ]; then echo '{}'; exit 0; fi
    done
    echo "gh: Not Found (HTTP 404)" >&2
    exit 1
    ;;
  *)
    echo "stub: unexpected url $url" >&2
    exit 1
    ;;
esac
STUB
chmod +x "$WORK/bin/gh"

export PATH="$WORK/bin:$PATH"
export GH_TOKEN=stub-token
export GITHUB_REPOSITORY=forestrie/canopy
export GITHUB_SHA=1111111111111111111111111111111111111111

run() { # run <VAR=VAL>... ; leaves pushed tags in $PUSHED
  local log
  log="$(mktemp)"
  STUB_POST_LOG="$log" GITHUB_STEP_SUMMARY=/dev/null env "$@" \
    bash "$HERE/auto-tag.sh" >/dev/null 2>&1 || return $?
  PUSHED="$(cut -d' ' -f1 "$log" | paste -sd, - || true)"
}

check() { # check <label> <expected> <actual>
  if [ "$2" = "$3" ]; then echo "ok   $1"; else
    echo "FAIL $1: expected '$2', got '$3'"
    fails=$((fails + 1))
  fi
}

echo "--- service mode"

run MODE=service STUB_TAGS='v0.1.23 v0.1.24 v0.1.25'
check "patch bump off the highest tag" "refs/tags/v0.1.26" "$PUSHED"

run MODE=service STUB_TAGS='v0.1.9 v0.1.10'
check "version sort is numeric, not lexical" "refs/tags/v0.1.11" "$PUSHED"

run MODE=service STUB_TAGS=''
check "an untagged repo starts at v0.0.1" "refs/tags/v0.0.1" "$PUSHED"

run MODE=service STUB_TAGS='v0.1.25 v1.0.0-rc.1 v-legacy'
check "prereleases and stray tag families are ignored" "refs/tags/v0.1.26" "$PUSHED"

run MODE=service STUB_TAGS='v0.1.25' STUB_TAGS_ON_HEAD='v0.1.25'
check "a commit already tagged is a no-op" "" "$PUSHED"

run MODE=service STUB_TAGS='v0.1.25' STUB_COMMIT_MSG='docs: tweak [no-release]'
check "the skip marker suppresses the tag" "" "$PUSHED"

run MODE=service STUB_TAGS='v0.1.25' SKIP_MARKER='[skip release]' \
  STUB_COMMIT_MSG='docs: tweak [skip release]'
check "the skip marker is configurable" "" "$PUSHED"

echo "--- packages mode"

cd "$WORK"
mkdir -p packages/kit packages/encoding .github
echo '{"version":"0.9.2"}' >packages/kit/package.json
echo '{"version":"1.2.0"}' >packages/encoding/package.json
cat >.github/auto-tag-packages.json <<'JSON'
{"packages":[
  {"dir":"packages/kit","tag_prefix":"canopy-e2e-kit"},
  {"dir":"packages/encoding","tag_prefix":"encoding"}
]}
JSON

run MODE=packages STUB_TAGS=''
check "two bumps in one merge push two tags" \
  "refs/tags/canopy-e2e-kit-v0.9.2,refs/tags/encoding-v1.2.0" "$PUSHED"

run MODE=packages STUB_TAGS='canopy-e2e-kit-v0.9.2'
check "an already-published version is skipped, the other still ships" \
  "refs/tags/encoding-v1.2.0" "$PUSHED"

run MODE=packages STUB_TAGS='canopy-e2e-kit-v0.9.2 encoding-v1.2.0'
check "re-running the same merge is a complete no-op" "" "$PUSHED"

echo "--- misconfiguration is loud"

expect_failure() { # expect_failure <label> <VAR=VAL>...
  local label="$1"
  shift
  if run "$@"; then
    echo "FAIL $label was tolerated"
    fails=$((fails + 1))
  else
    echo "ok   $label rejected"
  fi
}

expect_failure "unknown mode" MODE=amber
expect_failure "missing package list" MODE=packages CONFIG=.github/nope.json

echo '{"packages":[]}' >.github/empty.json
expect_failure "empty package list" MODE=packages CONFIG=.github/empty.json

echo '{"packages":[{"dir":"packages/gone","tag_prefix":"gone"}]}' >.github/gone.json
expect_failure "declared package with no directory" MODE=packages CONFIG=.github/gone.json

echo '{"version":null}' >packages/kit/package.json
echo '{"packages":[{"dir":"packages/kit","tag_prefix":"kit"}]}' >.github/noversion.json
expect_failure "package.json with no version" MODE=packages CONFIG=.github/noversion.json

if [ "$fails" -eq 0 ]; then
  printf '\nALL AUTO-TAG ASSERTIONS PASSED\n'
else
  printf '\n%d AUTO-TAG ASSERTION(S) FAILED\n' "$fails"
  exit 1
fi
