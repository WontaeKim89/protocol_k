#!/bin/sh
# 이슈 본문을 템플릿(feature-task.yml form)에 맞게 wrap.
# 사용법:
#   wrap-issue-body.sh <type> [notes_file] < body_file
#   echo "본문" | wrap-issue-body.sh Feature
#   wrap-issue-body.sh Chore notes.md < body.md
#
# 인자:
#   <type>        Feature | Fix | Hotfix | Chore (대소문자 구분, 템플릿과 일치해야 함)
#   [notes_file]  '기타 참고 사항' 본문 파일 경로 (옵션, 미지정 시 _No response_)
#
# 입력:
#   stdin         '상세 요구사항 및 개발 내용' 본문
#
# 출력 (stdout):
#   템플릿 헤더와 함께 wrap 된 이슈 본문 (gh issue create --body 에 그대로 사용 가능)
#
# Exit code:
#   0   성공
#   1   인자 오류 또는 본문 비어있음

set -e

usage() {
  echo "Usage: $0 <Feature|Fix|Hotfix|Chore> [notes_file] < body_file" >&2
  echo "  body_file 은 stdin 으로 전달한다." >&2
}

TYPE="${1:-}"
NOTES_FILE="${2:-}"

if [ -z "$TYPE" ]; then
  echo "FAIL: 브랜치 유형이 지정되지 않았습니다." >&2
  usage
  exit 1
fi

case "$TYPE" in
  Feature|Fix|Hotfix|Chore)
    ;;
  *)
    echo "FAIL: 잘못된 브랜치 유형 '$TYPE'. (허용: Feature, Fix, Hotfix, Chore)" >&2
    exit 1
    ;;
esac

# stdin 에서 본문 읽기
BODY=$(cat)
if [ -z "$BODY" ]; then
  echo "FAIL: 본문(stdin)이 비어 있습니다." >&2
  exit 1
fi

# notes 결정
if [ -n "$NOTES_FILE" ]; then
  if [ ! -f "$NOTES_FILE" ]; then
    echo "FAIL: notes 파일을 찾을 수 없습니다: $NOTES_FILE" >&2
    exit 1
  fi
  NOTES=$(cat "$NOTES_FILE")
  [ -z "$NOTES" ] && NOTES="_No response_"
else
  NOTES="_No response_"
fi

# 템플릿 wrapping (헤더의 이모티콘/공백/줄바꿈은 GitHub Actions awk 파서가 의존하므로 변경 금지)
cat <<EOF
### 🌿 브랜치 유형

$TYPE

### 📝 상세 요구사항 및 개발 내용

$BODY

### 💬 기타 참고 사항

$NOTES
EOF
