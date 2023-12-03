update_config() {
    local config_file=$1
    local content=$2
    local marker=${3:-"CUSTOM CONFIGURATION"}
    local start_marker="# START $marker"
    local end_marker="# END $marker"

    # Create a temporary file for the new content
    local temp_file=$(mktemp)
    echo -e "$start_marker\n$content\n$end_marker" > "$temp_file"

    if grep -q "$start_marker" "$config_file"; then
        echo "$marker: Existing configuration found. Removing..."
        sed -i "/$start_marker/,/$end_marker/d" "$config_file"
    fi

    # Ensure there is a newline at the end of the file before appending
    sed -i -e '$a\' "$config_file"
    # Append the new block
    cat "$temp_file" >> "$config_file"
    echo "$marker: Configuration appended"

    rm "$temp_file"
}
