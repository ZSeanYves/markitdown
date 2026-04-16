#!/usr/bin/env python3
from pathlib import Path

# 如果本机有 Pillow，就生成真正 jpg；没有就给出提示
try:
    from PIL import Image
except ImportError:
    raise SystemExit("请先安装 Pillow: pip install pillow")

root = Path("samples/html")
img_dir = root / "img"
img_dir.mkdir(parents=True, exist_ok=True)

# 1) 生成 jpg
img_path = img_dir / "img_red.jpg"
img = Image.new("RGB", (320, 180), (220, 40, 40))  # 红底图
img.save(img_path, format="JPEG", quality=90)

# 2) 生成 html 样例
cases = {
    "html_img_alt_basic.html": '<p><img src="img/img_red.jpg" alt="red diagram"></p>\n',
    "html_img_title_basic.html": '<p><img src="img/img_red.jpg" alt="red diagram" title="Figure title text"></p>\n',
    "html_figure_figcaption_basic.html": (
        "<figure>\n"
        '  <img src="img/img_red.jpg" alt="figure image" title="Figure title">\n'
        "  <figcaption>Figure caption text.</figcaption>\n"
        "</figure>\n"
    ),
    "html_img_missing_alt_negative.html": '<p><img src="img/img_red.jpg"></p>\n',
}

for name, content in cases.items():
    (root / name).write_text(content, encoding="utf-8")

print("done:")
print(f"  jpg: {img_path}")
for name in cases:
    print(f"  html: {root / name}")