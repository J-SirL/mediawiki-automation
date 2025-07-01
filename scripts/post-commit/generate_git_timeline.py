#!/usr/bin/env python3
# Last changes by Johan Sörell
import subprocess
import os
import sys
from datetime import datetime
from pathlib import Path

from githooks_utils import (
    assert_inside_repo,
    get_repo_root,
    run_git_command,
    get_repo_url,
    get_branches,
    get_tags,
    get_pull_requests,
    get_commits,
)

def generate_git_timeline():
    branch_name = os.getenv("BRANCH_NAME")

    if not branch_name:
        print("❌ ERROR: Branch name not set. Exiting.")
        sys.exit(1)

    print(f"🌿 Active Branch: {branch_name}")

    repo_root = get_repo_root()
    log_dir = os.path.join(repo_root, "docs", "commit-logs", branch_name)
    assert_inside_repo(Path(log_dir), Path(repo_root), "Timeline output directory")

    os.makedirs(log_dir, exist_ok=True)
    timeline_file_path = os.path.join(log_dir, "git_timeline_report.md")

    # Start generating the Markdown content
    with open(timeline_file_path, "w") as md_file:
        md_file.write("# 📊 Git Commit Timeline\n\n")
        md_file.write(f"> **Generated on:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
        md_file.write(f"> **Branch:** `{branch_name}`\n\n")

        # Branches Section
        md_file.write("## 📦 Branches\n| **Branch Name** | **Last Commit** | **Author** |\n|----------------|--------------|------------|\n")
        for branch in get_branches():
            md_file.write(f"| {branch} |\n")

        # Tags Section
        md_file.write("\n## 🏷️ Tags\n| **Tag** | **Commit Hash** | **Tagged On** |\n|--------|----------------|--------------|\n")
        for tag in get_tags():
            md_file.write(f"| {tag} |\n")

        # PR Section (Simulated using commit messages)
        md_file.write("\n## 🔀 Pull Requests (PRs)\n| **Commit** | **Message** | **Date** |\n|------------|-------------|---------|\n")
        for pr in get_pull_requests():
            md_file.write(f"| {pr} |\n")

        # Commits Section
        md_file.write("\n## 📁 Commit Log\n")
        for commit in get_commits():
            hash, message, author, date = commit.split(" | ")
            repo_url = get_repo_url()
            md_file.write(f"### ✅ Commit: [{hash}]({repo_url}/commit/{hash})\n")
            md_file.write(f"- **Date:** {date}\n- **Author:** {author}\n- **Message:** {message}\n\n")

        md_file.write("\n## ✅ Summary\n- **Here you can put a summary if you like.**\n- **PR and MR inclusion (simulated).**\n")

    subprocess.run(["git", "add", timeline_file_path], check=True)
    commit_hash = subprocess.run(["git", "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    commit_message = f"Update commit timeline: {commit_hash}"

    try:
        subprocess.run(["git", "commit", "-m", commit_message], check=True)
        print(f"📈 Git Timeline Updated for branch: {branch_name}")
        print(f"✅ Timeline report generated: {timeline_file_path}")
    except subprocess.CalledProcessError:
        print("⚠️ No changes detected. Skipping commit.")

if __name__ == "__main__":
    generate_git_timeline()
