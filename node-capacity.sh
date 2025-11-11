#!/bin/bash

# Get current cluster context
CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null)
if [ -z "$CURRENT_CONTEXT" ]; then
    echo "❌ Error: No kubectl context found"
    exit 1
fi

# Create cluster-specific cache file
CACHE_DIR="/tmp/k8s_nodes_cache"
mkdir -p "$CACHE_DIR"
CACHE_FILE="${CACHE_DIR}/${CURRENT_CONTEXT}.txt"
CACHE_AGE=300  # 5 minutes

# Check for force refresh parameter
FORCE_REFRESH=false
if [ "$1" == "-f" ] || [ "$1" == "--force" ] || [ "$1" == "force" ]; then
    FORCE_REFRESH=true
fi

# Function to format seconds into readable time
format_time() {
    local total_seconds=$1
    local minutes=$((total_seconds / 60))
    local seconds=$((total_seconds % 60))
    
    if [ $minutes -gt 0 ]; then
        echo "${minutes}m ${seconds}s"
    else
        echo "${seconds}s"
    fi
}

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
        echo "🔄 Cache expired (age: $(format_time $AGE)), fetching fresh data..."
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
printf "%-45s | %-22s | %-22s | %-16s\n" "NODE NAME" "CPU (Alloc/Avail)" "MEMORY (Alloc/Avail)" "STATUS"
echo "=============================================================================================================="

echo "$DESC" | awk '
BEGIN {
    GREEN = "\033[1;32m"
    ORANGE = "\033[38;5;214m"  # Medium Orange (lighter than 208, darker than bright yellow)
    RED = "\033[1;31m"
    RESET = "\033[0m"
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

/^Name:/ {
    if (name != "" && cpu_pct != "" && mem_pct != "") {
        cpu_num = cpu_pct + 0
        mem_num = mem_pct + 0
        cpu_avail = 100 - cpu_num
        mem_avail = 100 - mem_num
        
        if (cpu_num < 70 && mem_num < 70) {
            color = GREEN; status = "✓ AVAILABLE"
        } else if (cpu_num < 90 || mem_num < 90) {
            color = ORANGE; status = "⚠ MODERATE"  
        } else {
            color = RED; status = "✗ OVERCOMMITTED"
        }
        
        current_pool = get_pool_name(name)
        if (prev_pool != "" && current_pool != prev_pool) {
            print ""
        }
        prev_pool = current_pool
        
        mem_gib = convert_to_gib(mem)
        
        cpu_str = sprintf("%5s (%2d%%/%2d%%)", cpu, cpu_num, cpu_avail)
        mem_str = sprintf("%6.1fGi (%2d%%/%2d%%)", mem_gib, mem_num, mem_avail)
        
        printf "%s%-45s | %-22s | %-22s | %-16s%s\n", \
            color, name, cpu_str, mem_str, status, RESET
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
        
        if (cpu_num < 70 && mem_num < 70) {
            color = GREEN; status = "✓ AVAILABLE"
        } else if (cpu_num < 90 || mem_num < 90) {
            color = ORANGE; status = "⚠ MODERATE"
        } else {
            color = RED; status = "✗ OVERCOMMITTED"
        }
        
        current_pool = get_pool_name(name)
        if (prev_pool != "" && current_pool != prev_pool) {
            print ""
        }
        
        mem_gib = convert_to_gib(mem)
        
        cpu_str = sprintf("%5s (%2d%%/%2d%%)", cpu, cpu_num, cpu_avail)
        mem_str = sprintf("%6.1fGi (%2d%%/%2d%%)", mem_gib, mem_num, mem_avail)
        
        printf "%s%-45s | %-22s | %-22s | %-16s%s\n", \
            color, name, cpu_str, mem_str, status, RESET
    }
}
'

echo "=============================================================================================================="
echo ""
echo "📊 Format: Resource (Allocated%/Available%)"
echo -e "🎨 Colors: \033[1;32m■ GREEN\033[0m (Available) | \033[38;5;214m■ ORANGE\033[0m (Moderate) | \033[1;31m■ RED\033[0m (Overcommitted)"
echo "💾 Cache: $CACHE_FILE (auto-refresh every $(format_time $CACHE_AGE))"
echo "🔄 Force refresh: nodecap -f (or --force)"
echo "🗑️  Clear all cache: rm -rf $CACHE_DIR"
echo ""