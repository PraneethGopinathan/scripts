#!/bin/bash

# Function to show help
show_help() {
    cat << EOF
================================================================================
NODECAP - Kubernetes Node Capacity Monitor
================================================================================

DESCRIPTION:
    Display Kubernetes node resource allocation with color-coded status indicators.
    Automatically caches results per cluster for improved performance.

USAGE:
    nodecap [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    -f, --force         Force refresh (bypass cache)
    -c, --clear         Clear all cache files
    -s, --status        Show cache status for all clusters
    -v, --version       Show script version
    -o, --output FILE   Save output with ANSI color codes (view with: cat FILE)
    -p, --plain FILE    Save plain text output without colors
    --html FILE         Save as HTML with colors (viewable in browsers/VSCode)

EXAMPLES:
    nodecap                  # Display node capacity (uses cache if fresh)
    nodecap -f               # Force refresh for current cluster
    nodecap --clear          # Clear all cached data
    nodecap --status         # Show cache status for all clusters
    nodecap -o output.txt    # Save with ANSI codes (cat output.txt to view)
    nodecap -p report.txt    # Save plain text output
    nodecap --html report.html  # Save as HTML (open in browser)

CACHE BEHAVIOR:
    • Cache expires after 5 minutes
    • Separate cache maintained for each kubectl context
    • Cache location: /tmp/k8s_nodes_cache/

STATUS INDICATORS:
    ✓ GREEN   (<70% allocated)     - Good availability
    ⚠ ORANGE  (70-90% allocated)   - Moderate load
    ✗ RED     (>90% allocated)     - Overcommitted

COLOR CODING:
    • Node name colored by overall status
    • CPU and Memory colored independently
    • Overall status reflects the worst condition

OUTPUT FORMAT:
    Shows CPU and Memory as: Resource (Allocated%/Available%)

VIEWING OUTPUT FILES:
    • ANSI format: cat output.txt (in terminal)
    • HTML format: Open in any web browser or VSCode
    • Plain text: Open in any text editor

REQUIREMENTS:
    • kubectl configured with cluster access
    • Active kubectl context

VERSION: 1.7.0
AUTHOR: Platform Engineering Team

================================================================================
EOF
    exit 0
}

# Function to show version
show_version() {
    echo "nodecap version 1.7.0"
    exit 0
}

# Function to clear cache
clear_cache() {
    CACHE_DIR="/tmp/k8s_nodes_cache"
    if [ -d "$CACHE_DIR" ]; then
        rm -rf "$CACHE_DIR"
        echo "✅ Cache cleared successfully"
    else
        echo "ℹ️  No cache to clear"
    fi
    exit 0
}

# Enhanced time formatting function
format_time() {
    local total_seconds=$1
    local days=$((total_seconds / 86400))
    local hours=$(((total_seconds % 86400) / 3600))
    local minutes=$(((total_seconds % 3600) / 60))
    local seconds=$((total_seconds % 60))
    
    if [ $days -gt 0 ]; then
        echo "${days}d ${hours}h ${minutes}m"
    elif [ $hours -gt 0 ]; then
        echo "${hours}h ${minutes}m ${seconds}s"
    elif [ $minutes -gt 0 ]; then
        echo "${minutes}m ${seconds}s"
    else
        echo "${seconds}s"
    fi
}

# Function to format cache age with date for old caches
format_cache_age() {
    local cache_time=$1
    local current_time=$2
    local age=$((current_time - cache_time))
    
    # If older than 24 hours, show the actual date
    if [ $age -gt 86400 ]; then
        # Format: Day-DD-MM-YYYY HH:MM
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            echo "$(date -r $cache_time '+%a-%d-%m-%Y %H:%M')"
        else
            # Linux
            echo "$(date -d @$cache_time '+%a-%d-%m-%Y %H:%M')"
        fi
    else
        # Less than 24 hours, show relative time
        format_time $age
    fi
}

# Function to show cache status
show_cache_status() {
    CACHE_DIR="/tmp/k8s_nodes_cache"
    CACHE_AGE=300
    
    echo "=================================================================================="
    echo "CACHE STATUS"
    echo "=================================================================================="
    
    if [ ! -d "$CACHE_DIR" ]; then
        echo "No cache directory found"
        exit 0
    fi
    
    if [ -z "$(ls -A $CACHE_DIR 2>/dev/null)" ]; then
        echo "No cache files found"
        exit 0
    fi
    
    CURRENT_TIME=$(date +%s)
    CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null)
    
    printf "%-40s | %-20s | %-15s | %-10s\n" "CLUSTER" "AGE/DATE" "STATUS" "CURRENT"
    echo "----------------------------------------------------------------------------------"
    
    for cache_file in "$CACHE_DIR"/*.txt; do
        if [ -f "$cache_file" ]; then
            cluster_name=$(basename "$cache_file" .txt)
            CACHE_TIME=$(stat -f%m "$cache_file" 2>/dev/null || stat -c%Y "$cache_file")
            AGE=$((CURRENT_TIME - CACHE_TIME))
            
            # Format age/date
            age_str=$(format_cache_age $CACHE_TIME $CURRENT_TIME)
            
            # Determine status
            if [ $AGE -lt $CACHE_AGE ]; then
                status="✓ Fresh"
            else
                status="⚠ Expired"
            fi
            
            # Check if current
            if [ "$cluster_name" = "$CURRENT_CONTEXT" ]; then
                current="◆ Yes"
            else
                current=""
            fi
            
            printf "%-40s | %-20s | %-15s | %-10s\n" "$cluster_name" "$age_str" "$status" "$current"
        fi
    done
    
    echo ""
    echo "Cache directory: $CACHE_DIR"
    echo "Cache lifetime: 5 minutes"
    exit 0
}

# Function to convert ANSI output to HTML
convert_to_html() {
    cat << 'HTML_HEAD'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Kubernetes Node Capacity Report</title>
    <style>
        body {
            background-color: #1e1e1e;
            color: #d4d4d4;
            font-family: 'Consolas', 'Courier New', monospace;
            padding: 20px;
            line-height: 1.4;
        }
        pre {
            background-color: #2d2d2d;
            padding: 20px;
            border-radius: 8px;
            overflow-x: auto;
        }
        .green { color: #4ec9b0; font-weight: bold; }
        .orange { color: #ffb86c; font-weight: bold; }
        .red { color: #ff6b6b; font-weight: bold; }
        .header {
            color: #569cd6;
            font-weight: bold;
        }
        .separator {
            color: #608b4e;
        }
    </style>
</head>
<body>
<pre>
HTML_HEAD

    # Read from stdin and convert ANSI to HTML
    sed -e 's/\[1;32m/<span class="green">/g' \
        -e 's/\[38;5;220m/<span class="orange">/g' \
        -e 's/\[1;31m/<span class="red">/g' \
        -e 's/\[0m/<\/span>/g' \
        -e 's/===============================================/<span class="separator">===============================================<\/span>/g' \
        -e 's/^🎯/<span class="header">🎯<\/span>/g' \
        -e 's/^⚡/<span class="header">⚡<\/span>/g' \
        -e 's/^🔄/<span class="header">🔄<\/span>/g'

    cat << 'HTML_FOOT'
</pre>
</body>
</html>
HTML_FOOT
}

# Main execution function
run_nodecap() {
    local output_mode=$1
    
    # Get current cluster context
    CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null)
    if [ -z "$CURRENT_CONTEXT" ]; then
        echo "❌ Error: No kubectl context found"
        echo "Please configure kubectl with a valid cluster context"
        exit 1
    fi
    
    # Create cluster-specific cache file
    CACHE_DIR="/tmp/k8s_nodes_cache"
    mkdir -p "$CACHE_DIR"
    CACHE_FILE="${CACHE_DIR}/${CURRENT_CONTEXT}.txt"
    CACHE_AGE=300  # 5 minutes
    
    echo "🎯 Current context: $CURRENT_CONTEXT"
    
    # Force refresh if requested
    if [ "$FORCE_REFRESH" = true ]; then
        echo "🔄 Force refresh requested, fetching fresh data..."
        DESC=$(kubectl describe nodes)
        echo "$DESC" > "$CACHE_FILE"
    # Check if cache exists and is fresh
    elif [ -f "$CACHE_FILE" ]; then
        CACHE_TIME=$(stat -f%m "$CACHE_FILE" 2>/dev/null || stat -c%Y "$CACHE_FILE")
        CURRENT_TIME=$(date +%s)
        AGE=$((CURRENT_TIME - CACHE_TIME))
        
        if [ $AGE -lt $CACHE_AGE ]; then
            EXPIRES_IN=$((CACHE_AGE - AGE))
            echo "⚡ Using cached data (age: $(format_time $AGE), expires in: $(format_time $EXPIRES_IN))..."
            DESC=$(cat "$CACHE_FILE")
        else
            # Show proper formatted age for expired cache
            age_display=$(format_cache_age $CACHE_TIME $CURRENT_TIME)
            if [ $AGE -gt 86400 ]; then
                echo "🔄 Cache expired (created: $age_display), fetching fresh data..."
            else
                echo "🔄 Cache expired (age: $age_display), fetching fresh data..."
            fi
            DESC=$(kubectl describe nodes)
            echo "$DESC" > "$CACHE_FILE"
        fi
    else
        echo "🔄 No cache found for this cluster, fetching fresh data..."
        DESC=$(kubectl describe nodes)
        echo "$DESC" > "$CACHE_FILE"
    fi
    
    echo "=============================================================================================================="
    echo "KUBERNETES NODE RESOURCE ALLOCATION"
    echo "=============================================================================================================="
    printf "%-45s | %-22s | %-22s | %-16s\n" "NODE NAME" "CPU (Alloc/Avail)" "MEMORY (Alloc/Avail)" "OVERALL STATUS"
    echo "=============================================================================================================="
    
    echo "$DESC" | awk -v output_mode="$output_mode" '
    BEGIN {
        if (output_mode == "plain") {
            GREEN = ""
            ORANGE = ""
            RED = ""
            RESET = ""
        } else {
            GREEN = "\033[1;32m"
            ORANGE = "\033[38;5;220m"  # Yellow-orange
            RED = "\033[1;31m"
            RESET = "\033[0m"
        }
        prev_pool = ""
    }
    
    function convert_to_gib(mem_str) {
        gsub(/\(.*\)/, "", mem_str)
        gsub(/ /, "", mem_str)
        
        if (mem_str ~ /Mi$/) {
            gsub(/Mi/, "", mem_str)
            return sprintf("%.1f", mem_str / 1024)
        } else if (mem_str ~ /Gi$/) {
            gsub(/Gi/, "", mem_str)
            return mem_str + 0
        } else if (mem_str ~ /Ki$/) {
            gsub(/Ki/, "", mem_str)
            return sprintf("%.1f", mem_str / 1024 / 1024)
        } else if (mem_str ~ /[0-9]$/) {
            return sprintf("%.1f", mem_str / 1024 / 1024 / 1024)
        }
        return 0
    }
    
    function get_pool_name(node_name) {
        split(node_name, parts, "-")
        if (length(parts) >= 2) {
            return parts[2]
        }
        return ""
    }
    
    function get_color(percentage) {
        if (percentage < 70) return GREEN
        else if (percentage < 90) return ORANGE
        else return RED
    }
    
    function pad_right(str, len) {
        # Remove ANSI color codes to calculate actual string length
        plain = str
        gsub(/\033\[[0-9;]*m/, "", plain)
        padding = len - length(plain)
        if (padding > 0) {
            return str sprintf("%" padding "s", "")
        }
        return str
    }
    
    /^Name:/ {
        if (name != "" && cpu_pct != "" && mem_pct != "") {
            cpu_num = cpu_pct + 0
            mem_num = mem_pct + 0
            cpu_avail = 100 - cpu_num
            mem_avail = 100 - mem_num
            
            # Get individual colors for CPU and Memory
            cpu_color = get_color(cpu_num)
            mem_color = get_color(mem_num)
            
            # Overall status based on worst condition
            if (cpu_num >= 90 || mem_num >= 90) {
                overall_color = RED
                overall_status = "✗ OVERCOMMITTED"
            } else if (cpu_num >= 70 || mem_num >= 70) {
                overall_color = ORANGE
                overall_status = "⚠ MODERATE"
            } else {
                overall_color = GREEN
                overall_status = "✓ AVAILABLE"
            }
            
            current_pool = get_pool_name(name)
            if (prev_pool != "" && current_pool != prev_pool) {
                print ""
            }
            prev_pool = current_pool
            
            mem_gib = convert_to_gib(mem)
            
            # Format CPU with its own color - create the string without color first
            cpu_plain = sprintf("%6s (%2d%%/%2d%%)", cpu, cpu_num, cpu_avail)
            cpu_str = sprintf("%s%s%s", cpu_color, cpu_plain, RESET)
            
            # Format Memory with its own color - create the string without color first
            mem_plain = sprintf("%6.1fGi (%2d%%/%2d%%)", mem_gib, mem_num, mem_avail)
            mem_str = sprintf("%s%s%s", mem_color, mem_plain, RESET)
            
            # Pad strings to ensure alignment
            cpu_padded = pad_right(cpu_str, 22)
            mem_padded = pad_right(mem_str, 22)
            
            # Color the node name based on overall status
            printf "%s%-45s%s | %s | %s | %s%-16s%s\n", \
                overall_color, name, RESET, cpu_padded, mem_padded, overall_color, overall_status, RESET
        }
        name = $2
        cpu = ""; mem = ""; cpu_pct = ""; mem_pct = ""
        in_alloc = 0
    }
    
    /Allocated resources:/ { in_alloc = 1; next }
    
    in_alloc && /^  cpu/ {
        cpu = $2
        if ($3 ~ /\(/) {
            gsub(/[()%]/, "", $3)
            cpu_pct = $3
        }
    }
    
    in_alloc && /^  memory/ {
        mem = $2
        if ($3 ~ /\(/) {
            gsub(/[()%]/, "", $3)
            mem_pct = $3
        }
        in_alloc = 0
    }
    
    END {
        if (name != "" && cpu_pct != "" && mem_pct != "") {
            cpu_num = cpu_pct + 0
            mem_num = mem_pct + 0
            cpu_avail = 100 - cpu_num
            mem_avail = 100 - mem_num
            
            # Get individual colors for CPU and Memory
            cpu_color = get_color(cpu_num)
            mem_color = get_color(mem_num)
            
            # Overall status based on worst condition
            if (cpu_num >= 90 || mem_num >= 90) {
                overall_color = RED
                overall_status = "✗ OVERCOMMITTED"
            } else if (cpu_num >= 70 || mem_num >= 70) {
                overall_color = ORANGE
                overall_status = "⚠ MODERATE"
            } else {
                overall_color = GREEN
                overall_status = "✓ AVAILABLE"
            }
            
            current_pool = get_pool_name(name)
            if (prev_pool != "" && current_pool != prev_pool) {
                print ""
            }
            
            mem_gib = convert_to_gib(mem)
            
            # Format CPU with its own color - create the string without color first
            cpu_plain = sprintf("%6s (%2d%%/%2d%%)", cpu, cpu_num, cpu_avail)
            cpu_str = sprintf("%s%s%s", cpu_color, cpu_plain, RESET)
            
            # Format Memory with its own color - create the string without color first
            mem_plain = sprintf("%6.1fGi (%2d%%/%2d%%)", mem_gib, mem_num, mem_avail)
            mem_str = sprintf("%s%s%s", mem_color, mem_plain, RESET)
            
            # Pad strings to ensure alignment
            cpu_padded = pad_right(cpu_str, 22)
            mem_padded = pad_right(mem_str, 22)
            
            # Color the node name based on overall status
            printf "%s%-45s%s | %s | %s | %s%-16s%s\n", \
                overall_color, name, RESET, cpu_padded, mem_padded, overall_color, overall_status, RESET
        }
    }
    '
    
    echo "=============================================================================================================="
    echo ""
    echo "📊 Format: Resource (Allocated%/Available%)"
    
    if [ "$output_mode" = "plain" ]; then
        echo "Colors: GREEN (<70%) | ORANGE (70-90%) | RED (>90%)"
    else
        echo -e "🎨 Colors: \033[1;32m■ GREEN\033[0m (<70%) | \033[38;5;220m■ ORANGE\033[0m (70-90%) | \033[1;31m■ RED\033[0m (>90%)"
    fi
    
    echo "📝 Note: Node name colored by overall status. CPU/Memory colored independently."
    echo "💾 Cache: $CACHE_FILE (auto-refresh every $(format_time $CACHE_AGE))"
    echo "🔄 Force refresh: nodecap -f"
    echo "📖 Help: nodecap --help"
    echo ""
}

# Parse arguments
FORCE_REFRESH=false
OUTPUT_FILE=""
OUTPUT_MODE="color"
HTML_OUTPUT=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help|help)
            show_help
            ;;
        -v|--version|version)
            show_version
            ;;
        -c|--clear|clear)
            clear_cache
            ;;
        -s|--status|status)
            show_cache_status
            ;;
        -f|--force|force)
            FORCE_REFRESH=true
            shift
            ;;
        -o|--output)
            OUTPUT_MODE="color"
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -p|--plain)
            OUTPUT_MODE="plain"
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --html)
            HTML_OUTPUT=true
            OUTPUT_FILE="$2"
            shift 2
            ;;
        "")
            break
            ;;
        *)
            echo "❌ Unknown option: $1"
            echo "Use 'nodecap --help' for usage information"
            exit 1
            ;;
    esac
done

# Execute based on output mode
if [ "$HTML_OUTPUT" = true ]; then
    run_nodecap "color" | convert_to_html > "$OUTPUT_FILE"
    echo "✅ HTML output saved to: $OUTPUT_FILE"
    echo "📝 Open in browser: open $OUTPUT_FILE (macOS) or xdg-open $OUTPUT_FILE (Linux)"
    echo "📝 Or open directly in VSCode to view with colors"
elif [ -n "$OUTPUT_FILE" ]; then
    run_nodecap "$OUTPUT_MODE" > "$OUTPUT_FILE"
    echo "✅ Output saved to: $OUTPUT_FILE"
    if [ "$OUTPUT_MODE" = "color" ]; then
        echo "📝 View with colors in terminal: cat $OUTPUT_FILE"
        echo "📝 Or use: less -R $OUTPUT_FILE"
        echo "💡 Tip: For VSCode, install 'ANSI Colors' extension or use --html option"
    fi
else
    run_nodecap "color"
fi