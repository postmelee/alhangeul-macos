# Task M020 #341 Stage 2 완료보고서

## 서명·universal·CI/package 검증 경로 통합

## 통합

universal checker가 importer bundle의 위치/실행 파일/버전/식별자/UTI/schema/factory를 검사하고 네 번째 실행 파일의 두 slice를 요구한다. release source version 검사·내부 우선 서명·signing preflight에 importer를 추가했다. package와 PR CI에는 실제 CFPlugIn 직접 검사를 연결했다. 공개 Developer ID 서명/공증은 실행하지 않았다.

## 검증

- source/built bundle 계약 checker와 3개 fixture suite PASS: UTI/role/factory/version/package/schema drift 및 실행 파일 누락 거부.
- 최종 Release 앱 universal 검사 PASS: HostApp/Preview/Thumbnail/Spotlight 4개 실행 파일.
- 실제 embedded importer 호출 9개 사례 PASS: HWP/HWPX 본문, missing/invalid/empty/directory/symlink/FIFO/32 MiB 초과 파일의 이전 본문 제거.
- 변경 shell 구문, workflow YAML, git diff 형식 PASS.

## 도구 제한

시스템 MetadataSchema.xsd + xmllint는 유효 UTI 문자열을 regex 오류로 거부했다. 같은 명령이 Apple 기본 Mail.mdimporter의 com.apple.mail.emlx도 거부하는 음성 대조를 확보했다. 이를 XSD 통과로 기록하지 않는다. 자체 XML/UTI/속성 계약 검사는 통과했고 실제 등록된 mdimport/색인 수용은 #342 작업에서 확인한다.

## 다음 단계

Debug/Release 앱, 실제 패키지와 loader dependency/최소 OS 산출물을 최종 확인한다. 설치/등록 상태는 아직 변경하지 않았다.
