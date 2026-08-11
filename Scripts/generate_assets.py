#!/usr/bin/env python3
"""외부 라이브러리 없이 앱 아이콘과 DocC 개념도를 생성합니다."""

from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
ICON_DIR = ROOT / "AirAR" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"
IMAGE_DIR = ROOT / "AirAR" / "Documentation.docc" / "Resources" / "Images"


def write_png(path: Path, width: int, height: int, pixels: bytearray) -> None:
    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    rows = bytearray()
    stride = width * 3
    for y in range(height):
        rows.append(0)
        rows.extend(pixels[y * stride:(y + 1) * stride])
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(rows), 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


def generate_icon() -> None:
    size = 1024
    pixels = bytearray(size * size * 3)
    for y in range(size):
        for x in range(size):
            t = (x + y) / (size * 2)
            color = (int(18 + 12 * t), int(73 + 45 * t), int(106 + 60 * t))
            offset = (y * size + x) * 3
            pixels[offset:offset + 3] = bytes(color)

    def circle(cx: int, cy: int, radius: int, color: tuple[int, int, int]) -> None:
        r2 = radius * radius
        for y in range(max(0, cy - radius), min(size, cy + radius + 1)):
            for x in range(max(0, cx - radius), min(size, cx + radius + 1)):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r2:
                    offset = (y * size + x) * 3
                    pixels[offset:offset + 3] = bytes(color)

    def rect(x0: int, y0: int, x1: int, y1: int, color: tuple[int, int, int]) -> None:
        for y in range(y0, y1):
            for x in range(x0, x1):
                offset = (y * size + x) * 3
                pixels[offset:offset + 3] = bytes(color)

    # AR 프레임 모서리
    cyan = (122, 233, 255)
    for x, y, sx, sy in [(190, 190, 1, 1), (834, 190, -1, 1), (190, 834, 1, -1), (834, 834, -1, -1)]:
        rect(min(x, x + sx * 180), y - 12, max(x, x + sx * 180), y + 12, cyan)
        rect(x - 12, min(y, y + sy * 180), x + 12, max(y, y + sy * 180), cyan)
    # 태양과 광선
    circle(650, 420, 116, (255, 191, 58))
    for px, py in [(650, 245), (650, 595), (475, 420), (825, 420), (525, 295), (775, 295), (525, 545), (775, 545)]:
        circle(px, py, 20, (255, 219, 96))
    # 미세먼지 입자
    for cx, cy, radius in [(345, 435, 42), (290, 530, 26), (400, 555, 34), (310, 650, 20), (455, 660, 28), (240, 620, 15)]:
        circle(cx, cy, radius, (154, 231, 244))

    ICON_DIR.mkdir(parents=True, exist_ok=True)
    write_png(ICON_DIR / "AppIcon-1024.png", size, size, pixels)


def svg(title: str, body: str, accent: str = "#62D9F5") -> str:
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="675" viewBox="0 0 1200 675" role="img" aria-labelledby="title desc">
<title id="title">{title}</title><desc id="desc">실제 앱 화면이 아닌 구현 구조를 설명하는 개념도</desc>
<rect width="1200" height="675" rx="36" fill="#071C2A"/>
<text x="70" y="90" fill="white" font-family="-apple-system, sans-serif" font-size="42" font-weight="700">{title}</text>
<text x="70" y="132" fill="#9CC3D5" font-family="-apple-system, sans-serif" font-size="22">구현 구조를 설명하는 개념도</text>
<g stroke="{accent}" stroke-width="5" fill="none">{body}</g>
</svg>'''


def generate_svgs() -> None:
    IMAGE_DIR.mkdir(parents=True, exist_ok=True)
    diagrams = {
        "air-ar-hero.svg": svg("현재 위치 환경 데이터를 공간에 놓기", '<rect x="170" y="200" width="860" height="360" rx="28"/><circle cx="420" cy="380" r="65"/><circle cx="550" cy="335" r="18"/><circle cx="600" cy="410" r="25"/><circle cx="775" cy="350" r="70"/><path d="M775 245v-45 M775 500v-45 M670 350h-45 M925 350h-45"/>'),
        "world-coordinate-diagram.svg": svg("카메라 좌표에서 월드 좌표로", '<path d="M250 480V240 M250 480h250 M250 480l-90 90"/><rect x="510" y="260" width="190" height="120" rx="18"/><path d="M610 390v145"/><path d="M595 510l15 25 15-25"/><rect x="475" y="535" width="270" height="70" rx="18"/>'),
        "pm25-visualization.svg": svg("PM2.5 결정론적 입자", ''.join(f'<circle cx="{250+(i*83)%700}" cy="{230+(i*67)%300}" r="{10+(i%4)*4}"/>' for i in range(24))),
        "uv-visualization.svg": svg("UV Index 0...11 게이지", '<rect x="520" y="200" width="160" height="360" rx="60"/><rect x="555" y="325" width="90" height="200" rx="35" fill="#62D9F5"/><path d="M750 520V210 M735 225l15-25 15 25"/>'),
        "github-pages-flow.svg": svg("DocC를 GitHub Pages로 배포", '<rect x="90" y="280" width="210" height="110" rx="20"/><path d="M300 335h120"/><rect x="420" y="280" width="210" height="110" rx="20"/><path d="M630 335h120"/><rect x="750" y="280" width="330" height="110" rx="20"/>'),
    }
    for name, content in diagrams.items():
        (IMAGE_DIR / name).write_text(content, encoding="utf-8")


if __name__ == "__main__":
    generate_icon()
    generate_svgs()
    print("앱 아이콘과 DocC 개념도를 생성했습니다.")
