import os
import re
from pathlib import (
    Path,
)  # Import Path from pathlib module for modern path manipulations.

# Automatically determine the directory where the script is located
current_script_dir = Path(__file__).parent

# Modify directory "../lua/fittencode/template/"
lua_template_dir = current_script_dir.parent.joinpath("lua", "fittencode", "template")

# Define the regex pattern to match and the replacement logic
# pattern = re.compile(r'<\|\s*([a-zA-Z0-9_-]+)\s*\|>')


def replace_in_file(file_path):
    """Function to replace content inside the <| |> tags in a file"""
    with open(file_path, "r", encoding="utf-8") as file:
        content = file.read()

    # Perform the replacement
    # new_content = re.sub(pattern, r'<|\1|>', content)
    new_content = re.sub(
        r"<\|\s*|\s*\|>", lambda m: m.group().replace(" ", ""), content
    )

    # If there's a change, write it back to the file
    if new_content != content:
        print(f"Updating file: {file_path}")
        with open(file_path, "w", encoding="utf-8") as file:
            file.write(new_content)
    else:
        print(f"No changes in file: {file_path}")


def batch_replace_in_directory(directory):
    """Recursively find and replace content in files in the specified directory"""
    for foldername, subfolders, filenames in os.walk(directory):
        for filename in filenames:
            if filename.endswith(
                ".lua"
            ):  # You can modify this to match different file types
                file_path = os.path.join(foldername, filename)
                replace_in_file(file_path)


def trim_trailing_whitespace(file_path):
    """Function to remove trailing whitespace from the end of lines in a file"""
    with open(file_path, "r", encoding="utf-8") as file:
        content = file.readlines()

    # Remove trailing whitespace from each line
    new_content = [line.rstrip() for line in content]

    # If there's a change, write it back to the file
    if new_content != content:
        print(f"Trimming trailing whitespace from file: {file_path}")
        with open(file_path, "w", encoding="utf-8") as file:
            file.write("\n".join(new_content))
    else:
        print(f"No changes in file: {file_path}")


def add_newline_at_eof(file_path):
    """Function to add a newline character at the end of a file if it doesn't already have one"""
    with open(file_path, "r", encoding="utf-8") as file:
        content = file.read()

    # Check if the file already ends with a newline
    if content.endswith("\n"):
        print(f"File already ends with a newline: {file_path}")
        return

    # Add a newline character at the end of the file
    new_content = content + "\n"

    # If there's a change, write it back to the file
    if new_content != content:
        print(f"Adding newline at the end of file: {file_path}")
        with open(file_path, "w", encoding="utf-8") as file:
            file.write(new_content)
    else:
        print(f"No changes in file: {file_path}")

def replace_backtick(file_path):
    # replace \` with `
    with open(file_path, "r", encoding="utf-8") as file:
        content = file.read()

    new_content = re.sub(r"\\`", "`", content)
    if new_content != content:
        print(f"Replacing \\` with ` in file: {file_path}")
        with open(file_path, "w", encoding="utf-8") as file:
            file.write(new_content)
    else:
        print(f"No changes in file: {file_path}")

def refine(file_path):
    replace_in_file(file_path)
    trim_trailing_whitespace(file_path)
    add_newline_at_eof(file_path)
    replace_backtick(file_path)


# Run the batch replacement in the current script's directory
# batch_replace_in_directory(lua_template_dir)
