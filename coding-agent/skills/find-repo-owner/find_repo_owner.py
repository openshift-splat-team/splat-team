#!/usr/bin/env python3
"""
Repository Owner Finder Helper

Convenience wrapper around list-repos for common ownership queries.
Designed to be imported by other plugins.

Usage:
    # As a library
    from plugins.teams.skills.find_repo_owner.find_repo_owner import (
        find_repo_approvers,
        find_team_repos,
        suggest_repos_for_work
    )

    # As a CLI tool
    python3 find_repo_owner.py --repo openshift/console
    python3 find_repo_owner.py --team team-network
    python3 find_repo_owner.py --suggest "network ipv6"
"""

import argparse
import json
import os
import subprocess
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
LIST_REPOS_SCRIPT = os.path.join(
    os.path.dirname(SCRIPT_DIR),
    "list-repos",
    "list_repos.py"
)


def run_list_repos(search=None, approver=None, topic=None):
    """Run the list_repos.py script with optional filters."""
    cmd = ["python3", LIST_REPOS_SCRIPT]

    if search:
        cmd.extend(["--search", search])
    if approver:
        cmd.extend(["--approver", approver])
    if topic:
        cmd.extend(["--topic", topic])

    result = subprocess.run(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True
    )

    if result.returncode != 0:
        print(f"Error running list_repos: {result.stderr}", file=sys.stderr)
        return None

    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON: {e}", file=sys.stderr)
        return None


def find_repo_approvers(repo_name):
    """Find approvers for a specific repository.

    Args:
        repo_name: Repository name (with or without 'openshift/' prefix)

    Returns:
        dict with 'name', 'approvers', 'description', 'has_codeowners'
        or None if not found
    """
    # Normalize repo name
    if not repo_name.startswith("openshift/"):
        repo_name = f"openshift/{repo_name}"

    # Search by repo name only (without org)
    search_term = repo_name.split("/")[1]
    data = run_list_repos(search=search_term)

    if not data:
        return None

    # Find exact match
    for repo in data['repos']:
        if repo['name'] == repo_name:
            return {
                'name': repo['name'],
                'approvers': repo['approvers'],
                'description': repo['description'],
                'has_codeowners': repo['has_codeowners'],
                'url': repo['url'],
                'topics': repo['topics']
            }

    return None


def find_team_repos(team_name):
    """Find all repositories owned by a specific team.

    Args:
        team_name: Team name (with or without @ prefix)

    Returns:
        List of repository objects
    """
    # Normalize team name
    if not team_name.startswith("@"):
        team_name = f"@{team_name}"

    data = run_list_repos(approver=team_name)

    if not data:
        return []

    return data['repos']


def suggest_repos_for_work(keywords):
    """Suggest repositories based on functionality keywords.

    Args:
        keywords: String or list of keywords to search for

    Returns:
        List of repository objects ranked by relevance
    """
    if isinstance(keywords, list):
        keywords = " ".join(keywords)

    data = run_list_repos(search=keywords)

    if not data or not data['repos']:
        return []

    # Rank by keyword presence in description and name
    repos = data['repos']
    keyword_list = keywords.lower().split()

    for repo in repos:
        score = 0
        name_lower = repo['name'].lower()
        desc_lower = repo['description'].lower()

        # Higher score for matches in name
        for kw in keyword_list:
            if kw in name_lower:
                score += 2
            if kw in desc_lower:
                score += 1

        repo['relevance_score'] = score

    return sorted(repos, key=lambda r: r['relevance_score'], reverse=True)


def find_repos_by_tech(topic):
    """Find repositories using a specific technology.

    Args:
        topic: Topic/technology (e.g., 'go', 'react', 'python')

    Returns:
        List of repository objects
    """
    data = run_list_repos(topic=topic)

    if not data:
        return []

    return data['repos']


def main():
    parser = argparse.ArgumentParser(
        description="Find repository ownership information"
    )

    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        "--repo",
        help="Find approvers for a specific repository (e.g., 'openshift/console')"
    )
    group.add_argument(
        "--team",
        help="Find all repositories owned by a team (e.g., 'team-network')"
    )
    group.add_argument(
        "--suggest",
        help="Suggest repositories based on keywords (e.g., 'network ipv6')"
    )
    group.add_argument(
        "--tech",
        help="Find repositories by technology/topic (e.g., 'go', 'react')"
    )

    args = parser.parse_args()

    if args.repo:
        result = find_repo_approvers(args.repo)
        if result:
            print(json.dumps(result, indent=2))
        else:
            print(json.dumps({
                "error": "Repository not found",
                "repo": args.repo
            }, indent=2))
            sys.exit(1)

    elif args.team:
        repos = find_team_repos(args.team)
        print(json.dumps({
            "team": args.team if args.team.startswith("@") else f"@{args.team}",
            "total_repos": len(repos),
            "repos": repos
        }, indent=2))

    elif args.suggest:
        repos = suggest_repos_for_work(args.suggest)
        print(json.dumps({
            "keywords": args.suggest,
            "total_matches": len(repos),
            "suggestions": repos
        }, indent=2))

    elif args.tech:
        repos = find_repos_by_tech(args.tech)
        print(json.dumps({
            "topic": args.tech,
            "total_repos": len(repos),
            "repos": repos
        }, indent=2))


if __name__ == "__main__":
    main()
