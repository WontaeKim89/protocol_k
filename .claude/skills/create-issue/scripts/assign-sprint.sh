#!/bin/sh
# 이슈를 GitHub Project 의 현재 Sprint 에 자동 배정한다.
# 사용법:
#   assign-sprint.sh <issue-url>
#
# 절차:
#   1) 오늘 날짜 기준 현재 Sprint 결정 (스크립트 내부 표)
#   2) issue node ID 조회 → addProjectV2ItemById 로 즉시 추가 (idempotent)
#   3) Sprint 필드 mutation
#
# 출력 (stdout):
#   ASSIGNED_SPRINT: <Sprint 이름>
#   ASSIGNED_RESULT: {iteration_id, item_id, sprint_name}  (jq -c)
#
# Exit code:
#   0   배정 성공
#   1   인자/의존성 오류
#   2   오늘 날짜에 해당하는 Sprint 가 없음 (스크립트 표 갱신 필요)
#   3   issue 정보 조회 또는 project add/update 실패

set -e

# 프로젝트 고정값 (Protocol K 전용)
# 최초 셋업 시 GitHub Project 생성 후 ID·Field ID·Sprint 표를 채워야 한다.
# 자세한 가이드: docs/setup/sprint-setup.md
PROJECT_ID="${PROTOCOL_K_PROJECT_ID:-PVT_REPLACE_ME}"
SPRINT_FIELD_ID="${PROTOCOL_K_SPRINT_FIELD_ID:-PVTIF_REPLACE_ME}"

# Sprint 표 (이름|ID|시작일|종료일, 종료일 inclusive, duration 14일)
# 비어 있으면 스크립트가 exit 2 로 종료된다. 셋업 후 직접 채울 것.
SPRINT_TABLE=''

ISSUE_URL="${1:-}"
if [ -z "$ISSUE_URL" ]; then
  echo "Usage: $0 <issue-url>" >&2
  exit 1
fi

for cmd in gh jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "FAIL: $cmd 가 필요합니다." >&2
    exit 1
  fi
done

# 1) 현재 Sprint 결정 (ISO-8601 문자열 비교)
TODAY=$(date +%Y-%m-%d)
CURRENT_LINE=$(printf '%s\n' "$SPRINT_TABLE" | awk -F'|' -v today="$TODAY" '
  today >= $3 && today <= $4 { print; exit }
')

if [ -z "$CURRENT_LINE" ]; then
  echo "FAIL: 오늘($TODAY)에 해당하는 Sprint 가 표에 없습니다." >&2
  echo "  -> .claude/skills/create-issue/scripts/assign-sprint.sh 의 SPRINT_TABLE 갱신이 필요합니다." >&2
  exit 2
fi

# subshell 3회 → 1회로 정리
IFS='|' read -r SPRINT_NAME SPRINT_ID _ _ <<EOF
$CURRENT_LINE
EOF

# 2) issue node ID 조회 (gh issue view 가 가장 가벼움)
ISSUE_NUMBER=$(echo "$ISSUE_URL" | awk -F/ '{print $NF}')
if ! CONTENT_ID=$(gh issue view "$ISSUE_NUMBER" --json id -q .id 2>/dev/null) || [ -z "$CONTENT_ID" ]; then
  echo "FAIL: 이슈 node ID 조회 실패: $ISSUE_URL" >&2
  exit 3
fi

# addProjectV2ItemById 는 idempotent (이미 있으면 기존 item 반환) → 자동 추가 race 회피
ADD_MUTATION='mutation($projectId: ID!, $contentId: ID!) {
  addProjectV2ItemById(input: {projectId: $projectId, contentId: $contentId}) {
    item { id }
  }
}'

ADD_RESP=$(gh api graphql \
  -f query="$ADD_MUTATION" \
  -f projectId="$PROJECT_ID" \
  -f contentId="$CONTENT_ID" 2>/dev/null) || ADD_RESP=""

ITEM_ID=$(echo "$ADD_RESP" | jq -r '.data.addProjectV2ItemById.item.id // empty')
if [ -z "$ITEM_ID" ]; then
  echo "FAIL: 프로젝트에 이슈 추가 실패. 프로젝트 권한을 확인하세요." >&2
  exit 3
fi

# 3) Sprint 필드 mutation
UPDATE_MUTATION='mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $iterationId: String!) {
  updateProjectV2ItemFieldValue(input: {
    projectId: $projectId
    itemId: $itemId
    fieldId: $fieldId
    value: { iterationId: $iterationId }
  }) {
    projectV2Item { id }
  }
}'

if ! gh api graphql \
  -f query="$UPDATE_MUTATION" \
  -f projectId="$PROJECT_ID" \
  -f itemId="$ITEM_ID" \
  -f fieldId="$SPRINT_FIELD_ID" \
  -f iterationId="$SPRINT_ID" >/dev/null 2>&1; then
  echo "FAIL: Sprint 필드 mutation 에 실패했습니다." >&2
  exit 3
fi

echo "ASSIGNED_SPRINT: $SPRINT_NAME"
echo "ASSIGNED_RESULT: $(jq -nc \
  --arg sprint "$SPRINT_NAME" \
  --arg iteration "$SPRINT_ID" \
  --arg item "$ITEM_ID" \
  '{sprint_name: $sprint, iteration_id: $iteration, item_id: $item}')"
exit 0
