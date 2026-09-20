"""Version gate plus complete Windows ZIP and Linux tar packaging for GitHub
Actions (stdlib only)."""

from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import json
import os
import re
import stat
import subprocess
import sys
import tarfile
import zipfile
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# Flutter's build number becomes the fourth numeric Windows file-version field.
VERSION = re.compile(
    r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
    r"(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?"
    r"(?:\+(0|[1-9][0-9]*))?"
)


def parse_version(source: str) -> str:
    """Read exactly one top-level scalar; reject unsafe/unsupported versions."""
    lines = re.findall(r"^version:[ \t]*(.*)$", source, re.MULTILINE)
    if len(lines) != 1:
        raise ValueError("pubspec.yaml must contain exactly one top-level version.")
    value = lines[0].split("#", 1)[0].strip()
    if value.startswith(("'", '"')) and value.endswith(value[0]):
        value = value[1:-1]
    match = VERSION.fullmatch(value)
    if not match:
        raise ValueError("Use a version such as 1.0.0+1 or 1.1.0-beta.1+2.")
    major, minor, patch, prerelease, build = match.groups()
    try:
        fields = [int(part) for part in (major, minor, patch, build or "0")]
    except ValueError as error:
        raise ValueError("Windows version fields must be small integers.") from error
    if any(part > 65535 for part in fields):
        raise ValueError("Windows version fields must be between 0 and 65535.")
    if prerelease and any(
        part.isdigit() and len(part) > 1 and part.startswith("0")
        for part in prerelease.split(".")
    ):
        raise ValueError("Numeric prerelease identifiers cannot have leading zeroes.")
    return value


def git(root: Path, *args: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(root), *args], encoding="utf-8"
    ).strip()


def version_at(root: Path, revision: str) -> str | None:
    if not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise ValueError("Expected a full Git commit SHA.")
    if revision == "0" * 40:
        return None  # Initial branch push, even when local history already exists.
    exists = subprocess.run(
        ["git", "-C", str(root), "cat-file", "-e", f"{revision}^{{commit}}"],
        capture_output=True,
        check=False,
    )
    if exists.returncode:
        # A force-push can leave 'before' outside the checked-out branch history.
        git(root, "fetch", "--no-tags", "origin", revision)
    if not git(root, "ls-tree", "--name-only", revision, "--", "pubspec.yaml"):
        return None
    return parse_version(git(root, "show", f"{revision}:pubspec.yaml"))


def detect(root: Path, event_name: str, event: dict) -> dict[str, str]:
    current = parse_version((root / "pubspec.yaml").read_text(encoding="utf-8-sig"))
    if event_name == "workflow_dispatch":
        previous = None
        changed = True
    elif event_name == "push":
        previous = version_at(root, event["before"])
        changed = current != previous
    else:
        raise ValueError("Only push and workflow_dispatch events can release.")
    return {
        "changed": str(changed).lower(),
        "version": current,
        "previous": previous or "",
        "tag": f"v{current}",
        "prerelease": str("-" in current.split("+", 1)[0]).lower(),
    }


def release_notes(root: Path) -> str:
    """Publish the guide body, not its repository-only YAML metadata."""
    text = (root / "docs/release_usage.md").read_text(encoding="utf-8-sig")
    if not text.startswith("---\n"):
        return text
    _, separator, body = text[4:].partition("\n---\n")
    if not separator:
        raise ValueError("release_usage.md has an unclosed YAML header.")
    return body.lstrip("\n")


# Files from the repository that ship inside every release archive next to the
# application itself.
SHARED_FILES = (
    ("LICENSE", "LICENSE"),
    ("THIRD_PARTY_NOTICES.md", "THIRD_PARTY_NOTICES.md"),
    ("assets/fonts/MiSans/LICENSE.pdf", "licenses/MiSans-LICENSE.pdf"),
    ("licenses/MaterialIcons-LICENSE.txt", "licenses/MaterialIcons-LICENSE.txt"),
)


def flutter_notices(source: Path) -> bytes:
    """Require Flutter's license bundle and preserve its original text bytes."""
    path = source / "data/flutter_assets/NOTICES.Z"
    try:
        text = gzip.decompress(path.read_bytes())
        if not text.decode("utf-8").strip():
            raise ValueError("Flutter license bundle is empty")
    except (OSError, EOFError, UnicodeError, zlib.error) as error:
        raise ValueError("Missing or invalid Flutter license bundle: NOTICES.Z") from error
    return text


def write_checksum(archive: Path) -> None:
    with archive.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    archive.with_name(archive.name + ".sha256").write_text(
        f"{digest}  {archive.name}\n", encoding="utf-8"
    )


def package(root: Path, source: Path, output: Path) -> Path:
    version = parse_version((root / "pubspec.yaml").read_text(encoding="utf-8-sig"))
    for name in ("pi_gui.exe", "flutter_windows.dll", "data/icudtl.dat", "data/app.so"):
        if not (source / name).is_file():
            raise ValueError(f"Incomplete Windows release: missing {name}")
    executables = {
        p.name.lower() for p in source.iterdir() if p.suffix.lower() == ".exe"
    }
    if executables != {"pi_gui.exe"}:
        raise ValueError(f"Unexpected EXE in release directory: {sorted(executables)}")
    if not (source / "data/flutter_assets").is_dir():
        raise ValueError("Incomplete Windows release: missing Flutter assets")
    notices = flutter_notices(source)
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f"pi-gui-flutter-{version}-windows-x64.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
        for path in sorted(source.rglob("*")):
            if path.is_file():
                bundle.write(path, path.relative_to(source).as_posix())
        bundle.writestr("README.md", release_notes(root).encode("utf-8"))
        bundle.writestr("licenses/Flutter-Pub-NOTICES.txt", notices)
        for original, destination in SHARED_FILES:
            bundle.write(root / original, destination)
    write_checksum(archive)
    return archive


def linux_executables(source: Path) -> set[str]:
    """Top-level files that still carry a POSIX executable bit after the build."""
    return {
        p.name
        for p in source.iterdir()
        if p.is_file()
        and p.stat().st_mode & (stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    }


def package_linux(root: Path, source: Path, output: Path) -> Path:
    """Package the Flutter Linux bundle as a tar.gz that keeps the executable bit."""
    version = parse_version((root / "pubspec.yaml").read_text(encoding="utf-8-sig"))
    for name in (
        "pi_gui",
        "data/icudtl.dat",
        "lib/libapp.so",
        "lib/libflutter_linux_gtk.so",
    ):
        if not (source / name).is_file():
            raise ValueError(f"Incomplete Linux release: missing {name}")
    if not (source / "data/flutter_assets").is_dir():
        raise ValueError("Incomplete Linux release: missing Flutter assets")
    executables = linux_executables(source)
    if executables != {"pi_gui"}:
        raise ValueError(
            f"Unexpected executable in release directory: {sorted(executables)}"
        )
    notices = flutter_notices(source)
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f"pi-gui-flutter-{version}-linux-x64.tar.gz"
    with tarfile.open(archive, "w:gz") as bundle:
        for path in sorted(source.rglob("*")):
            if path.is_file() or path.is_symlink():
                bundle.add(
                    path,
                    arcname=path.relative_to(source).as_posix(),
                    recursive=False,
                )
        readme = release_notes(root).encode("utf-8")
        info = tarfile.TarInfo("README.md")
        info.size = len(readme)
        bundle.addfile(info, io.BytesIO(readme))
        info = tarfile.TarInfo("licenses/Flutter-Pub-NOTICES.txt")
        info.size = len(notices)
        bundle.addfile(info, io.BytesIO(notices))
        for original, destination in SHARED_FILES:
            bundle.add(root / original, arcname=destination, recursive=False)
    write_checksum(archive)
    return archive


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "command", choices=("detect", "package", "package-linux", "notes")
    )
    args = parser.parse_args()
    if args.command == "detect":
        try:
            event = json.loads(
                Path(os.environ["GITHUB_EVENT_PATH"]).read_text(encoding="utf-8")
            )
        except (KeyError, OSError, json.JSONDecodeError) as error:
            raise SystemExit(
                f"Cannot read the GitHub event payload: {error}"
            ) from error
        result = detect(ROOT, os.environ["GITHUB_EVENT_NAME"], event)
        lines = "".join(f"{key}={value}\n" for key, value in result.items())
        print(lines, end="")
        if output := os.environ.get("GITHUB_OUTPUT"):
            with Path(output).open("a", encoding="utf-8") as stream:
                stream.write(lines)
        if summary := os.environ.get("GITHUB_STEP_SUMMARY"):
            with Path(summary).open("a", encoding="utf-8") as stream:
                stream.write(
                    f"## Version check\n\nPrevious: `{result['previous'] or 'none/manual'}`"
                    f" → Current: `{result['version']}`\n\n"
                    f"Build requested: **{result['changed']}**\n"
                )
    elif args.command == "notes":
        sys.stdout.buffer.write(release_notes(ROOT).encode("utf-8"))
    elif args.command == "package-linux":
        print(
            package_linux(ROOT, ROOT / "build/linux/x64/release/bundle", ROOT / "dist")
        )
    else:
        print(package(ROOT, ROOT / "build/windows/x64/runner/Release", ROOT / "dist"))


if __name__ == "__main__":
    main()
