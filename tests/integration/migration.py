"""Exercise migration against a temporary desktop, never the installed desktop."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile

binary = Path(sys.argv[1]).resolve()
repo = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix="macarchy-migration-test-") as temporary:
    home = Path(temporary)
    config = home / ".config"
    root = config / "macarchy-settings"
    root.mkdir(parents=True)
    (root / "settings.env").write_text('BORDER_WIDTH="7.0"\nBORDERS_VISIBLE="true"\nYABAI_WINDOW_GAP="8"\nSKETCHYBAR_HEIGHT="35"\n')
    themes = root / "themes"
    themes.mkdir()
    shutil.copytree(repo / "tests/fixtures/themes/matte-black", themes / "matte-black")
    (themes / ".current").write_text("matte-black\n")
    (themes / ".backgrounds.json").write_text('{"matte-black":"backgrounds/chosen.jpg"}')
    for program, filename, regions in [
        ("borders", "bordersrc", {"extra": "# preserved border extension"}),
        ("yabai", "yabairc", {"signals": "# preserved signals", "rules": "# preserved rules"}),
        ("sketchybar", "sketchybarrc", {"setup": "sketchybar --bar height=35 --load-font example --default icon.font=example", "items": "# preserved items"}),
    ]:
        directory = config / program
        directory.mkdir()
        text = "#!/bin/bash\n"
        for name, content in regions.items():
            text += f"# >>> macarchy:keep {name}\n{content}\n# <<< macarchy:keep\n"
        (directory / filename).write_text(text)
    (config / "yabai/float_state.json").write_text('["System Settings"]')
    environment = dict(os.environ, MACARCHY_HOME=str(home))
    subprocess.run([binary, "migrate"], env=environment, check=True)
    saved = json.loads((root / "settings.json").read_text())
    assert saved["borders"]["border_width"] == 7
    assert saved["borders"]["borders_visible"] is True
    assert saved["layout"]["window_gap"] == 8
    assert saved["currentTheme"] == "matte-black"
    assert saved["floatingApps"] == ["System Settings"]
    assert saved["wallpapers"]["matte-black"] == "backgrounds/chosen.jpg"
    for path in [config / "borders/bordersrc", config / "yabai/yabairc", config / "sketchybar/sketchybarrc"]:
        subprocess.run(["/bin/bash", "-n", path], check=True)
        assert "macarchy\" startup" in path.read_text()
        assert "settings.env" not in path.read_text()
        assert "preserved" in path.read_text()
        assert os.access(path, os.X_OK)
    def contents():
        return {str(path.relative_to(home)): hashlib.sha256(path.read_bytes()).hexdigest()
                for path in home.rglob("*") if path.is_file()}
    before = contents()
    subprocess.run([binary, "migrate"], env=environment, check=True)
    assert before == contents(), "Repeated migration rewrote state or snapshots"
    (root / "settings.json").write_text("invalid JSON")
    result = subprocess.run([binary, "migrate"], env=environment, capture_output=True)
    assert result.returncode != 0
    assert (root / "settings.json").read_text() == "invalid JSON"
print("Migration: settings preserved, custom regions preserved, startup syntax valid, repeat is a no-op, malformed JSON rejected")
