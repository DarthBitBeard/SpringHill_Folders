#!/usr/bin/env bash
# SpringHill Folders: Folding@home Linux setup (Team 1068033)
#
# Review this file before running it. Download it, read it, then run the
# local copy with sudo. Do not pipe remote content into a shell.
#
# What this script does:
#   1. Installs the Folding@home client only if it is missing, and only
#      from a package you supply. By default it downloads nothing.
#      Give a local package with --package, or an explicit https package
#      URL with --package-url. Otherwise it prints the official download
#      instructions and stops.
#   2. Creates /etc/fah-client/config.xml only when no config exists.
#      After a fresh install it waits briefly for the client to create
#      its own config first. If a config already exists, it is left
#      alone unless you pass --force-config, and it is never rewritten
#      when it already contains a passkey or account token. When an
#      edit is needed, a timestamped backup is made first and the edit
#      is written to a temporary file and only moved into place when
#      it actually differs. An existing username is never overwritten.
#      This script never writes, changes, or prints a passkey or
#      account token.
#   3. Enables and restarts the fah-client systemd service when the
#      config was created or changed. It never force stops processes.
#
# The recommended path for most people is still the official installer
# plus Web Control at https://app.foldingathome.org . Use this script
# only when you want the team setting applied automatically on a fresh
# machine or across several machines you manage.
#
# After running it, set a passkey in Web Control if you want Quick Return
# Bonus points. A passkey is different from an account passphrase. See
# https://foldingathome.org/faq/stats
#
# Usage:
#   sudo ./install.sh --help
#   sudo ./install.sh --dry-run
#   sudo ./install.sh
#   sudo ./install.sh --package ./fah-client_8.5.6_amd64.deb
#   sudo ./install.sh --package-url https://example.invalid/fah-client.deb --yes
#   sudo ./install.sh --force-config
#
# Supported: Debian and Ubuntu (.deb), Fedora, RHEL and derivatives (.rpm),
# and openSUSE (.rpm). Other systems: install manually from
# https://foldingathome.org/download and set the team in Web Control.

set -euo pipefail
IFS=$'\n\t'

TEAM_ID="1068033"
USER_NAME="anonymous"
IDLE_VALUE="true"
PACKAGE_PATH=""
PACKAGE_URL=""
FORCE_CONFIG=0
ASSUME_YES=0
DRY_RUN=0
CONFIG_PATH="/etc/fah-client/config.xml"
WEB_CONTROL_URL="https://app.foldingathome.org"
TMP_DIR=""

usage() {
    cat <<'EOF'
Usage: sudo ./install.sh [options]

Options:
  --team NUMBER        Folding@home team number (default: 1068033)
  --user NAME          Username, used only when no username is configured
                       (default: anonymous; letters, numbers, underscores)
  --idle               Fold only when idle (default for a new config)
  --no-idle            Do not set idle only for a new config
  --package PATH       Local .deb or .rpm package to install
  --package-url URL     Explicit https URL of a .deb or .rpm package
  --force-config       Edit an existing config that has no passkey or
                       account token, to set the team number
  --yes                Skip the download confirmation prompt
  --dry-run            Show what would happen and exit without changing
                       anything
  --help               Show this help and exit

By default, if the client is not installed and no package is given, this
script stops with the official download instructions. It never invents
a package version or URL.
EOF
}

die() {
    echo "Error: $*" >&2
    exit 1
}

cleanup() {
    if [ -n "${TMP_DIR:-}" ] && [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT

while [ $# -gt 0 ]; do
    case "$1" in
        --team)
            [ $# -ge 2 ] || die "--team needs a value"
            TEAM_ID="$2"; shift 2 ;;
        --user)
            [ $# -ge 2 ] || die "--user needs a value"
            USER_NAME="$2"; shift 2 ;;
        --idle)
            IDLE_VALUE="true"; shift ;;
        --no-idle)
            IDLE_VALUE="false"; shift ;;
        --package)
            [ $# -ge 2 ] || die "--package needs a path"
            PACKAGE_PATH="$2"; shift 2 ;;
        --package-url)
            [ $# -ge 2 ] || die "--package-url needs a URL"
            PACKAGE_URL="$2"; shift 2 ;;
        --force-config)
            FORCE_CONFIG=1; shift ;;
        --yes|-y)
            ASSUME_YES=1; shift ;;
        --dry-run)
            DRY_RUN=1; shift ;;
        --help|-h)
            usage; exit 0 ;;
        *)
            die "Unknown option: $1 (try --help)" ;;
    esac
done

case "$TEAM_ID" in
    ''|*[!0-9]*) die "Team number must be digits only: $TEAM_ID" ;;
esac

case "$USER_NAME" in
    ''|*[!A-Za-z0-9_]*) die "Username must use letters, numbers, and underscores only: $USER_NAME" ;;
esac

if [ -n "$PACKAGE_PATH" ] && [ -n "$PACKAGE_URL" ]; then
    die "Use only one of --package or --package-url."
fi

# Note: the root check is after the --dry-run block below, so a dry run
# can be previewed without sudo. Real installs and config changes need root.

# Detect the package family from /etc/os-release. Fail clearly elsewhere.
FAMILY=""
if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-} ${ID_LIKE:-}" in
        *debian*|*ubuntu*) FAMILY="deb" ;;
        *fedora*|*rhel*|*centos*|*rocky*|*alma*) FAMILY="rpm" ;;
        *suse*|*opensuse*) FAMILY="rpm-suse" ;;
        *) FAMILY="" ;;
    esac
fi
[ -n "$FAMILY" ] || die "Unsupported system. Install manually from https://foldingathome.org/download and set team $TEAM_ID in Web Control at $WEB_CONTROL_URL"

is_installed() {
    if command -v fah-client >/dev/null 2>&1; then
        return 0
    fi
    if [ "$FAMILY" = "deb" ] && command -v dpkg >/dev/null 2>&1 && dpkg -s fah-client >/dev/null 2>&1; then
        return 0
    fi
    if { [ "$FAMILY" = "rpm" ] || [ "$FAMILY" = "rpm-suse" ]; } && command -v rpm >/dev/null 2>&1 && rpm -q fah-client >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

install_package() {
    local pkg="$1"
    case "$FAMILY" in
        deb)
            case "$pkg" in
                *.deb) ;;
                *) die "Expected a .deb package on this system: $pkg" ;;
            esac
            echo "Installing .deb package with apt (this resolves dependencies)..."
            apt-get update
            apt-get install -y "$pkg"
            ;;
        rpm)
            case "$pkg" in
                *.rpm) ;;
                *) die "Expected a .rpm package on this system: $pkg" ;;
            esac
            echo "Installing .rpm package with dnf..."
            dnf install -y "$pkg"
            ;;
        rpm-suse)
            case "$pkg" in
                *.rpm) ;;
                *) die "Expected a .rpm package on this system: $pkg" ;;
            esac
            echo "Installing .rpm package with zypper..."
            zypper --non-interactive install "$pkg"
            ;;
    esac
}

echo "SpringHill Folders: Folding@home Linux setup (Team $TEAM_ID)"
echo "Web Control: $WEB_CONTROL_URL"

if [ "$DRY_RUN" -eq 1 ]; then
    echo "Dry run only. Nothing will be installed or changed."
    echo "System family: $FAMILY"
    if is_installed; then
        echo "Client: already installed, would skip download and install."
    elif [ -n "$PACKAGE_PATH" ]; then
        echo "Client: missing, would install local package: $PACKAGE_PATH"
    elif [ -n "$PACKAGE_URL" ]; then
        echo "Client: missing, would download and install: $PACKAGE_URL"
    else
        echo "Client: missing, would stop with official download instructions."
    fi
    if [ -f "$CONFIG_PATH" ]; then
        echo "Config: exists at $CONFIG_PATH, would be left unchanged without --force-config, and never rewritten if it has a passkey or account token."
    else
        echo "Config: missing, would create a minimal config at $CONFIG_PATH (user: $USER_NAME, team: $TEAM_ID, idle: $IDLE_VALUE)."
    fi
    exit 0
fi

JUST_INSTALLED=0
if [ "$(id -u)" -ne 0 ]; then
    die "Run this script with sudo, from a local copy you have reviewed."
fi
if ! is_installed; then
    if [ -n "$PACKAGE_PATH" ]; then
        [ -f "$PACKAGE_PATH" ] || die "Package file not found: $PACKAGE_PATH"
        # Use an absolute path so apt/dnf/zypper treat it as a local file.
        case "$PACKAGE_PATH" in
            /*) PKG_ABS="$PACKAGE_PATH" ;;
            *) PKG_ABS="$(pwd)/$PACKAGE_PATH" ;;
        esac
        install_package "$PKG_ABS"
    elif [ -n "$PACKAGE_URL" ]; then
        case "$PACKAGE_URL" in
            https://*.deb|https://*.rpm) ;;
            *) die "--package-url must be an https URL ending in .deb or .rpm" ;;
        esac
        if [ "$ASSUME_YES" -ne 1 ]; then
            if [ -t 0 ]; then
                read -r -p "Download and install $PACKAGE_URL ? Type yes to continue: " answer
                [ "$answer" = "yes" ] || die "Download cancelled. Download the package yourself from https://foldingathome.org/download and rerun with --package."
            else
                die "Non-interactive download requires --yes. Download the package yourself from https://foldingathome.org/download and rerun with --package."
            fi
        fi
        command -v curl >/dev/null 2>&1 || die "curl is required to download a package URL. Install curl, or download the package yourself."
        TMP_DIR="$(mktemp -d)"
        PKG_FILE="$TMP_DIR/$(basename "$PACKAGE_URL")"
        echo "Downloading package..."
        curl -fL -- "$PACKAGE_URL" -o "$PKG_FILE"
        PKG_SIZE="$(wc -c < "$PKG_FILE" | tr -d ' ')"
        if [ "$PKG_SIZE" -lt 1000000 ]; then
            die "Downloaded package looks too small ($PKG_SIZE bytes). Delete it and download from https://foldingathome.org/download instead."
        fi
        install_package "$PKG_FILE"
    else
        cat >&2 <<EOF
Folding@home does not appear to be installed, and no package was given.
Download the installer from https://foldingathome.org/download , then rerun with:
  sudo ./install.sh --package ./<downloaded package file>
Or rerun with an explicit package URL:
  sudo ./install.sh --package-url https://<official package URL> --yes
See the v8.5 guide: https://foldingathome.org/guides/v8-5
EOF
        exit 1
    fi
    echo "Install finished."
    JUST_INSTALLED=1
else
    echo "Folding@home client already installed. Skipping download and install."
fi

# Configure, preserving any existing identity. Never touch secrets.
CONFIG_CHANGED=0
BACKUP_PATH=""
CONFIG_OUTCOME="was not set by this script. Set the team in Web Control."

# If the client was just installed, give it a short time to create its own
# config on first run before this script creates one.
if [ "$JUST_INSTALLED" -eq 1 ] && [ ! -f "$CONFIG_PATH" ]; then
    echo "Waiting briefly for the newly installed client to create its config..."
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
        if [ -f "$CONFIG_PATH" ]; then
            break
        fi
        sleep 2
    done
fi

if [ -f "$CONFIG_PATH" ]; then
    if grep -q -E "passkey|account-token" "$CONFIG_PATH"; then
        echo "A passkey or account token is already configured. It will be preserved."
        echo "This script will not rewrite this config. Set the team in Web Control if needed: $WEB_CONTROL_URL"
        CONFIG_OUTCOME="was not changed because it already contains a passkey or account token. Set the team in Web Control if needed."
    elif [ "$FORCE_CONFIG" -ne 1 ]; then
        echo "An existing config was found and left unchanged."
        echo "Set the team in Web Control if needed, or rerun with --force-config to set the team here."
        echo "Existing config: $CONFIG_PATH"
        CONFIG_OUTCOME="was left unchanged. Set the team in Web Control, or rerun with --force-config."
    else
        command -v python3 >/dev/null 2>&1 || die "python3 is required to edit an existing config safely. Set the team in Web Control instead."
        echo "Checking whether the existing config needs a team change, preserving all other settings..."
        TMP_CONFIG="$(mktemp)"
        if ! python3 - "$CONFIG_PATH" "$TMP_CONFIG" "$TEAM_ID" "$USER_NAME" "$IDLE_VALUE" <<'PYEOF'
import sys
import xml.etree.ElementTree as ET

src, dst, team, user, idle = sys.argv[1:6]
tree = ET.parse(src)
root = tree.getroot()
if root.tag != "config":
    raise SystemExit("Config root is not <config>; refusing to edit.")

def set_value(name, value, only_if_missing=False):
    node = root.find(name)
    if node is None:
        node = ET.SubElement(root, name)
        node.set("v", value)
        return "added"
    if only_if_missing:
        return "kept"
    if node.get("v") == value:
        return "kept"
    node.set("v", value)
    return "updated"

team_result = set_value("team", team)
user_result = set_value("user", user, only_if_missing=True)
idle_result = set_value("idle", idle)
print(f"team: {team_result}, user: {user_result}, idle: {idle_result}")
tree.write(dst, encoding="utf-8", xml_declaration=True)
PYEOF
        then
            rm -f "$TMP_CONFIG"
            die "Could not edit the existing config safely. The original file was not changed. Set the team in Web Control instead."
        fi
        if cmp -s "$CONFIG_PATH" "$TMP_CONFIG"; then
            rm -f "$TMP_CONFIG"
            echo "Config already set for this team. No change was made."
            CONFIG_OUTCOME="already set for team $TEAM_ID in $CONFIG_PATH. No change was made."
        else
            STAMP="$(date +%Y%m%d-%H%M%S)"
            BACKUP_PATH="${CONFIG_PATH}.bak.${STAMP}"
            cp -- "$CONFIG_PATH" "$BACKUP_PATH"
            echo "Backed up existing config to: $BACKUP_PATH"
            mv -- "$TMP_CONFIG" "$CONFIG_PATH"
            chmod 0644 "$CONFIG_PATH"
            CONFIG_CHANGED=1
            CONFIG_OUTCOME="set to team $TEAM_ID in $CONFIG_PATH. A backup was kept at $BACKUP_PATH."
            echo "Config updated: $CONFIG_PATH"
        fi
    fi
else
    echo "No config found. Creating a minimal config: $CONFIG_PATH"
    mkdir -p /etc/fah-client
    cat > "$CONFIG_PATH" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<config>
  <user v="$USER_NAME"/>
  <team v="$TEAM_ID"/>
  <idle v="$IDLE_VALUE"/>
</config>
EOF
    chmod 0644 "$CONFIG_PATH"
    CONFIG_CHANGED=1
    CONFIG_OUTCOME="set to team $TEAM_ID in new config $CONFIG_PATH (user: $USER_NAME, idle: $IDLE_VALUE)."
    echo "Created minimal config (user: $USER_NAME, team: $TEAM_ID, idle: $IDLE_VALUE)."
    echo "Set a passkey and any other preferences in Web Control. This script never writes a passkey."
fi

if [ "$CONFIG_CHANGED" -eq 1 ]; then
    if systemctl cat fah-client.service >/dev/null 2>&1; then
        echo "Enabling and restarting the fah-client service..."
        systemctl enable fah-client
        systemctl restart fah-client
        echo "Service state: $(systemctl is-active fah-client || true)"
    else
        echo "No fah-client service was found. If the client is already running, restart it from Web Control or restart the computer."
    fi
fi

echo ""
echo "Done. Team $CONFIG_OUTCOME"
echo "Open Web Control to check folding and add a passkey: $WEB_CONTROL_URL"
echo "Passkey help: https://foldingathome.org/faq/stats"
