# Slack Incoming Webhook 셋업 가이드

GitHub 이벤트(commit · PR · 이슈 · 리뷰 · 코멘트 · 릴리즈)를 커스텀 Block Kit 카드로 Slack에 보내기 위한 1회 셋업 가이드.

---

## 1. Slack 공식 GitHub 앱 해제 (기존 구독 정리)

기존에 `/github subscribe` 로 등록한 구독을 정리한다. 채널·DM 양쪽 모두에서:

```
/github unsubscribe WontaeKim89/protocol_k
```

선택: 워크스페이스 admin이면 https://aichampion.slack.com/apps/manage 에서 GitHub 앱 자체를 제거해도 됨.

---

## 2. Slack App 생성 (Incoming Webhook 전용)

1. https://api.slack.com/apps 접속 → **Create New App**
2. **From scratch** 선택
3. App Name: `Protocol K Notifier` (자유)
4. Workspace: **AI Champion**
5. 생성 후 좌측 메뉴 → **Incoming Webhooks** → 활성화 (`Activate Incoming Webhooks` 토글 ON)
6. 페이지 하단 **Add New Webhook to Workspace** 클릭
7. 채널 선택: `#protocol_k_github-noti`
8. 허용 → Webhook URL 발급 (`https://hooks.slack.com/services/T.../B.../...`)

---

## 3. GitHub Repository Secret 등록

발급된 URL을 GitHub 레포 Secret으로 저장한다 (절대 코드에 박지 말 것).

방법 A — `gh` CLI (권장):
```bash
echo "https://hooks.slack.com/services/T.../B.../..." | gh secret set SLACK_WEBHOOK_URL --repo WontaeKim89/protocol_k
```

방법 B — GitHub 웹 UI:
1. https://github.com/WontaeKim89/protocol_k/settings/secrets/actions
2. **New repository secret**
3. Name: `SLACK_WEBHOOK_URL`
4. Value: (발급된 URL 붙여넣기)

---

## 4. 검증

워크플로 `.github/workflows/slack-notify.yml` 가 이미 secret을 참조하도록 구성되어 있다.

테스트:
```bash
git commit --allow-empty -m "chore: test custom slack notification"
git push origin main
```

`#protocol_k_github-noti` 채널에 Protocol K Notifier 가 보낸 풍부한 카드 도착 확인.

---

## 5. 트러블슈팅

- **알림 안 옴**: GitHub Actions 탭에서 `Slack Notifications` 워크플로 실행 결과 확인. 빨간 X 면 클릭해서 stderr 확인.
- **Webhook URL 유효성**: Slack App 페이지에서 Test 버튼 또는 curl 로 직접 호출.
  ```bash
  curl -X POST -H 'Content-Type: application/json' \
    --data '{"text":"hello from curl"}' \
    "$SLACK_WEBHOOK_URL"
  ```
- **URL 노출 사고**: 즉시 Slack App 페이지에서 webhook 삭제 후 재발급 + GitHub Secret 갱신.
