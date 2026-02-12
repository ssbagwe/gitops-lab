#!/usr/bin/env bash
set -euo pipefail

# sync-versions.sh - Dynamically sync tool versions from Dockerfile to README.md
# Reads all ARG *_VERSION variables and updates the README table

DOCKERFILE=".devcontainer/Dockerfile"
README="README.md"

# Check if files exist
if [[ ! -f "$DOCKERFILE" ]]; then
    echo "Error: $DOCKERFILE not found"
    exit 1
fi

if [[ ! -f "$README" ]]; then
    echo "Error: $README not found"
    exit 1
fi

# Default descriptions for common tools
declare -A DESCRIPTIONS=(
    ["kubectl"]="K8s CLI"
    ["helm"]="Package manager"
    ["kind"]="Local K8s clusters"
    ["k9s"]="Terminal UI"
    ["terraform"]="Infrastructure as Code"
    ["argocd"]="GitOps CD"
    ["kustomize"]="K8s config management"
    ["krew"]="kubectl plugin manager"
    ["stern"]="Log tailing"
    ["go"]="For operators/tools"
    ["awscli"]="AWS CLI"
)

# Extract existing descriptions from README to preserve custom ones
declare -A existing_descriptions
while IFS='|' read -r _ tool _ version _ description _; do
    # Trim whitespace
    tool=$(echo "$tool" | xargs)
    description=$(echo "$description" | xargs)
    if [[ -n "$tool" && "$tool" != "Tool" ]]; then
        existing_descriptions["$tool"]="$description"
    fi
done < <(sed -n '/^| Tool | Version | Purpose |$/,/^$/p' "$README" | tail -n +3)

# Extract all *_VERSION ARGs from Dockerfile
declare -A versions
while IFS='=' read -r arg value; do
    # Extract tool name from ARG name (e.g., KUBECTL_VERSION -> kubectl, K9S_VERSION -> k9s)
    if [[ "$arg" =~ ^ARG\ ([A-Z0-9_]+)_VERSION$ ]]; then
        tool_upper="${BASH_REMATCH[1]}"
        tool=$(echo "$tool_upper" | tr '[:upper:]' '[:lower:]')
        versions["$tool"]="$value"
    fi
done < <(grep -E '^ARG [A-Z0-9_]+_VERSION=' "$DOCKERFILE")

# Add awscli if it's installed (it doesn't have a VERSION ARG)
if grep -q "awscli.amazonaws.com" "$DOCKERFILE"; then
    versions["awscli"]="v2"
fi

# Build the new table
table_lines=()
table_lines+=("| Tool | Version | Purpose |")
table_lines+=("|------|---------|---------|")

# Sort tools alphabetically for consistent output
readarray -t sorted_tools < <(printf '%s\n' "${!versions[@]}" | sort)

for tool in "${sorted_tools[@]}"; do
    version="${versions[$tool]}"

    # Use existing description if available, otherwise use default, otherwise generic
    if [[ -n "${existing_descriptions[$tool]:-}" ]]; then
        description="${existing_descriptions[$tool]}"
    elif [[ -n "${DESCRIPTIONS[$tool]:-}" ]]; then
        description="${DESCRIPTIONS[$tool]}"
    else
        description="Tool"
    fi

    table_lines+=("| $tool | $version | $description |")
done

# Create temp file
TMP_FILE=$(mktemp)
trap 'rm -f "$TMP_FILE"' EXIT

# Replace the table in README
awk -v table="$(printf '%s\n' "${table_lines[@]}")" '
    BEGIN { in_table = 0; table_printed = 0 }

    # Detect start of table
    /^\| Tool \| Version \| Purpose \|$/ {
        if (!table_printed) {
            print table
            table_printed = 1
            in_table = 1
        }
        next
    }

    # Skip table header separator
    /^\|------\|/ && in_table { next }

    # Skip table rows
    /^\| [^ ]+ \|/ && in_table { next }

    # Detect end of table (empty line or non-table line)
    in_table && !/^\|/ {
        in_table = 0
        print
        next
    }

    # Print all other lines
    !in_table { print }
' "$README" > "$TMP_FILE"

# Check if anything changed
if ! diff -q "$README" "$TMP_FILE" > /dev/null 2>&1; then
    cp "$TMP_FILE" "$README"
    echo "✓ Updated $README with versions from $DOCKERFILE"
    for tool in "${sorted_tools[@]}"; do
        echo "  $tool: ${versions[$tool]}"
    done
    exit 1  # Exit 1 to signal pre-commit that file was modified
else
    echo "✓ $README versions are already in sync"
    exit 0
fi
