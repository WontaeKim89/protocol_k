# GitHub Project + Sprint 자동 배정 셋업

`assign-sprint.sh` 가 이슈 생성 직후 현재 Sprint 에 자동 배정하려면, 최초 1회 다음 셋업이 필요하다.

---

## 1. GitHub Project 생성

1. https://github.com/users/WontaeKim89/projects 또는 GitHub `WontaeKim89` 계정 → Projects → New project
2. Template: **Board** 또는 **Iteration** 권장
3. 이름: `Protocol K` (자유)
4. 이 레포(`protocol_k`)를 Project에 연결

---

## 2. Iteration(Sprint) 필드 추가

1. Project 보드에서 `+` 버튼 → New field → **Iteration**
2. Field 이름: `Sprint` (또는 원하는 이름)
3. Duration: **14 days** (Protocol K 표준)
4. Start date: 첫 Sprint 시작일 (예: `2026-05-19`)
5. 향후 Sprint들을 자동 생성 (8~10개 권장)

---

## 3. Project ID / Field ID 조회

`gh` CLI 또는 GraphQL Explorer 로 ID를 얻는다.

```bash
# Project 목록 (본인 계정)
gh project list --owner WontaeKim89

# 특정 Project의 필드 목록
gh project field-list <project-number> --owner WontaeKim89 --format json | jq '.fields[] | {name, id}'
```

또는 GraphQL:

```graphql
query {
  user(login: "WontaeKim89") {
    projectV2(number: <PROJECT_NUMBER>) {
      id
      fields(first: 20) {
        nodes {
          ... on ProjectV2IterationField {
            id
            name
            configuration {
              iterations { id title startDate duration }
            }
          }
        }
      }
    }
  }
}
```

수집할 값:
- `PROJECT_ID` (예: `PVT_kwDO...`)
- `SPRINT_FIELD_ID` (예: `PVTIF_lADO...`)
- 각 Iteration 의 `id`, `title`, `startDate` (스크립트 Sprint 표 작성용)

---

## 4. 스크립트에 값 반영

`.claude/skills/create-issue/scripts/assign-sprint.sh` 상단을 수정:

```bash
PROJECT_ID="${PROTOCOL_K_PROJECT_ID:-PVT_여기에_프로젝트_ID}"
SPRINT_FIELD_ID="${PROTOCOL_K_SPRINT_FIELD_ID:-PVTIF_여기에_필드_ID}"

SPRINT_TABLE='Sprint 1|<iteration-id>|2026-05-19|2026-06-01
Sprint 2|<iteration-id>|2026-06-02|2026-06-15
Sprint 3|<iteration-id>|2026-06-16|2026-06-29
...'
```

**보안 권장**: ID를 스크립트에 직접 박지 않고 환경변수로 노출.

```bash
# ~/.zshrc 또는 ~/.bashrc 에 추가
export PROTOCOL_K_PROJECT_ID="PVT_..."
export PROTOCOL_K_SPRINT_FIELD_ID="PVTIF_..."
```

스크립트는 env 우선, 없으면 placeholder fallback (현재 `PVT_REPLACE_ME`).

---

## 5. 권한 확인

`gh` CLI 인증이 다음 스코프를 포함해야 함:

- `repo`
- `project` (Project v2 mutation 필요)

```bash
gh auth status
# Token scopes에 'project' 가 포함되어 있는지 확인
# 없으면:
gh auth refresh -h github.com -s project
```

---

## 6. 검증

이슈 하나 만들어보고 Sprint 자동 배정 확인:

```bash
# 임의 이슈 생성 (테스트)
URL=$(gh issue create --title "Test sprint assignment" --body "test" --assignee @me | tail -1)

# Sprint 배정 실행
.claude/skills/create-issue/scripts/assign-sprint.sh "$URL"
```

성공 시 stdout 에 `ASSIGNED_SPRINT: Sprint X` 한 줄 출력. 실패 시 stderr 메시지 + exit code 확인:

| Exit | 의미 |
|---|---|
| 0 | 성공 |
| 1 | 인자/의존성 오류 |
| 2 | 오늘 날짜에 해당하는 Sprint 없음 (표 갱신 필요) |
| 3 | issue 조회 또는 project mutation 실패 (권한·네트워크 점검) |

---

## 7. Sprint 표 만료 관리

스크립트의 `SPRINT_TABLE` 은 Sprint 8~9개를 미리 박아두는 방식. 분기마다 갱신이 필요할 수 있다.

- exit 2 발생 시 = 표 갱신 시점
- 표 갱신은 PR로 진행 (이 셋업 가이드와 동일 위치)
