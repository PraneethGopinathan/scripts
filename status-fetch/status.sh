#!/bin/bash

# Define servers and their respective repository paths
declare -A servers
servers=(
    ["dcd-dev"]="user@machine:/path/to/repo"
    ["dcd-stage"]="user@machine:/path/to/repo"
)

# HTML, CSS, and favicon files
# output_file="/home/staticwebsites/Projects/status-fetch/index.html"
output_file="index.html" # give full path if running via cronjob
css_file="styles.css"
favicon_file="favicon.ico"

# Function to create hyperlinks based on the server
hyperlinks() {
    local server=$1
    local commit_id=$2

    local base_url="https://gitlab.com/project"

    if [[ "$server" == "authgenie" || "$server" == "cars-dev" ]]; then
        echo "${base_url}/rmw/dsur-automation/-/commit/${commit_id}"
    else
        echo "${base_url}/disease-context-center/-/commit/${commit_id}"
    fi
}

fetch_service_statuses() {
    # Define URLs for each service
    declare -A service_urls
    service_urls=(
        ["Pubmedsearch"]="https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi"
        ["Arrow"]="changeme"
        ["Metafetcher"]="changeme"
        ["Ontology"]="changeme"
        # add more services
    )

    # Fetch the JSON response
    response=$(curl -s -X 'GET' 'changeme' -H 'accept: application/json')

    # Parse and format the required information using jq
    services=$(echo "$response" | jq -r '.status | to_entries[] | "\(.key): \(.value[0].status_code)"')

    # Append the service statuses to the HTML file
    cat <<EOF >> "$output_file"
    <div class="container">
        <h2>Service Status</h2>
        <div class="services">
EOF

    # Iterate over each service and its status code
    while read -r service; do
        service_name=$(echo "$service" | cut -d':' -f1)
        status_code=$(echo "$service" | cut -d':' -f2)
        color=$( [ "$status_code" -eq 200 ] && echo "green" || echo "red" )

        # Determine the CSS class for the status circle based on the color
        status_circle_class="status-circle-${color}"

        # Get the URL for the service name
        service_url="${service_urls[$service_name]}"

        cat <<EOF >> "$output_file"
            <a href="${service_url}" class="service-button" target="_blank" data-url="${service_url}">
                <span class="status-circle ${status_circle_class}"></span>
                <span class="service-name"><b>$service_name</b></span>
            </a>
EOF
    done <<< "$services"

    # Close the HTML tags for the services container
    cat <<EOF >> "$output_file"
        </div>
    </div>
EOF
}

# Function to create the HTML file
create_html() {
    cat <<EOF > $output_file
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Git Branches and Service Statuses</title>
    <link rel="stylesheet" href="$css_file">
    <link rel="icon" type="image/x-icon" href="$favicon_file">
</head>
<body>
    <div class="container">
        <h2>Current Branches</h2>
        <div class="timer-container" title="Refresh every 10 minutes">
            <div id="countdown"></div>
            <script src="script.js"></script>
        </div>
        <table>
            <tr>
                <th>Server</th>
                <th>Current Branch</th>
                <th>Latest Commit ID</th>
            </tr>
EOF

    # Iterate over each server and get the current Git branch and latest commit ID
    for server in "${!servers[@]}"; do
        # Extract the SSH address and the repository path
        ssh_address=$(echo ${servers[$server]} | cut -d':' -f1)
        repo_path=$(echo ${servers[$server]} | cut -d':' -f2-)

        # Run the SSH command to get the current Git branch
        ssh_output=$(ssh "$ssh_address" "cd $repo_path && git symbolic-ref -q --short HEAD || git describe --tags --exact-match || git rev-parse --short HEAD")

        # Run the SSH command to get the latest commit ID
        full_commit_id=$(ssh "$ssh_address" "cd $repo_path && git rev-parse HEAD")

        # Generate the hyperlink for the full commit ID
        commit_url=$(hyperlinks "$server" "$full_commit_id")

        # Trim the commit ID for display
        trimmed_commit_id=$(echo "$full_commit_id" | cut -c1-7)

        # Append the result to the HTML file
        cat <<EOF >> $output_file
            <tr>
                <td><b>$server</b></td>
                <td>$ssh_output</td>
                <td><a href="$commit_url" target="_blank">$trimmed_commit_id</a></td>
            </tr>
EOF
    done

    # Close the HTML tags for the server branches table
    cat <<EOF >> $output_file
        </table>
    </div>
EOF

    # Fetch and append the service statuses to the HTML file
    fetch_service_statuses

    # Close the main HTML tags
    cat <<EOF >> $output_file
</body>
</html>
EOF
}

create_html
