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


def solar_flare_svg() -> str:
    return '''<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="675" viewBox="0 0 1200 675" role="img" aria-labelledby="title desc">
<title id="title">태양과 렌즈 플레어 생성 흐름</title><desc id="desc">RealityKit 태양 구와 절차적 코로나를 화면에 투영하고 카메라 정렬 강도로 렌즈 플레어를 표시하는 구조</desc>
<defs>
  <radialGradient id="sun"><stop stop-color="#FFFFFF"/><stop offset=".28" stop-color="#FFF5C9"/><stop offset="1" stop-color="#62D9F5" stop-opacity="0"/></radialGradient>
  <linearGradient id="beam" x1="0" x2="0" y1="0" y2="1"><stop stop-color="#FFF7D6" stop-opacity=".75"/><stop offset="1" stop-color="#FFD66B" stop-opacity="0"/></linearGradient>
</defs>
<rect width="1200" height="675" rx="36" fill="#071C2A"/>
<text x="70" y="90" fill="white" font-family="-apple-system, sans-serif" font-size="42" font-weight="700">공간의 태양을 카메라 렌즈 효과로 연결하기</text>
<text x="70" y="132" fill="#9CC3D5" font-family="-apple-system, sans-serif" font-size="22">RealityKit 월드 좌표 → 화면 투영 · 정면 정렬 → 이미지 없는 렌즈 플레어</text>
<g font-family="-apple-system, sans-serif" text-anchor="middle">
  <rect x="65" y="210" width="290" height="350" rx="28" fill="#12394D" stroke="#FFD66B" stroke-width="3"/>
  <circle cx="210" cy="300" r="72" fill="url(#sun)"/>
  <circle cx="210" cy="300" r="23" fill="#FFF8D8"/>
  <path d="M210 325L310 495H110Z" fill="url(#beam)"/>
  <text x="210" y="515" fill="white" font-size="27" font-weight="700">RealityKit 태양</text>
  <text x="210" y="548" fill="#F6DFA0" font-size="19">태양 구 · 코로나 · 교차 빔</text>

  <path d="M375 375H465" stroke="#62D9F5" stroke-width="6"/>
  <path d="M445 355l25 20-25 20" fill="none" stroke="#62D9F5" stroke-width="6"/>
  <rect x="480" y="240" width="260" height="270" rx="28" fill="#12394D" stroke="#62D9F5" stroke-width="3"/>
  <text x="610" y="310" fill="white" font-size="27" font-weight="700">매 프레임 계산</text>
  <text x="610" y="365" fill="#9CC3D5" font-size="21">ARView.project()</text>
  <text x="610" y="405" fill="#9CC3D5" font-size="21">카메라 · 태양 내적</text>
  <text x="610" y="445" fill="#9CC3D5" font-size="21">UV Index 밝기</text>

  <path d="M760 375H850" stroke="#A982FF" stroke-width="6"/>
  <path d="M830 355l25 20-25 20" fill="none" stroke="#A982FF" stroke-width="6"/>
  <rect x="865" y="210" width="270" height="350" rx="28" fill="#12394D" stroke="#A982FF" stroke-width="3"/>
  <circle cx="960" cy="310" r="78" fill="none" stroke="#62D9F5" stroke-opacity=".45" stroke-width="3"/>
  <circle cx="960" cy="310" r="45" fill="url(#sun)"/>
  <g stroke="#EAF8FF" stroke-opacity=".55" stroke-width="3"><path d="M960 230v-45"/><path d="M960 390v45"/><path d="M880 310h-45"/><path d="M1040 310h45"/><path d="M903 253l-34-34"/><path d="M1017 367l34 34"/></g>
  <circle cx="1030" cy="380" r="13" fill="#8DEBFF" fill-opacity=".65"/>
  <circle cx="1080" cy="430" r="28" fill="none" stroke="#FF8CC8" stroke-opacity=".45" stroke-width="3"/>
  <circle cx="1105" cy="458" r="7" fill="#FFF8D8"/>
  <text x="1000" y="515" fill="white" font-size="27" font-weight="700">렌즈 플레어</text>
  <text x="1000" y="548" fill="#D9C8FF" font-size="19">헤일로 · 링 · 방사광 · 고스트</text>
</g>
</svg>'''


def generate_svgs() -> None:
    IMAGE_DIR.mkdir(parents=True, exist_ok=True)
    diagrams = {
        "air-ar-hero.svg": svg("현재 위치 환경 데이터를 공간에 놓기", '<rect x="170" y="200" width="860" height="360" rx="28"/><circle cx="420" cy="380" r="65"/><circle cx="550" cy="335" r="18"/><circle cx="600" cy="410" r="25"/><circle cx="775" cy="350" r="70"/><path d="M775 245v-45 M775 500v-45 M670 350h-45 M925 350h-45"/>'),
        "world-coordinate-diagram.svg": svg("카메라 좌표에서 월드 좌표로", '<path d="M250 480V240 M250 480h250 M250 480l-90 90"/><rect x="510" y="260" width="190" height="120" rx="18"/><path d="M610 390v145"/><path d="M595 510l15 25 15-25"/><rect x="475" y="535" width="270" height="70" rx="18"/>'),
        "pm25-visualization.svg": svg("PM2.5 RealityKit 파티클", ''.join(f'<circle cx="{250+(i*83)%700}" cy="{230+(i*67)%300}" r="{10+(i%4)*4}"/>' for i in range(24))),
        "uv-visualization.svg": solar_flare_svg(),
        "github-pages-flow.svg": svg("DocC를 GitHub Pages로 배포", '<rect x="90" y="280" width="210" height="110" rx="20"/><path d="M300 335h120"/><rect x="420" y="280" width="210" height="110" rx="20"/><path d="M630 335h120"/><rect x="750" y="280" width="330" height="110" rx="20"/>'),
    }
    for name, content in diagrams.items():
        (IMAGE_DIR / name).write_text(content, encoding="utf-8")


if __name__ == "__main__":
    generate_icon()
    generate_svgs()
    print("앱 아이콘과 DocC 개념도를 생성했습니다.")
