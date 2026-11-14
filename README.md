# 무료 iPhone 빌드 및 Windows 설치

이 경로에서는 Apple 유료 멤버십 결제를 진행하지 않습니다. Apple 개발자 포털의 유료 기기 등록도 필요하지 않습니다. Mac을 구매하지 않고 GitHub 표준 macOS runner에서 서명 없는 iPhone용 IPA를 빌드한 뒤, 자신의 Windows PC에서 AltStore Classic으로 서명·설치합니다.

## 현재 준비 상태

- `.github/workflows/ios-unsigned.yml`: 수동 실행 전용. 공개 저장소에서만 빌드하며 비공개 저장소에서는 작업을 건너뜁니다.
- `scripts/build-ios-unsigned.sh`: XcodeGen 프로젝트 생성, 실제 기기용 ARM64 앱 빌드, IPA 생성.
- `scripts/verify_ipa.py`: 패키지 구조, 기기용 플랫폼, 위치 권한 문구, 백그라운드 위치 설정, 실행 파일 및 서명 자료 미포함 확인.
- Apple 비밀번호·배포 인증서·서명 키를 클라우드에 입력할 필요가 없습니다.
- **첫 클라우드 빌드 성공:** [빌드 #1](https://github.com/Diagreen/rokid-location-relay/actions/runs/43556320834). Xcode 16.4에서 iPhone ARM64 컴파일, 테스트 4개, IPA 구조 검사를 통과했습니다.
- [IPA ZIP 다운로드](https://github.com/Diagreen/rokid-location-relay/actions/runs/43556320834/artifacts/14098871004) · GitHub 아티팩트 보존 기간 3일. 다운로드한 IPA는 AltStore에서 서명·설치해야 합니다.
- 실제 iPhone 설치 및 화면 잠금 상태 위치 전달은 아직 미검증입니다.

## 1. GitHub에 빌드 프로젝트 올리기

`Rokid_iOS_Free_Build` 묶음의 폴더 안에 있는 **모든 항목**을 저장소 루트에 올립니다. `.github` 디렉터리를 반드시 포함합니다. Windows 탐색기의 숨김 항목 표시가 필요할 수 있습니다.

1. 자신의 GitHub 계정에서 `rokid-location-relay` 같은 이름의 **공개(Public)** 저장소를 만듭니다. 공개 저장소의 표준 GitHub-hosted 실행 환경을 이용하는 구성입니다.
2. 제공된 빌드 프로젝트를 업로드합니다. 개인 정보나 기존의 전체 작업 폴더를 업로드하지 않습니다. 이 묶음에는 iOS 소스·빌드 설정·고지만 포함됩니다.
3. GitHub의 **Actions → Build iPhone IPA (unsigned, free account) → Run workflow → Run workflow**를 누릅니다. 저장소의 Actions 활성화 안내가 나오면 활성화합니다.
4. 빌드가 성공하면 해당 실행의 **Artifacts → RokidLocation-unsigned-IPA**를 다운로드합니다. 다운로드에는 GitHub 로그인이 필요할 수 있으며 아티팩트 보존 기간은 3일입니다.
5. ZIP을 풀어 `RokidLocation-unsigned.ipa`와 SHA-256 파일을 확인합니다. 실패한 빌드는 설치할 수 없으므로 로그를 먼저 확인합니다.

이 IPA는 서명 전 파일입니다. iPhone Safari에서 다운로드 링크만 누르면 바로 설치되는 형태가 아닙니다. 공개 저장소 표준 runner만 사용하도록 구성했으며, 유료 larger runner나 외부 유료 빌드 서비스를 요구하지 않습니다. 저장소 공개 전 소스 공개 범위를 확인합니다.

## 2. Windows에 AltStore Classic 설치

공식 안내: https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows

1. 위 공식 문서에 따라 Windows용 AltServer 및 필요한 Apple iTunes/iCloud 구성요소를 준비합니다. 기존 Apple Devices 또는 Microsoft Store 버전을 사용 중이라면 공식 문서의 호환성/대체 절차를 먼저 확인합니다. 기존 동기화 프로그램을 임의로 제거하지 않습니다.
2. iPhone을 USB 데이터 케이블로 연결하고 잠금을 풉니다. ‘이 컴퓨터를 신뢰’를 허용합니다.
3. AltServer 메뉴의 **Install AltStore → 자신의 iPhone**을 선택합니다.
4. Apple 계정 인증은 자신의 PC의 AltServer 화면에서 수행합니다. 대화나 GitHub Secrets에 Apple 비밀번호를 올리지 않습니다.
5. iPhone에서 필요에 따라 **설정 → 일반 → VPN 및 기기 관리 → 개발자 앱 신뢰**를 진행합니다.
6. iOS 16 이상에서는 **설정 → 개인정보 보호 및 보안 → 개발자 모드**를 켜고 안내에 따라 재시동/확인합니다.

## 3. IPA 서명·설치

1. 다운로드한 `RokidLocation-unsigned.ipa`를 iCloud Drive 등으로 iPhone의 파일 앱에 전달합니다.
2. Windows AltServer를 실행하고 iPhone과 PC를 연결하거나 통신 가능한 같은 네트워크에 둡니다.
3. iPhone의 **AltStore Classic → My Apps → ＋**에서 IPA를 선택해 설치합니다.
4. 설치 후 ‘Rokid 위치 연결’을 실행합니다. 서명/설치 오류가 발생하면 AltStore 오류 메시지를 확인합니다. 이 경로의 실제 호환성은 설치 시험으로 판정합니다.

무료 계정에서는 앱 서명이 **7일** 만료되므로 AltStore의 **Refresh All**을 사용해 만료 전에 갱신합니다. 갱신할 때 AltServer가 실행되는 Windows PC와 통신해야 합니다. AltServer는 주행 내비게이션 중계 서버가 아니므로, 갱신이 완료된 후 자전거를 탈 때 PC를 휴대할 필요는 없습니다.

## 4. 안경 연결 및 화면 잠금 시험

1. 안경에는 기존 `rokid-osm-voice-0.1.0-arm64-debug.apk`를 설치합니다. APK는 변경하지 않았습니다.
2. 안경과 iPhone을 같은 Wi-Fi 또는 개인용 핫스팟으로 연결합니다.
3. iPhone 앱에 안경의 IP(`http://…:8765`)와 현재 32자리 연결 토큰을 입력합니다.
4. 위치 전송을 시작하고 **정확한 위치**, **로컬 네트워크** 권한을 허용합니다. 백그라운드 위치 권한 버튼도 확인합니다.
5. 처음에는 실외에서 iPhone 화면을 켠 채 위치 전달과 도보 경로를 확인합니다.
6. iPhone 화면을 잠그고 최소 10분간 위치 갱신이 지속되는지 확인합니다. 이후 자전거 시험을 진행합니다. 네이티브 백그라운드 위치 설정을 유지하지만 실기기 지속 동작을 보증한 상태는 아닙니다.
7. 위치가 오래되거나 정확하지 않으면 안경이 안내를 일시 중지합니다. iPhone 앱을 사용자가 강제로 종료하면 위치 전송도 중단됩니다.

## 출처

- GitHub runner 및 무료 공개 저장소 실행: https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job
- AltStore Windows 설치: https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows
- 무료 계정의 7일 만료와 갱신: https://faq.altstore.io/altstore-classic/your-altstore
