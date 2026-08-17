#!/usr/bin/env python3
"""자리 배치 연출용 테이블·의자 이미지의 빈 가운데를 게임 배경으로 채웁니다.

게임 진입 연출(`PlayerLayoutEditor`)은 테이블과 의자를 화면에 깔았다가 테이블로
줌인해 그대로 게임 화면으로 이어집니다. 그래서 가운데 면은 그 게임의
`background.png`와 같은 재질·색이어야 이음매가 보이지 않습니다.

입력은 가운데가 투명한 PNG 템플릿이고, 출력은
`assets/games/<game>/images/layout/layout_<kind>.png` 입니다.

사용법:
    python3 tool/fill_layout_asset.py --game final_call --kind table \
        --template ~/Desktop/layout_table.png

    # 만들어질 결과만 확인하고 저장은 하지 않기
    python3 tool/fill_layout_asset.py --game final_call --kind table \
        --template ~/Desktop/layout_table.png --dry-run
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

REPO_ROOT = Path(__file__).resolve().parent.parent

# 알파가 이 값 미만이면 "비어 있는 칸"으로 봅니다. 안티에일리어싱된 테두리를
# 채움 대상에 넣지 않으려고 낮게 잡습니다.
ALPHA_EMPTY = 8

# 기본값은 이미 손으로 만들어 둔 라이어스포커·파이널콜 에셋을 재서 정했습니다.
# 가장자리에서의 거리별 밝기를 재보면 두 종류가 확실히 다릅니다.
#
#   테이블: 안쪽이 거의 균일합니다(라이어스포커 54.2 → 52.0). 상판은 평평한
#           면이라 그림자를 넣으면 오히려 어색합니다.
#   의자  : 팔걸이 안쪽으로 그림자가 집니다(라이어스포커 40.8 → 55.4). 앉는 면이
#           테두리보다 낮게 보여야 합니다.
#
# 아래 값은 두 게임 에셋에 맞춰 파라미터를 훑어 오차가 가장 작았던 값의
# 중간입니다(픽셀 평균 오차 255 중 2.8~6.6).
#
#   테이블: darken 0.90(라이어스포커) / 0.98(파이널콜)
#   의자  : darken 0.94 / 0.96, 그림자 폭 0.04, 세기 0.15 / 0.10
#
# 밝기는 게임 아트에 따라 갈리므로 한 값으로 두 게임을 다 맞출 수는 없습니다.
# 실행하면 '배경 대비 밝기'를 찍어주니, 마음에 안 들면 --darken으로 한 번 더
# 돌리세요.
KIND_DEFAULTS = {
    "table": {"darken": 0.94, "shadow_width": 0.0, "shadow_strength": 0.0},
    "chair": {"darken": 0.95, "shadow_width": 0.04, "shadow_strength": 0.12},
}


def load_template(path: Path) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    return image


def interior_mask(image: Image.Image) -> np.ndarray:
    """바깥 여백이 아니라 '도형 안쪽'의 빈 칸만 True로 돌려줍니다.

    테두리에서 시작해 이어진 투명 영역을 바깥으로 보고 제외합니다. 도형이 한쪽이
    터져 있으면 안쪽과 바깥이 이어져 채울 곳을 못 찾고, 그때는 호출한 쪽에서
    오류로 처리합니다.
    """
    alpha = np.array(image.getchannel("A"))
    empty = alpha < ALPHA_EMPTY

    # 4-이웃으로 연결 요소를 나눈 뒤, 테두리에 닿은 덩어리를 바깥으로 봅니다.
    labels, count = ndimage.label(empty)
    if count == 0:
        return np.zeros_like(empty)

    edge_labels = set(labels[0, :]) | set(labels[-1, :])
    edge_labels |= set(labels[:, 0]) | set(labels[:, -1])
    edge_labels.discard(0)

    interior = empty & ~np.isin(labels, list(edge_labels))
    return interior


def diagnose_empty_mask(template: Image.Image) -> str:
    """채울 곳을 못 찾았을 때, 무엇이 잘못됐는지 짚어줍니다.

    실패 원인이 둘뿐이라(가운데가 투명하지 않거나, 도형이 터져 있거나) 실제
    픽셀을 보고 어느 쪽인지 알려주는 편이 훨씬 빠릅니다.
    """
    alpha = np.array(template.getchannel("A"))
    height, width = alpha.shape
    center = alpha[height // 2, width // 2]
    empty_share = (alpha < ALPHA_EMPTY).mean() * 100

    if center >= ALPHA_EMPTY:
        return (
            f"채울 곳을 찾지 못했습니다. 가운데 픽셀의 알파가 {center}(불투명)입니다.\n"
            "가운데를 흰색으로 칠하지 말고 완전히 지워서 투명하게 만들어 주세요.\n"
            "이미지 편집기에서 '배경 지우기'가 아니라 '선택 영역 삭제'여야 합니다."
        )
    return (
        f"채울 곳을 찾지 못했습니다. 투명한 픽셀은 {empty_share:.1f}% 있지만 모두\n"
        "바깥 여백과 이어져 있습니다. 테두리 도형이 한쪽에서 끊겨 안쪽과 바깥이\n"
        "통해 있다는 뜻이니, 테두리를 닫은 뒤 다시 시도하세요."
    )


def cover_resize(texture: Image.Image, size: tuple[int, int]) -> Image.Image:
    """비율을 유지한 채 대상 크기를 덮도록 키우고 가운데를 잘라냅니다."""
    target_w, target_h = size
    src_w, src_h = texture.size
    scale = max(target_w / src_w, target_h / src_h)
    new_size = (max(1, round(src_w * scale)), max(1, round(src_h * scale)))
    resized = texture.resize(new_size, Image.LANCZOS)
    left = (new_size[0] - target_w) // 2
    top = (new_size[1] - target_h) // 2
    return resized.crop((left, top, left + target_w, top + target_h))


def inner_shadow(mask: np.ndarray, width_px: float, strength: float) -> np.ndarray:
    """안쪽 면 가장자리에 지는 그림자의 밝기 배율(0~1)을 만듭니다.

    거리 변환으로 테두리에서 얼마나 들어왔는지 재고, 그 안쪽 폭만큼만 어둡게
    합니다. 단순히 마스크를 흐리면 면 전체가 어두워져서 거리 기준으로 합니다.
    """
    if strength <= 0 or width_px <= 0:
        return np.ones(mask.shape, dtype=np.float32)

    distance = ndimage.distance_transform_edt(mask).astype(np.float32)
    falloff = np.clip(distance / width_px, 0.0, 1.0)
    # 가장자리(0)에서 1-strength, 안쪽(1)에서 1.0
    return (1.0 - strength) + strength * falloff


def build(
    template: Image.Image,
    texture: Image.Image,
    darken: float,
    shadow_width: float,
    shadow_strength: float,
) -> Image.Image:
    mask = interior_mask(template)
    if not mask.any():
        raise SystemExit(diagnose_empty_mask(template))

    filled = cover_resize(texture.convert("RGB"), template.size)
    pixels = np.array(filled).astype(np.float32)

    pixels *= darken
    short_side = min(template.size)
    shade = inner_shadow(mask, short_side * shadow_width, shadow_strength)
    pixels *= shade[:, :, None]

    fill_rgb = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), "RGB")
    fill_alpha = Image.fromarray((mask * 255).astype(np.uint8), "L")
    # 채운 면과 테두리가 만나는 선이 도드라지지 않게 마스크를 아주 살짝 풉니다.
    fill_alpha = fill_alpha.filter(ImageFilter.GaussianBlur(0.6))

    base = Image.new("RGBA", template.size, (0, 0, 0, 0))
    base.paste(fill_rgb, (0, 0), fill_alpha)
    return Image.alpha_composite(base, template)


def make_preview(result: Image.Image, texture: Image.Image, width: int = 1200) -> Image.Image:
    """게임 배경 위에 결과를 얹어, 채운 면과 배경 사이의 이음매를 보여줍니다.

    진입 연출은 테이블로 줌인해 그대로 게임 화면으로 이어지므로, 채운 면이
    배경과 달라 보이면 그 순간 화면이 바뀐 느낌이 납니다. 저장 전에 여기서
    확인하세요.
    """
    height = round(width * texture.size[1] / texture.size[0])
    canvas = cover_resize(texture.convert("RGB"), (width, height)).convert("RGBA")
    size = round(min(width, height) * 0.62)
    canvas.alpha_composite(
        result.resize((size, size), Image.LANCZOS),
        ((width - size) // 2, (height - size) // 2),
    )
    return canvas


def short_path(path: Path) -> str:
    """저장소 안이면 상대 경로로, 밖이면 그대로 보여줍니다."""
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def report(image: Image.Image, mask_source: Image.Image, texture: Image.Image) -> str:
    """채운 면이 배경과 얼마나 맞는지 눈으로 확인하기 전에 숫자로 보여줍니다."""
    mask = interior_mask(mask_source)
    rgb = np.array(image.convert("RGB")).astype(np.float32)
    inside = rgb[mask]
    mean = inside.mean(axis=0)
    background_mean = np.array(texture.convert("RGB")).astype(np.float32).mean(axis=(0, 1))
    ratio = mean.mean() / background_mean.mean()
    rgb_text = ", ".join(str(int(round(v))) for v in mean)
    return (
        f"채운 면 {mask.mean() * 100:.1f}% · "
        f"평균 RGB ({rgb_text}) · "
        f"배경 대비 밝기 {ratio:.3f}"
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="테이블·의자 템플릿의 빈 가운데를 게임 배경으로 채워 에셋 경로에 저장합니다.",
    )
    parser.add_argument("--game", required=True, help="게임 폴더 이름 (예: liars_poker)")
    parser.add_argument("--kind", required=True, choices=["table", "chair"])
    parser.add_argument("--template", required=True, help="가운데가 투명한 PNG 경로")
    parser.add_argument(
        "--texture",
        help="채울 재질 이미지. 기본값은 해당 게임의 background.png 입니다.",
    )
    parser.add_argument("--out", help="저장 경로. 기본값은 해당 게임의 layout 폴더입니다.")
    parser.add_argument(
        "--darken",
        type=float,
        help="배경 대비 밝기 배율. 기본값은 종류별 측정값(테이블·의자 모두 0.97)입니다.",
    )
    parser.add_argument("--shadow-width", type=float, help="안쪽 그림자 폭(짧은 변 대비 비율)")
    parser.add_argument("--shadow-strength", type=float, help="안쪽 그림자 세기(0~1)")
    parser.add_argument(
        "--preview",
        help="게임 배경 위에 얹은 확인용 이미지를 저장할 경로입니다.",
    )
    parser.add_argument("--dry-run", action="store_true", help="저장하지 않고 결과만 보고합니다.")
    args = parser.parse_args()

    defaults = KIND_DEFAULTS[args.kind]
    darken = args.darken if args.darken is not None else defaults["darken"]
    shadow_width = (
        args.shadow_width if args.shadow_width is not None else defaults["shadow_width"]
    )
    shadow_strength = (
        args.shadow_strength
        if args.shadow_strength is not None
        else defaults["shadow_strength"]
    )

    game_root = REPO_ROOT / "assets" / "games" / args.game
    if not game_root.is_dir():
        raise SystemExit(f"게임 폴더가 없습니다: {game_root}")

    texture_path = (
        Path(args.texture).expanduser()
        if args.texture
        else game_root / "images" / "background" / "background.png"
    )
    if not texture_path.is_file():
        raise SystemExit(f"재질 이미지가 없습니다: {texture_path}")

    template_path = Path(args.template).expanduser()
    if not template_path.is_file():
        raise SystemExit(f"템플릿이 없습니다: {template_path}")

    out_path = (
        Path(args.out).expanduser()
        if args.out
        else game_root / "images" / "layout" / f"layout_{args.kind}.png"
    )

    template = load_template(template_path)
    texture = Image.open(texture_path)
    result = build(
        template,
        texture,
        darken=darken,
        shadow_width=shadow_width,
        shadow_strength=shadow_strength,
    )

    print(f"템플릿  {template_path}  {template.size[0]}x{template.size[1]}")
    print(f"재질    {short_path(texture_path)}")
    print(f"설정    밝기 {darken} · 그림자 세기 {shadow_strength} · 폭 {shadow_width}")
    print(f"결과    {report(result, template, texture)}")

    if args.preview:
        preview_path = Path(args.preview).expanduser()
        preview_path.parent.mkdir(parents=True, exist_ok=True)
        make_preview(result, texture).save(preview_path)
        print(f"미리보기 {short_path(preview_path)}")

    if args.dry_run:
        print("저장 안 함 (--dry-run)")
        return

    out_path.parent.mkdir(parents=True, exist_ok=True)
    result.save(out_path)
    print(f"저장    {short_path(out_path)}")


if __name__ == "__main__":
    sys.exit(main())
