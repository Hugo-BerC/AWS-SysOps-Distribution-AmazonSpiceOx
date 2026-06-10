#!/usr/bin/env sh
set -eu

repo_url="${1:?SSM-PowerConnect repository URL required}"
ref="${2:?SSM-PowerConnect ref required}"
out_dir="${3:?output directory required}"

repo_url="${repo_url%/}"
archive_url="$repo_url/archive/${ref}.tar.gz"
archive_file="$out_dir/source.tar.gz"
tmp_dir="$out_dir.extract"
app_dir="$out_dir/AmazonSpiceOx"
ui_patch_file="${SSM_POWERCONNECT_UI_PATCH_FILE:-configs/ssm-powerconnect/ui-polish.patch}"
aws_profiles_patch_file="${SSM_POWERCONNECT_AWS_PROFILES_PATCH_FILE:-configs/ssm-powerconnect/aws-config-profiles.patch}"
aws_cli_refresh_patch_file="${SSM_POWERCONNECT_AWS_CLI_REFRESH_PATCH_FILE:-configs/ssm-powerconnect/aws-cli-refresh.patch}"
terminal_tabs_patch_file="${SSM_POWERCONNECT_TERMINAL_TABS_PATCH_FILE:-configs/ssm-powerconnect/terminal-tabs.patch}"
responsive_layout_patch_file="${SSM_POWERCONNECT_RESPONSIVE_LAYOUT_PATCH_FILE:-configs/ssm-powerconnect/responsive-layout.patch}"

case "$ui_patch_file" in
    /*)
        ui_patch_path="$ui_patch_file"
        ;;
    *)
        ui_patch_path="$(pwd)/$ui_patch_file"
        ;;
esac

case "$aws_profiles_patch_file" in
    /*)
        aws_profiles_patch_path="$aws_profiles_patch_file"
        ;;
    *)
        aws_profiles_patch_path="$(pwd)/$aws_profiles_patch_file"
        ;;
esac

case "$aws_cli_refresh_patch_file" in
    /*)
        aws_cli_refresh_patch_path="$aws_cli_refresh_patch_file"
        ;;
    *)
        aws_cli_refresh_patch_path="$(pwd)/$aws_cli_refresh_patch_file"
        ;;
esac

case "$terminal_tabs_patch_file" in
    /*)
        terminal_tabs_patch_path="$terminal_tabs_patch_file"
        ;;
    *)
        terminal_tabs_patch_path="$(pwd)/$terminal_tabs_patch_file"
        ;;
esac

case "$responsive_layout_patch_file" in
    /*)
        responsive_layout_patch_path="$responsive_layout_patch_file"
        ;;
    *)
        responsive_layout_patch_path="$(pwd)/$responsive_layout_patch_file"
        ;;
esac

archive_urls="$archive_url"
case "$repo_url" in
    https://github.com/*)
        github_path="${repo_url#https://github.com/}"
        github_path="${github_path%.git}"
        archive_urls="https://codeload.github.com/$github_path/tar.gz/$ref $archive_url"
        ;;
    http://github.com/*)
        github_path="${repo_url#http://github.com/}"
        github_path="${github_path%.git}"
        archive_urls="https://codeload.github.com/$github_path/tar.gz/$ref $archive_url"
        ;;
esac

download_archive() {
    for candidate_url in $archive_urls; do
        echo "Fetching SSM-PowerConnect from $candidate_url"
        rm -f "$archive_file"

        if curl \
            --fail \
            --location \
            --retry 5 \
            --retry-delay 3 \
            --retry-max-time 300 \
            --connect-timeout 30 \
            --output "$archive_file" \
            "$candidate_url"; then
            return 0
        fi

        echo "warning: SSM-PowerConnect fetch failed from $candidate_url; trying next source if available" >&2
    done

    return 1
}

rm -rf "$tmp_dir"
mkdir -p "$out_dir" "$tmp_dir"

if ! download_archive; then
    echo "error: could not fetch SSM-PowerConnect archive after retries" >&2
    exit 1
fi

tar -C "$tmp_dir" -xzf "$archive_file"

top_dir="$(find "$tmp_dir" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
if [ -z "$top_dir" ]; then
    echo "error: archive did not contain a top-level directory" >&2
    exit 1
fi

src_app_dir="$top_dir/AmazonSpiceOx"
if [ ! -d "$src_app_dir" ]; then
    echo "error: archive does not contain AmazonSpiceOx/" >&2
    exit 1
fi

if [ -e "$app_dir" ] && [ ! -w "$app_dir" ]; then
    echo "error: cannot replace existing SSM-PowerConnect app directory: $app_dir" >&2
    echo "hint: it may be owned by root from a previous sudo build" >&2
    echo "hint: run sudo chown -R \"\$USER:\$USER\" \"$out_dir\" and retry make fetch" >&2
    exit 1
fi

if ! rm -rf "$app_dir"; then
    echo "error: could not remove existing SSM-PowerConnect app directory: $app_dir" >&2
    echo "hint: fix ownership with sudo chown -R \"\$USER:\$USER\" \"$out_dir\" and retry" >&2
    exit 1
fi

mkdir -p "$app_dir"
cp -a "$src_app_dir/." "$app_dir/"

for required_file in ssm_powerconnect.py skin.jpg requirements.txt run.sh README.md; do
    if [ ! -f "$app_dir/$required_file" ]; then
        echo "error: missing AmazonSpiceOx/$required_file in SSM-PowerConnect archive" >&2
        exit 1
    fi
done

chmod 0755 "$app_dir/run.sh" 2>/dev/null || true

if [ -f "$ui_patch_path" ]; then
    if ! command -v patch >/dev/null 2>&1; then
        echo "error: patch is required to apply $ui_patch_path" >&2
        exit 1
    fi

    echo "Applying AmazonSpiceOx SSM-PowerConnect UI patch"
    (
        cd "$app_dir"
        patch -p1 < "$ui_patch_path"
    )
fi

if [ -f "$aws_profiles_patch_path" ]; then
    if ! command -v patch >/dev/null 2>&1; then
        echo "error: patch is required to apply $aws_profiles_patch_path" >&2
        exit 1
    fi

    echo "Applying AmazonSpiceOx SSM-PowerConnect AWS profile patch"
    (
        cd "$app_dir"
        patch -p1 < "$aws_profiles_patch_path"
    )
fi

if [ -f "$aws_cli_refresh_patch_path" ]; then
    if ! command -v patch >/dev/null 2>&1; then
        echo "error: patch is required to apply $aws_cli_refresh_patch_path" >&2
        exit 1
    fi

    echo "Applying AmazonSpiceOx SSM-PowerConnect AWS CLI refresh patch"
    (
        cd "$app_dir"
        patch -p1 < "$aws_cli_refresh_patch_path"
    )
fi

if [ -f "$terminal_tabs_patch_path" ]; then
    if ! command -v patch >/dev/null 2>&1; then
        echo "error: patch is required to apply $terminal_tabs_patch_path" >&2
        exit 1
    fi

    echo "Applying AmazonSpiceOx SSM-PowerConnect terminal tabs patch"
    (
        cd "$app_dir"
        patch -p1 < "$terminal_tabs_patch_path"
    )
fi

if [ -f "$responsive_layout_patch_path" ]; then
    if ! command -v patch >/dev/null 2>&1; then
        echo "error: patch is required to apply $responsive_layout_patch_path" >&2
        exit 1
    fi

    echo "Applying AmazonSpiceOx SSM-PowerConnect responsive layout patch"
    (
        cd "$app_dir"
        patch -p1 < "$responsive_layout_patch_path"
    )
fi

rm -rf "$tmp_dir"

echo "SSM-PowerConnect ready at $app_dir"
