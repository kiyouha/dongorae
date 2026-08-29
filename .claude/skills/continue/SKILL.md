---
name: continue
description: 이전 작업을 최소 컨텍스트로 이어서 시작한다. .ai/CURRENT.md와 저장소/스택 상태를 읽고 Next action부터 계속한다. 새 세션 시작이나 컨텍스트 손실 후 "이어서", "계속", "어디까지 했지" 요청 시 사용.
---

# Continue — 이어서 작업

목표: 이전 작업을 **최소 컨텍스트**로 복구해서 계속한다. 전체 저장소를 다시 읽거나 지난 대화를 재생하지 않는다.

## 순서
1. **`.ai/CURRENT.md` 를 읽는다.** 지금 상태의 기준. (Goal / Status / Done / Known issues / Next action / Run)
2. **저장소·런타임 상태 확인:**
   - git 저장소면: `git status --short` + `git diff --stat`.
   - 이 프로젝트는 docker compose로 돈다 → `docker compose ps` 로 db/app/nginx/scheduler/pgadmin 기동 여부 확인. 검증이 필요하면 `docker compose up -d`.
3. **Next action / Active files 에 관련된 파일만** 읽는다. 큰 파일은 먼저 검색(grep)하고 필요한 범위만. 무관한 모듈은 건드리지 않는다.
4. Goal과 **Next action 한 줄**을 다시 정리해 말한 뒤, 그 지점부터 계속한다.
5. Next action이 애매하거나 코드와 어긋나 보이면, 큰 작업 전에 **질문 하나** 먼저.

## 제약 (CLAUDE.md)
- 가장 작은 올바른 변경. 무관한 코드 리팩터 금지. 기존 API/스키마/동작 보존.
- 넓은 테스트 전에 타겟 검증 먼저. 큰 로그는 필터링해서 확인.

## 참고
- 상세 아키텍처: `.ai/ARCHITECTURE.md` / 운영: `DOCKER.md` / 거래내역 넣는 법: `data/inbox/README.md`.
- 멈출 때는 `/handoff` 로 `.ai/CURRENT.md` 를 갱신한다.
