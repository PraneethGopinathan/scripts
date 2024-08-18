#!/bin/bash

# This script will count the total lines of codes in all the git projects using a open-source tool called cloc
# https://github.com/AlDanial/cloc
# Function to show a spinner during execution
spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Function to analyze the "dcd" project
function dcd() {
    local branch=$1
    local project=$2
    printf "\n"
    echo -e "\033[1;35m🚀 Analyzing the '$project' with '$branch' branch...\033[0m"
    cd ~/Documents/repos/genpro/CLOC/disease-context-center
    git fetch 
    error_msg=$(git checkout "$branch" 2>&1 > /dev/null)
    if [[ $? -ne 0 ]]; then
        echo -e "\033[1;31mError: Branch '$branch' not found in dsur-automation repository.\033[0m"
        exit 1
    fi 
    git pull origin "$branch" &> /dev/null & spinner

    cd ../arippa
    git fetch &> /dev/null & spinner
    git checkout main &> /dev/null & spinner
    git pull origin main &> /dev/null & spinner

    cd ../snail
    git fetch &> /dev/null & spinner
    git checkout master &> /dev/null & spinner
    git pull origin master &> /dev/null & spinner

    cd ../arrow
    git fetch &> /dev/null & spinner
    git checkout main &> /dev/null & spinner
    git pull origin main &> /dev/null & spinner

    cd ../voynich
    git fetch &> /dev/null & spinner
    git checkout main &> /dev/null & spinner
    git pull origin main &> /dev/null & spinner

    cd ../dawn
    git fetch &> /dev/null & spinner
    git checkout main &> /dev/null & spinner
    git pull origin main &> /dev/null & spinner

    cd ~/Documents/repos/genpro/CLOC/
    cloc --exclude-dir=.git,.vscode,tmp --fullpath --not-match-d=extension/node_modules --not-match-f='(json|xml|svg|png)' --skip-archive='(zip|tar(.(gz|Z|bz2|xz|7z))?)' disease-context-center arippa snail arrow voynich dawn --out ~/Documents/repos/genpro/CLOC/dcd.txt &> /dev/null & spinner
}

# Function to analyze the "dsur" project
function dsur() {
    local branch=$1
    local project=$2
    printf "\n"
    echo -e "\033[1;35m🚀 Analyzing the '$project' with '$branch' branch...\033[0m"
    cd ~/Documents/repos/genpro/CLOC/dsur-automation
    git fetch &> /dev/null & spinner
    error_msg=$(git checkout "$branch" 2>&1 > /dev/null)
    if [[ $? -ne 0 ]]; then
        echo -e "\033[1;31mError: Branch '$branch' not found in dsur-automation repository.\033[0m"
        exit 1
    fi
    git pull &> /dev/null & spinner

    cloc --exclude-dir=.git,.vscode,tmp --fullpath --not-match-d='(venv|deployment/kubernetes)' --not-match-f='(json|xml|svg|png)' --skip-archive='(zip|tar(.(gz|Z|bz2|xz|7z))?)' --exclude-lang=C,"C/C++ Header" . --out ~/Documents/repos/genpro/CLOC/dsur.txt &> /dev/null & spinner
}


# Prompt the user to choose a project
echo -e "\033[1;32mWhich project do you want to analyze?\033[0m"
echo "1. DCD"
echo "2. DSUR"
read -p "Select the project (1 or 2): " choice

if [ "$choice" -eq 1 ]; then
    project="DCD"
    printf "\n"
    read -p $'Branch name for DCD (Default: master): ' branch
    if [ -z $branch ]; then
        echo -e "\033[1;31mNo branch selected. Exiting... \033[0m"
        exit 1
        # branch="master"
    fi
elif [ "$choice" -eq 2 ]; then
    project="DSUR"
    printf "\n"
    read -p $'Branch name for DSUR (Default: main):  ' branch
    if [ -z $branch ]; then
        echo -e "\033[1;31mNo branch selected. Exiting... \033[0m"
        exit 1
        # branch="main"
    fi
else
    echo -e "\033[1;31mInvalid choice. Exiting... \033[0m"
    exit 1
fi

# Provide default branch names if no input is provided
if [ -z "$branch" ]; then
    if [ "$choice" -eq 1 ]; then
        branch="master"
    elif [ "$choice" -eq 2 ]; then
        branch="main"
    fi
fi

printf "\n"
echo -e "\033[1;36mProject → $project\033[0m" && echo -e "\033[1;36mBranch → $branch\033[0m"

# Execute the selected function
case $choice in
    1)
        dcd "$branch" "$project"
        cat ~/Documents/repos/genpro/CLOC/dcd.txt
        echo -e "\033[1;32m   Output file → /home/$USER/Documents/repos/genpro/CLOC/dcd.txt \033[0m"
        ;;
    2)
        dsur "$branch" "$project"
        cat ~/Documents/repos/genpro/CLOC/dsur.txt
        echo -e "\033[1;32m   Output file → /home/$USER/Documents/repos/genpro/CLOC/dsur.txt \033[0m"
        ;;
    *)
        echo -e "\033[1;31mInvalid choice. Exiting...\033[0m"
        exit 1
        ;;
esac
