# 글꼴 검사 테스트 자산

이 폴더의 TTF·OTF·TTC는 본 저장소에서 테스트를 위해 직접 만든 사각형 윤곽 3개(`.notdef`, `A`, `가`)만 포함한다. 타사 글꼴·사용자 설치 자산을 복사하지 않았다. 저장소와 동일한 라이선스를 적용한다. 실제 한글 글꼴 모양·품질·renderer 호환성을 검증하는 자산이 아니다.

`generate.py`가 생성 원본이다. 재생성에는 Python과 `fontTools==4.59.1`이 필요하지만 XCTest 실행은 커밋된 작은 바이너리를 사용하므로 Python·네트워크·설치 글꼴에 의존하지 않는다. 고정 timestamp로 생성하며 해시는 `SHA256SUMS`에 기록한다.

- `regular.ttf`, `bold.ttf`: 동일 family, 다른 PostScript 이름·weight, 한국어·영어 이름.
- `regular.otf`: CFF 윤곽.
- `two-face.ttc`: regular/bold 2개 SFNT face, 공유 table.
- `variable.ttf`: `wght` 100–900, 기본 400, named instance 700. 메타데이터 및 제한 상태 검증용이며 제품 가변 렌더 지원 판정이 아니다.
- `language-tag.ttf`: name format 1의 `ko-KR` 언어 태그와 한국어 이름 연결.
