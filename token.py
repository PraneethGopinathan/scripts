# This script is used to print the tokens in terminal

# Use any of the one method

# ------------------------------- Method-1 -------------------------------------------#

# Display as table

from tabulate import tabulate
import textwrap
from colorama import Fore, Style, init

# Initialize colorama
init(autoreset=True)

# Define the tokens in a dictionary
tokens = {
    "GITLAB_ACCESS_TOKEN": "changeme",
    "JIRA_TOKEN": "changeme",
    "AZURE_TERRAFORM_client_id": "changeme",
    # Add more tokens here
}

# Wrap long token values to avoid breaking the table layout
wrapped_tokens = {k: textwrap.fill(v, width=80) for k, v in tokens.items()}

# Prepare the data for tabulate
table_data = [(Fore.BLUE + key + Style.RESET_ALL, Style.BRIGHT + value + Style.RESET_ALL) for key, value in wrapped_tokens.items()]

# Create a colored header

# Print the table using tabulate
print(tabulate(table_data, tablefmt="fancy_grid"))



# ------------------------------- Method-2 -------------------------------------------#

# Display as normal print can be handy when frequently copying the text

from colorama import Fore, Style, init

# Initialize colorama
init(autoreset=True)

# Define the tokens in a dictionary
tokens = {
    "GITLAB_ACCESS_TOKEN": "changeme",
    "JIRA_TOKEN": "changeme",
    "AZURE_TERRAFORM_client_id": "changeme",
    # Add more tokens here
}

# Print each token on a new line without wrapping
for key, value in tokens.items():
    print(f"{Fore.BLUE + key + Style.RESET_ALL}: {Fore.GREEN + value + Style.RESET_ALL}")
