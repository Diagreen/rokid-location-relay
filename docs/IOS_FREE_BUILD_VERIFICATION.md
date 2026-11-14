# 무료 iOS 빌드 검증 결과 — 2026-11-14

- 저장소: https://github.com/Diagreen/rokid-location-relay
- 빌드: https://github.com/Diagreen/rokid-location-relay/actions/runs/43556320834
- 코드 커밋: `3def2be441e00e11693d880a7cc7fe4d5e1bd4aa`
- macos-15 표준 runner, Xcode16.4, iPhoneOS18.5 SDK, ARM64/iOS16 이상.
- 테스트 4개, Swift 컴파일, 실제 기기용 IPA 생성과 구조 검사 통과.
- 다운로드한 ZIP의 SHA-256 및 IPA 동봉 체크섬 일치 확인.
- IPA SHA-256: `d0f77d323d39fe12e9ac065cee65e39008357cc8de70d6aa2448f227b698c374`
- IPA는 서명 전 파일. AltServer/AltStore Classic에서 사용자 무료 계정으로 서명 후 설치.
- 실제 iPhone 설치·7일 갱신·안경 연동·잠금 상태 위치 전달은 미검증.
