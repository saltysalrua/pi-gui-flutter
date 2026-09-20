"""Focused regression checks for the version gate and release archive boundary."""

import gzip
import hashlib
import subprocess
import tarfile
import tempfile
import unittest
import zipfile
from contextlib import ExitStack
from pathlib import Path
from unittest import mock

from ci_release import (
    detect,
    flutter_notices,
    git,
    package,
    package_linux,
    parse_version,
    release_notes,
)


class ReleaseTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="pi-gui-release-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        git(self.root, "init", "-b", "master")
        git(self.root, "config", "user.name", "Release Test")
        git(self.root, "config", "user.email", "test@example.invalid")
        git(self.root, "config", "core.autocrlf", "false")
        git(self.root, "config", "commit.gpgsign", "false")

    def commit(self, version=None, dependency="one"):
        (self.root / "fixture.txt").write_text(dependency, encoding="utf-8")
        if version is not None:
            (self.root / "pubspec.yaml").write_text(
                f"name: fixture\nversion: {version}\n# {dependency}\n", encoding="utf-8"
            )
        git(self.root, "add", ".")
        git(self.root, "commit", "-m", "fixture")
        return git(self.root, "rev-parse", "HEAD")

    def test_scalar_format_and_windows_limits(self):
        for source in (
            "version: 1.0.0+1\n",
            "version: '1.0.0+1' # comment\r\n",
            'version: "1.0.0+1"\n',
        ):
            self.assertEqual(parse_version(source), "1.0.0+1")
        self.assertEqual(parse_version("version: 1.1.0-beta.1+2"), "1.1.0-beta.1+2")
        for value in ("1.0", "01.0.0", "1.0.0+65536", "1.0.0+abc", "1.0.0-01", "$(id)"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                parse_version(f"version: {value}")
        for source in (
            "name: app",
            "  version: 1.0.0",
            "version: 1.0.0\nversion: 2.0.0",
        ):
            with self.assertRaises(ValueError):
                parse_version(source)

    def test_initial_push_and_first_pubspec(self):
        before = self.commit()
        self.commit("1.0.0+1")
        for revision in ("0" * 40, before):
            result = detect(self.root, "push", {"before": revision})
            self.assertEqual(result["changed"], "true")
            self.assertEqual(result["tag"], "v1.0.0+1")

    def test_whole_push_not_just_last_commit_and_build_number(self):
        before = self.commit("1.0.0+1")
        self.commit("1.0.0+2")
        self.commit("1.0.0+2", "dependency-only commit at push tip")
        result = detect(self.root, "push", {"before": before})
        self.assertEqual(result["changed"], "true")
        self.assertEqual(result["previous"], "1.0.0+1")

    def test_dependency_only_net_revert_manual_and_invalid_history(self):
        before = self.commit("1.0.0+1")
        self.commit("1.0.0+1", "dependency changed")
        self.assertEqual(
            detect(self.root, "push", {"before": before})["changed"], "false"
        )
        self.commit("1.0.0+2")
        self.commit("1.0.0+1")
        self.assertEqual(
            detect(self.root, "push", {"before": before})["changed"], "false"
        )
        self.assertEqual(detect(self.root, "workflow_dispatch", {})["changed"], "true")
        self.commit("1.1.0-beta.1+2")
        self.assertEqual(
            detect(self.root, "push", {"before": before})["prerelease"], "true"
        )
        with self.assertRaises(ValueError):
            detect(self.root, "push", {"before": "--help"})
        with self.assertRaises(subprocess.CalledProcessError):
            detect(self.root, "push", {"before": "f" * 40})

    def test_flutter_notices_reject_missing_corrupt_and_empty_text(self):
        path = self.root / "data/flutter_assets/NOTICES.Z"
        with self.assertRaises(ValueError):
            flutter_notices(self.root)
        path.parent.mkdir(parents=True)
        for data in (b"not gzip", gzip.compress(b"\xff"), gzip.compress(b" \n")):
            path.write_bytes(data)
            with self.assertRaises(ValueError):
                flutter_notices(self.root)
        original = "Copyright 原始声明\r\nLicense text\n".encode()
        path.write_bytes(gzip.compress(original))
        self.assertEqual(flutter_notices(self.root), original)

    def test_complete_zip_checksum_and_qa_rejection(self):
        self.commit("1.0.0+1")
        source = self.root / "Release"
        for name in (
            "pi_gui.exe",
            "flutter_windows.dll",
            "data/icudtl.dat",
            "data/app.so",
            "data/flutter_assets/font.ttf",
            "plugin.dll",
        ):
            path = source / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"fixture")
        for name in (
            "docs/release_usage.md",
            "THIRD_PARTY_NOTICES.md",
            "assets/fonts/MiSans/LICENSE.pdf",
        ):
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"notice")
        (self.root / "licenses").mkdir()
        (self.root / "licenses/MaterialIcons-LICENSE.txt").write_bytes(b"icons notice")
        notices = b"Original Flutter and Pub license texts\n"
        (source / "data/flutter_assets/NOTICES.Z").write_bytes(gzip.compress(notices))
        (self.root / "LICENSE").write_bytes(b"project MIT license")
        guide = self.root / "docs/release_usage.md"
        body = "# Windows 便携版使用说明\n\n正文。\n\n---\n\n保留正文分隔线。\n"
        guide.write_text(body, encoding="utf-8")
        self.assertEqual(release_notes(self.root), body)
        guide.write_bytes(
            ("---\r\ntitle: 使用说明\r\n---\r\n\r\n" + body).encode("utf-8-sig")
        )
        self.assertEqual(release_notes(self.root), body)
        archive = package(self.root, source, self.root / "dist")
        with zipfile.ZipFile(archive) as bundle:
            self.assertIsNone(bundle.testzip())
            self.assertIn("pi_gui.exe", bundle.namelist())
            self.assertEqual(bundle.read("LICENSE"), b"project MIT license")
            self.assertIn("plugin.dll", bundle.namelist())
            self.assertIn("data/flutter_assets/font.ttf", bundle.namelist())
            self.assertIn("licenses/MiSans-LICENSE.pdf", bundle.namelist())
            self.assertEqual(bundle.read("licenses/MaterialIcons-LICENSE.txt"), b"icons notice")
            self.assertEqual(bundle.read("licenses/Flutter-Pub-NOTICES.txt"), notices)
            self.assertEqual(gzip.decompress(bundle.read("data/flutter_assets/NOTICES.Z")), notices)
            self.assertEqual(bundle.read("README.md").decode("utf-8"), body)
        checksum = archive.with_suffix(".zip.sha256").read_text(encoding="utf-8")
        self.assertEqual(
            checksum,
            f"{hashlib.sha256(archive.read_bytes()).hexdigest()}  {archive.name}\n",
        )
        (source / "qa.exe").write_bytes(b"not production")
        with self.assertRaises(ValueError):
            package(self.root, source, self.root / "dist")
        (source / "qa.exe").unlink()
        (source / "data/app.so").unlink()
        with self.assertRaises(ValueError):
            package(self.root, source, self.root / "dist")

    def test_linux_tarball_checksum_and_qa_rejection(self):
        self.commit("1.0.0+1")
        source = self.root / "bundle"
        for name in (
            "pi_gui",
            "data/icudtl.dat",
            "data/flutter_assets/font.ttf",
            "lib/libapp.so",
            "lib/libflutter_linux_gtk.so",
        ):
            path = source / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"fixture")
        for name in (
            "docs/release_usage.md",
            "THIRD_PARTY_NOTICES.md",
            "assets/fonts/MiSans/LICENSE.pdf",
        ):
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"notice")
        (self.root / "licenses").mkdir()
        (self.root / "licenses/MaterialIcons-LICENSE.txt").write_bytes(b"icons notice")
        notices = b"Original Flutter and Pub license texts\n"
        (source / "data/flutter_assets/NOTICES.Z").write_bytes(gzip.compress(notices))
        (self.root / "LICENSE").write_bytes(b"project MIT license")
        body = "---\ntitle: 使用说明\n---\n\n# 使用说明\n\n正文。\n"
        (self.root / "docs/release_usage.md").write_text(body, encoding="utf-8-sig")
        # Windows stat cannot express the POSIX executable bit, so the
        # validation set is stubbed for every host; CI exercises the real
        # chmod-derived mode on ubuntu.
        with ExitStack() as stack:
            stack.enter_context(
                mock.patch("ci_release.linux_executables", return_value={"pi_gui"})
            )
            archive = package_linux(self.root, source, self.root / "dist")
        self.assertEqual(archive.name, "pi-gui-flutter-1.0.0+1-linux-x64.tar.gz")
        with tarfile.open(archive) as bundle:
            names = bundle.getnames()
            for expected in (
                "pi_gui",
                "lib/libflutter_linux_gtk.so",
                "data/flutter_assets/font.ttf",
                "README.md",
                "licenses/MiSans-LICENSE.pdf",
            ):
                self.assertIn(expected, names)
            for name, expected in (
                ("LICENSE", b"project MIT license"),
                ("licenses/MaterialIcons-LICENSE.txt", b"icons notice"),
                ("licenses/Flutter-Pub-NOTICES.txt", notices),
                ("data/flutter_assets/NOTICES.Z", notices),
            ):
                handle = bundle.extractfile(name)
                assert handle is not None
                actual = handle.read()
                if name.endswith(".Z"):
                    actual = gzip.decompress(actual)
                self.assertEqual(actual, expected)
            readme_handle = bundle.extractfile("README.md")
            assert readme_handle is not None
            self.assertEqual(
                readme_handle.read().decode("utf-8"), release_notes(self.root)
            )
        checksum = (self.root / "dist" / (archive.name + ".sha256")).read_text(
            encoding="utf-8"
        )
        self.assertEqual(
            checksum,
            f"{hashlib.sha256(archive.read_bytes()).hexdigest()}  {archive.name}\n",
        )
        with (
            mock.patch(
                "ci_release.linux_executables", return_value={"pi_gui", "qa_tool"}
            ),
            self.assertRaises(ValueError),
        ):
            package_linux(self.root, source, self.root / "dist")
        with (
            mock.patch("ci_release.linux_executables", return_value=set()),
            self.assertRaises(ValueError),
        ):
            package_linux(self.root, source, self.root / "dist")
        (source / "lib/libapp.so").unlink()
        with (
            mock.patch("ci_release.linux_executables", return_value={"pi_gui"}),
            self.assertRaises(ValueError),
        ):
            package_linux(self.root, source, self.root / "dist")


if __name__ == "__main__":
    unittest.main()
