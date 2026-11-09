"""Builds dist/ShamanTracker-<version>.zip, ready to unzip into Interface/AddOns.

The version comes from the ## Version line in ShamanTracker/ShamanTracker.toc.
Usage: python3 scripts/package.py   (or: make package)
"""
import pathlib
import re
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
ADDON = ROOT / "ShamanTracker"
TOC = ADDON / "ShamanTracker.toc"


def main():
    match = re.search(r"^## Version:\s*(\S+)", TOC.read_text(), re.MULTILINE)
    if not match:
        raise SystemExit("no ## Version line in " + str(TOC))
    version = match.group(1)

    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    target = dist / f"ShamanTracker-{version}.zip"
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(ADDON.rglob("*")):
            if path.is_file():
                archive.write(path, path.relative_to(ROOT).as_posix())
    print(target.relative_to(ROOT))


if __name__ == "__main__":
    main()
