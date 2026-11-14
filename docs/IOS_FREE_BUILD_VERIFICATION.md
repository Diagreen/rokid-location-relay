# 무료 빌드 구성 검증 — 2026-11-14

## 확인한 항목
- workflow YAML 및 XcodeGen project YAML 파싱 성공.
- 수동 실행(workflow_dispatch), 공개 저장소만 실행, macos-15 표준 runner, 20분 제한, contents:read 권한, 3일 아티팩트 보존 설정 확인.
- build-ios-unsigned.sh: bash -n 구문 검사 통과.
- IPA 검사기 회귀 테스트 4개 통과: 정상 기기용 구조, 시뮬레이터 거부, 백그라운드 위치 누락 거부, 예상하지 않은 프로비저닝 자료 거부.
- IPA 테스트는 합성 패키지를 사용하며 실제 Swift 컴파일이나 실제 설치를 검증하지 않음.

## 다음 검증
- GitHub 계정 연결 및 공개 저장소 업로드 후 첫 macOS 빌드 실행.
- Xcode Swift 컴파일 및 실제 기기용 IPA 생성/검사 성공 확인.
- Windows AltStore Classic의 무료 계정 서명·iPhone 설치 및 7일 갱신 시험.
- iPhone 잠금 상태에서 안경으로 위치 전달 지속 시험.

GitHub 인증이 확인되지 않았으므로 현재 빌드 실행 주소나 IPA 다운로드 주소는 발급되지 않았다. 무료 빌드 구성 완료와 클라우드 빌드 성공은 구분한다.
