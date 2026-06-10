#!/bin/bash
set -euo pipefail

timestamp="$(date +"%Y%m%d-%H%M%S")"
home_dir="${HOME:-/root}"
aws_dir="${AWS_DIR:-$home_dir/.aws}"
output_file="$aws_dir/config.sync"
config_file="$aws_dir/config"
credentials_file="$aws_dir/credentials"

default_region="${AWS_REGION:-eu-west-1}"
default_output="${AWS_OUTPUT:-json}"
default_sso_start_url="${AWS_SSO_START_URL:-}"
default_sso_region="${AWS_SSO_REGION:-eu-west-1}"
default_sso_role="${AWS_SSO_ROLE_NAME:-AWSAdministratorAccess}"

prompt() {
    label="$1"
    default_value="$2"
    value=""

    if [ -n "$default_value" ]; then
        read -r -p "$label [$default_value]: " value
    else
        read -r -p "$label: " value
    fi

    if [ -z "$value" ]; then
        value="$default_value"
    fi

    printf '%s\n' "$value"
}

prompt_required() {
    label="$1"
    default_value="$2"
    value=""

    while true; do
        value="$(prompt "$label" "$default_value")"
        if [ -n "$value" ]; then
            printf '%s\n' "$value"
            return 0
        fi
        echo "error: $label is required" >&2
    done
}

prompt_secret() {
    label="$1"
    value=""

    read -r -s -p "$label: " value
    printf '\n' >&2
    printf '%s\n' "$value"
}

require_command() {
    command_name="$1"
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "error: required command not found: $command_name" >&2
        exit 1
    fi
}

backup_file() {
    path="$1"
    if [ -f "$path" ]; then
        cp "$path" "$path.$timestamp"
        echo "backup: $path.$timestamp"
    fi
}

sanitize_profile_name() {
    raw_name="$1"
    fallback="$2"

    sanitized="$(
        printf '%s' "$raw_name" |
            tr ' /' '--' |
            sed 's/[^A-Za-z0-9_.@+=,-]/-/g; s/--*/-/g; s/^-//; s/-$//'
    )"

    if [ -z "$sanitized" ]; then
        sanitized="$fallback"
    fi

    printf '%s\n' "$sanitized"
}

append_profile() {
    profile_name="$1"
    account_id="$2"

    if grep -qx "\\[profile $profile_name\\]" "$output_file" 2>/dev/null; then
        profile_name="$profile_name-$account_id"
    fi

    {
        echo "[profile $profile_name]"
        echo "sso_start_url = $sso_start_url"
        echo "sso_account_id = $account_id"
        echo "output = $aws_output"
        echo "sso_region = $sso_region"
        echo "region = $aws_region"
        echo "sso_role_name = $sso_role_name"
        echo
    } >> "$output_file"

    echo "profile: $profile_name -> $account_id"
}

require_command aws
require_command jq

mkdir -p "$aws_dir"
chmod 700 "$aws_dir" 2>/dev/null || true

echo "AmazonSpiceOx AWS config bootstrap"
echo
echo "This will ask for the access keys of an admin/read account"
echo "that can run: aws organizations list-accounts."
echo

aws_region="$(prompt "AWS default region" "$default_region")"
aws_output="$(prompt "AWS output format" "$default_output")"
sso_start_url="$(prompt_required "AWS SSO start URL" "$default_sso_start_url")"
sso_region="$(prompt "AWS SSO region" "$default_sso_region")"
sso_role_name="$(prompt "AWS SSO role name" "$default_sso_role")"

backup_file "$config_file"
backup_file "$credentials_file"

echo
echo "Running aws configure"
echo "Enter the access key, secret key, region and output for the account"
echo "allowed to list AWS Organizations accounts."
echo
env -u AWS_PROFILE -u AWS_DEFAULT_PROFILE aws configure

configured_access_key="$(env -u AWS_PROFILE -u AWS_DEFAULT_PROFILE aws configure get aws_access_key_id 2>/dev/null || true)"

echo
echo "AWS session token"
echo "Required for temporary STS credentials. Press Enter only for long-lived IAM access keys."
session_token="$(prompt_secret "AWS Session Token")"
if [ -n "$session_token" ]; then
    env -u AWS_PROFILE -u AWS_DEFAULT_PROFILE aws configure set aws_session_token "$session_token"
else
    sed -i '/^[[:space:]]*aws_session_token[[:space:]]*=.*$/d' "$credentials_file" 2>/dev/null || true
fi

echo "Validating default AWS credentials"
if ! env -u AWS_PROFILE -u AWS_DEFAULT_PROFILE aws sts get-caller-identity --output json >/tmp/create-aws-config-identity.json; then
    echo "error: default AWS credentials are not valid." >&2
    case "$configured_access_key" in
        ASIA*)
            echo "hint: STS credentials whose access key starts with ASIA require aws_session_token." >&2
            ;;
        *)
            echo "hint: verify the access key, secret key, region and optional session token." >&2
            ;;
    esac
    echo "hint: if the token is expired, request fresh credentials and rerun this script." >&2
    exit 1
fi

echo "Listing AWS Organizations accounts with default credentials"
if ! accounts_json="$(env -u AWS_PROFILE -u AWS_DEFAULT_PROFILE aws organizations list-accounts --output json)"; then
    echo "error: could not list AWS Organizations accounts." >&2
    echo "hint: make sure the configured credentials can run organizations:ListAccounts." >&2
    exit 1
fi

{
    echo "[default]"
    echo "region = $aws_region"
    echo "output = $aws_output"
    echo
} > "$output_file"

printf '%s\n' "$accounts_json" |
    jq -r '.Accounts[] | [.Id, .Name] | @tsv' |
    while IFS="$(printf '\t')" read -r account_id account_name; do
        profile_name="$(sanitize_profile_name "$account_name" "$account_id")"
        append_profile "$profile_name" "$account_id"
    done

mv "$output_file" "$config_file"
chmod 600 "$config_file" "$credentials_file" 2>/dev/null || true

echo
echo "AWS config created: $config_file"
echo "AWS credentials kept in: $credentials_file"
echo
echo "Next:"
echo "  aws configure list-profiles"
echo "  aws sso login --profile <generated-profile>"
echo "  ssm-powerconnect"
