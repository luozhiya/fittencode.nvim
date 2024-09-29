import os
import re
from pathlib import Path  # Import Path from pathlib module for modern path manipulations.

# Automatically determine the directory where the script is located
current_script_dir = Path(__file__).parent

# Define the regex pattern to match and the replacement logic
pattern = re.compile(r'<\|\s*([a-zA-Z0-9_-]+)\s*\|>')


def replace_in_file(file_path):
    """Function to replace content inside the <| |> tags in a file"""
    with open(file_path, 'r', encoding='utf-8') as file:
        content = file.read()

    # Perform the replacement
    new_content = re.sub(pattern, r'<|\1|>', content)

    # If there's a change, write it back to the file
    if new_content != content:
        print(f"Updating file: {file_path}")
        with open(file_path, 'w', encoding='utf-8') as file:
            file.write(new_content)
    else:
        print(f"No changes in file: {file_path}")


def batch_replace_in_directory(directory):
    """Recursively find and replace content in files in the specified directory"""
    for foldername, subfolders, filenames in os.walk(directory):
        for filename in filenames:
            if filename.endswith('.lua'):  # You can modify this to match different file types
                file_path = os.path.join(foldername, filename)
                replace_in_file(file_path)


# Run the batch replacement in the current script's directory
batch_replace_in_directory(current_script_dir)