# 우사기 뒤쪽 귀 수정

사용자 피드백에 따라 뒤태 아이콘의 귀 2개와 흔들기 시트 6프레임의 귀 12개에서 분홍 귀 안쪽을 없애고, 머리와 이어지는 연노랑 털로 수정했습니다.

- 런타임 파일: `godot/assets/icons/items_v1/item01_usagi_shake.png` (128×128), `godot/assets/effects/spritesheets/usagi_shake.png` (768×512).
- 시트: 3열×2행, 256×256 6프레임. 기존 JSON·재생 속도·루프 설정은 유지합니다.
- 내장 image_gen으로 편집했습니다. 전체 프롬프트는 `generation.json` 및 `cleanup_prompt.txt`에 저장했습니다. 생성 편집 특성상 그림이 픽셀 단위로 동일한 결과는 아니며, 포즈 순서와 뒤태 구성은 시각 비교했습니다.
- 처음 시트 편집에 생긴 갈색 배경과 첫 프레임 귀 주변 얼룩은 추가 이미지 편집으로 제거했습니다. 최종 `review.png`는 크림 배경 합성으로 투명 영역을 검수한 이미지입니다.
- `before/`에 수정 전 두 출력 파일을 보존했습니다.
- 재내보내기로 분홍 귀가 복구되지 않도록 `assets/source/cave_items_v1/masters/item01_usagi_shake.png`와 `assets/source/item_effects_v1/masters/usagi_shake.png`도 갱신했습니다. 과거 제작 기록은 보존하며, 이 수정 기록이 우사기 색상에 대해 우선합니다.
- Godot headless로 `export.gd`를 실행해 기계적 축소와 검수 이미지 생성을 재현할 수 있습니다.
- `validation.json`: 원래 출력 크기·RGBA 투명도·프레임별 귀 영역의 분홍색 검사 결과를 기록합니다. 색상 임계값 검사는 시각 검수를 보조합니다.

게임 코드·메타데이터·아이템 작동 방식은 변경하지 않았습니다. 실행 파일/웹 재빌드는 통합 담당의 후속 작업입니다.
