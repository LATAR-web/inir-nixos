#!/usr/bin/env python3
"""Adapt the iNiR shell to NixOS at build time.

iNiR targets Arch: it looks for icons under /usr/share/icons, shells out to
/usr/bin/find, and only knows how to find its own payload from a handful of
system paths. NixOS has none of those.

These edits are deliberately written as regex rewrites rather than a diff with
context, because a context patch stops applying the moment upstream touches an
adjacent line — that is exactly what broke the previous build. Each rewrite is
idempotent and self-skipping: if upstream ever ships the same fix, this notices
and leaves the file alone instead of failing the build.
"""

import os
import re
import sys

# Everything the store mounts for the running system. Populated by the NixOS
# module, which symlinks /usr/share/icons and /usr/share/quickshell here.
NIXOS_STORE = "/run/current-system/sw"


def apply(text, name, pattern, replacement, *, already, required=True, flags=re.M):
    """Rewrite `pattern` once. Skip cleanly when `already` shows it is applied."""
    if re.search(already, text, flags):
        print(f"  = {name}: already applied upstream, leaving as-is")
        return text, True

    new_text, count = re.subn(pattern, replacement, text, flags=flags)
    if count == 0:
        print(f"  ! {name}: no match")
        if required:
            print(
                f"postpatch: '{name}' is required for a working NixOS build but "
                f"upstream no longer matches it. Re-anchor this regex in "
                f"nix/nixos-postpatch.py."
            )
            sys.exit(1)
        return text, False

    print(f"  + {name}")
    return new_text, True


def patch_icon_theme(text):
    """Icon themes must resolve on NixOS, where the icon theme lives in the store."""
    # For every "~/.local/share/icons/<theme>/<rest>" entry, add the ~/.icons and
    # the system-store equivalents; likewise for the /usr/share one.
    def expand_home(match):
        indent, rest = match.group(1), match.group(2)
        return (
            match.group(0)
            + f"\n{indent}`file://${{home}}/.icons/${{theme}}/{rest}`,"
            + f"\n{indent}`file://{NIXOS_STORE}/share/icons/${{theme}}/{rest}`,"
        )

    text, _ = apply(
        text,
        "IconThemeService: ~/.icons + system store search paths",
        r"^([ \t]*)`file://\$\{home\}/\.local/share/icons/\$\{theme\}/([^`]+)`,[ \t]*$",
        expand_home,
        already=r"`file://\$\{home\}/\.icons/\$\{theme\}/",
        flags=re.M,
    )

    # 48x48 is what many distro themes ship at; without it icons fall back to a
    # generic glyph.
    if "`48x48/apps/${iconName}.svg`" not in text:
        entries = []
        for suffix in ("svg", "png"):
            for root in (
                f"file://${{home}}/.local/share/icons/${{theme}}",
                f"file://${{home}}/.icons/${{theme}}",
                f"file://{NIXOS_STORE}/share/icons/${{theme}}",
                "file:///usr/share/icons/${theme}",
            ):
                entries.append(f"            `{root}/48x48/apps/${{iconName}}.{suffix}`,")
        block = "\n".join(entries)
        text, _ = apply(
            text,
            "IconThemeService: 48x48 icon entries",
            r"^([ \t]*`file:///usr/share/icons/\$\{theme\}/256x256/apps/\$\{iconName\}\.png`,[ \t]*)$",
            rf"\1\n{block}",
            already=r"`48x48/apps/\$\{iconName\}\.svg`",
            required=False,
        )

    # `find` must come from PATH, and it has to walk the store icon directory too.
    # -xtype follows symlinks, which is how /usr/share/icons reaches the store.
    text, _ = apply(
        text,
        "IconThemeService: find-based theme scan",
        re.escape('            "/usr/bin/find",\n')
        + re.escape('            "/usr/share/icons",\n')
        + re.escape("            `${FileUtils.trimFileProtocol(Directories.home)}/.local/share/icons`,\n")
        + re.escape('            "-maxdepth",\n')
        + re.escape('            "1",\n')
        + re.escape('            "-type",\n')
        + re.escape('            "d"'),
        "\n".join(
            [
                '            "find",',
                "            `${FileUtils.trimFileProtocol(Directories.home)}/.local/share/icons`,",
                "            `${FileUtils.trimFileProtocol(Directories.home)}/.icons`,",
                f'            "{NIXOS_STORE}/share/icons",',
                '            "/usr/share/icons",',
                '            "-maxdepth",',
                '            "1",',
                '            "-mindepth",',
                '            "1",',
                '            "-xtype",',
                '            "d"',
            ]
        ),
        already=r'"-xtype",',
        required=False,
    )

    # NOTE: an earlier revision also forced the theme list to be rescanned at the top of
    # ensureInitialized(), before the `_initialized` guard. Upstream 2.33.0 already
    # rescans it once per initialization, and the Process chains run
    # listThemesProc -> gsettingsSetProc -> kdeGlobalsUpdateProc -> kwriteconfigProc.
    # Restarting that chain before the guard made every call re-fire it, which fought
    # the shell during a family switch. Upstream's own single refresh is left alone.

    return text


def patch_family_transition(text):
    """Let the animated family transition run on Qt 6.11, behind an opt-in.

    Qt 6.11 can segfault while tearing down layer-shell surfaces, so upstream
    skips the animated family transition there and restarts the shell instead.
    That is the right default, but it means the transition never plays on the
    Qt that nixpkgs currently ships (6.11.2), so the family switch just blinks.

    Gating the guard behind an env var keeps opting in a config change rather
    than a patch, and records what was traded away.
    """
    text, _ = apply(
        text,
        "shell.qml: make the Qt 6.11 family-transition bail-out opt-in",
        re.escape(
            "        const qt611LayerShellRisk = Quickshell.hasQtVersion(6, 11)\n"
            "            && !Quickshell.hasQtVersion(6, 12)\n"
        ),
        '        const qt611LayerShellRisk = '
        'Quickshell.env("INIR_FAMILY_ANIMATION_ON_QT611") !== "1"\n'
        "            && Quickshell.hasQtVersion(6, 11)\n"
        "            && !Quickshell.hasQtVersion(6, 12)\n",
        already=r"INIR_FAMILY_ANIMATION_ON_QT611",
        required=False,
    )
    return text


def patch_launcher(text):
    """The launcher must find its payload inside the read-only store."""
    text, _ = apply(
        text,
        "scripts/inir: system store payload fallback",
        re.escape(
            '    for candidate in "$user_config_dir" "$system_config_dir" '
            '"$fallback_system_config_dir"; do'
        ),
        "    for candidate in \"$user_config_dir\" \"$system_config_dir\" "
        '"$fallback_system_config_dir" '
        f'"{NIXOS_STORE}/share/quickshell/inir"; do',
        already=re.escape(f'"{NIXOS_STORE}/share/quickshell/inir"; do'),
    )
    return text


def patch_record_script(text):
    """Probe hardware video encoders before selecting them, avoiding failed VAAPI startup.

    Upstream detects VAAPI support merely by checking if a render device exists
    and ffmpeg lists h264_vaapi. In VMs and systems without functional VAAPI
    drivers, wf-recorder fails immediately upon launch with 'Failed to initialise
    VAAPI connection', forcing an error notification ('Preferred encoder failed,
    retrying with safe mode') before falling back to libx264.

    By probing actual encoder functionality via a lightweight 0.05s test command,
    we cleanly select libx264 as preferred on non-VAAPI hardware and never trigger
    the fallback failure notification.
    """
    original_detect = """detect_hw_video_codec() {
    # Nvidia: skip VAAPI (unreliable even if ffmpeg lists it), go straight to NVENC
    if is_nvidia_gpu; then
        if has_ffmpeg_encoder h264_nvenc; then
            printf '%s\\n' 'h264_nvenc'
            return
        fi
        if has_ffmpeg_encoder hevc_nvenc; then
            printf '%s\\n' 'hevc_nvenc'
            return
        fi
    fi
    # AMD/Intel: try VAAPI (needs render device)
    if [[ -n "$HARDWARE_DEVICE" && -c "$HARDWARE_DEVICE" ]]; then
        if has_ffmpeg_encoder h264_vaapi; then
            printf '%s\\n' 'h264_vaapi'
            return
        fi
        if has_ffmpeg_encoder hevc_vaapi; then
            printf '%s\\n' 'hevc_vaapi'
            return
        fi
    fi
    # Fallback: try NVENC anyway (hybrid GPU setups)
    if has_ffmpeg_encoder h264_nvenc; then
        printf '%s\\n' 'h264_nvenc'
        return
    fi
    printf '%s\\n' 'libx264'
}"""

    replacement_detect = """can_test_encoder() {
    local codec="$1"
    local dev="${2:-}"
    if [[ "$codec" == *"_vaapi" ]]; then
        [[ -n "$dev" && -c "$dev" ]] || return 1
        ffmpeg -loglevel error -f lavfi -i color=c=black:s=64x64:d=0.04 -vaapi_device "$dev" -vf 'format=nv12,hwupload' -c:v "$codec" -f null - >/dev/null 2>&1
    elif [[ "$codec" == *"_nvenc" ]]; then
        ffmpeg -loglevel error -f lavfi -i color=c=black:s=64x64:d=0.04 -c:v "$codec" -f null - >/dev/null 2>&1
    else
        has_ffmpeg_encoder "$codec"
    fi
}

detect_hw_video_codec() {
    # Nvidia: skip VAAPI (unreliable even if ffmpeg lists it), go straight to NVENC
    if is_nvidia_gpu; then
        if can_test_encoder h264_nvenc; then
            printf '%s\\n' 'h264_nvenc'
            return
        fi
        if can_test_encoder hevc_nvenc; then
            printf '%s\\n' 'hevc_nvenc'
            return
        fi
    fi
    # AMD/Intel: try VAAPI (needs verified working render device)
    if [[ -n "$HARDWARE_DEVICE" && -c "$HARDWARE_DEVICE" ]]; then
        if can_test_encoder h264_vaapi "$HARDWARE_DEVICE"; then
            printf '%s\\n' 'h264_vaapi'
            return
        fi
        if can_test_encoder hevc_vaapi "$HARDWARE_DEVICE"; then
            printf '%s\\n' 'hevc_vaapi'
            return
        fi
    fi
    # Fallback: try NVENC anyway (hybrid GPU setups)
    if can_test_encoder h264_nvenc; then
        printf '%s\\n' 'h264_nvenc'
        return
    fi
    printf '%s\\n' 'libx264'
}"""

    text, _ = apply(
        text,
        "scripts/videos/record.sh: probe hardware encoder before selecting",
        re.escape(original_detect),
        replacement_detect,
        already=r"can_test_encoder\(\)",
        required=False,
    )

    vaapi_guard = """if is_vaapi_codec "$VIDEO_CODEC"; then
    if ! can_test_encoder "$VIDEO_CODEC" "$HARDWARE_DEVICE"; then
        VIDEO_CODEC="libx264"
    fi"""

    text, _ = apply(
        text,
        "scripts/videos/record.sh: validate configured VAAPI codec before launch",
        re.escape('if is_vaapi_codec "$VIDEO_CODEC"; then'),
        vaapi_guard,
        already=r'if ! can_test_encoder "\$VIDEO_CODEC"',
        required=False,
    )

    return text


def patch_root_qml():

    """Strip /usr/bin/ from QML and JS anywhere in the tree.

    package.nix already rewrites these paths, but only under
    modules/, services/, defaults/ and scripts/. The top-level QML
    (killDialog.qml, welcome.qml) sits outside those directories and would
    keep absolute /usr/bin/pidof, /usr/bin/killall and /usr/bin/notify-send,
    none of which exist on NixOS.

    Shebangs are untouched because .qml and .js files never carry one.
    """
    changed = []
    for dirpath, _dirnames, filenames in os.walk("."):
        if "/.git" in dirpath:
            continue
        for filename in filenames:
            if not filename.endswith((".qml", ".js")):
                continue
            path = os.path.join(dirpath, filename)
            with open(path, encoding="utf-8") as handle:
                original = handle.read()
            patched = original.replace("/usr/bin/", "")
            if patched != original:
                with open(path, "w", encoding="utf-8") as handle:
                    handle.write(patched)
                changed.append(path)

    print(
        f"  + /usr/bin/ stripped from {len(changed)} top-level QML/JS file(s)"
        if changed
        else "  = /usr/bin/ in QML/JS: already handled upstream, leaving as-is"
    )
    return changed


PATCHES = {
    "services/IconThemeService.qml": patch_icon_theme,
    "shell.qml": patch_family_transition,
    "scripts/inir": patch_launcher,
    "scripts/videos/record.sh": patch_record_script,
}



def main():
    applied, skipped = [], []

    for path, patch in PATCHES.items():
        print(f"postpatch: {path}")
        try:
            with open(path, encoding="utf-8") as handle:
                original = handle.read()
        except FileNotFoundError:
            print("  ! missing, skipped")
            skipped.append(path)
            continue

        patched = patch(original)
        if patched != original:
            with open(path, "w", encoding="utf-8") as handle:
                handle.write(patched)
            applied.append(path)
        else:
            skipped.append(path)

    print("postpatch: tree-wide")
    applied += patch_root_qml()

    print(f"postpatch: {len(applied)} file(s) adapted, {len(skipped)} unchanged")
    if not applied:
        print("postpatch: nothing to do (upstream may already be NixOS-ready)")


if __name__ == "__main__":
    main()