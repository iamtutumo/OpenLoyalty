#!/usr/bin/env python3
"""
Nayo - Database Credentials Finder

Scans the Nayo project for database connection strings, credentials,
and sensitive configuration values. Useful for:

  - Auditing before deployment
  - Finding hardcoded credentials that should be environment variables
  - Verifying Docker environment configurations
  - Security review before pushing to production

Usage:
    python FIND_DB_CREDENTIALS.py [options]

Options:
    --project-dir PATH    Path to Nayo project root (default: current directory)
    --format FORMAT       Output format: text, json, csv (default: text)
    --include-env         Also scan .env files
    --verbose             Show file context around matches
"""

import os
import re
import sys
import json
import argparse
from pathlib import Path
from datetime import datetime

# Patterns to search for
PATTERNS = {
    "PostgreSQL Connection": re.compile(
        r'(postgresql|postgres|pgsql)://[^\s\'"]+', re.IGNORECASE
    ),
    "Database Host": re.compile(
        r'(database_host|DB_HOST|APP_DB_HOST|POSTGRES_HOST)\s*[:=]\s*[^\s\'"#]+',
        re.IGNORECASE,
    ),
    "Database Name": re.compile(
        r'(database_name|DB_NAME|APP_DB_NAME|POSTGRES_DB)\s*[:=]\s*[^\s\'"#]+',
        re.IGNORECASE,
    ),
    "Database User": re.compile(
        r'(database_user|DB_USER|APP_DB_USER|POSTGRES_USER)\s*[:=]\s*[^\s\'"#]+',
        re.IGNORECASE,
    ),
    "Database Password": re.compile(
        r'(database_password|DB_PASSWORD|APP_DB_PASSWORD|POSTGRES_PASSWORD|DB_PASS)\s*[:=]\s*[^\s\'"#]+',
        re.IGNORECASE,
    ),
    "Database Port": re.compile(
        r'(database_port|DB_PORT|APP_DB_PORT)\s*[:=]\s*\d+',
        re.IGNORECASE,
    ),
    "Database Driver": re.compile(
        r'(database_driver|DB_DRIVER)\s*[:=]\s*[^\s\'"#]+',
        re.IGNORECASE,
    ),
    "Elasticsearch Host": re.compile(
        r'(ELK_HOST|ES_HOST|ELASTICSEARCH_HOST)\s*[:=]\s*[^\s\'"#]+',
        re.IGNORECASE,
    ),
    "JWT Secret/Key Path": re.compile(
        r'(jwt_private_key_path|jwt_public_key_path|jwt_key_pass_phrase|JWT_SECRET)\s*[:=]\s*[^\s\'"#]+',
        re.IGNORECASE,
    ),
    "API Key": re.compile(
        r'(master_api_key|api_key|API_KEY)\s*[:=]\s*[^\s\'"#]+',
        re.IGNORECASE,
    ),
    "Secret Key": re.compile(
        r'(secret|SECRET_KEY|APP_SECRET)\s*[:=]\s*[^\s\'"#]+',
        re.IGNORECASE,
    ),
    "Mailer Config": re.compile(
        r'(mailer_transport|mailer_host|mailer_user|mailer_password|mailer_port)\s*[:=]\s*[^\s\'"#]+',
        re.IGNORECASE,
    ),
    "Odoo Connection": re.compile(
        r'(ODOO_URL|ODOO_HOST|ODOO_DB|ODOO_USER|ODOO_PASSWORD|odoo_xmlrpc)\s*[:=]\s*[^\s\'"#]+',
        re.IGNORECASE,
    ),
}

# Directories to skip
SKIP_DIRS = {
    ".git",
    "node_modules",
    "vendor",
    "var",
    "__pycache__",
    ".venv",
    ".cache",
    ".idea",
    ".vscode",
}

# File extensions to scan
SCAN_EXTENSIONS = {
    ".py", ".php", ".yml", ".yaml", ".json", ".xml", ".env",
    ".txt", ".cfg", ".ini", ".conf", ".sh", ".bash", ".md",
    ".rst", ".sql", ".js", ".ts", ".properties", ".toml",
}


def scan_file(filepath, include_env=False):
    """Scan a single file for credential patterns."""
    findings = []

    # Skip .env files unless explicitly included
    if not include_env and filepath.name.startswith(".env"):
        return findings

    try:
        with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
            lines = f.readlines()
    except (PermissionError, OSError):
        return findings

    for line_num, line in enumerate(lines, 1):
        # Skip comments
        stripped = line.strip()
        if stripped.startswith("#") or stripped.startswith("//"):
            continue

        for pattern_name, pattern in PATTERNS.items():
            matches = pattern.finditer(line)
            for match in matches:
                findings.append({
                    "file": str(filepath),
                    "line": line_num,
                    "pattern": pattern_name,
                    "match": match.group().strip(),
                    "context": stripped[:120],
                })

    return findings


def scan_project(project_dir, include_env=False):
    """Scan entire project directory."""
    project_path = Path(project_dir).resolve()
    all_findings = []

    for root, dirs, files in os.walk(project_path):
        # Skip excluded directories
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]

        for filename in files:
            filepath = Path(root) / filename
            if filepath.suffix.lower() in SCAN_EXTENSIONS or filepath.name.startswith(".env"):
                findings = scan_file(filepath, include_env)
                all_findings.extend(findings)

    return all_findings


def print_text_report(findings, project_dir):
    """Print findings as formatted text."""
    print("=" * 78)
    print("NAYO DATABASE CREDENTIALS AUDIT REPORT")
    print(f"Project: {project_dir}")
    print(f"Date:    {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Findings: {len(findings)}")
    print("=" * 78)

    if not findings:
        print("\nNo credentials found. Your project looks clean.")
        return

    # Group by file
    by_file = {}
    for f in findings:
        by_file.setdefault(f["file"], []).append(f)

    for filepath, file_findings in sorted(by_file.items()):
        rel_path = os.path.relpath(filepath, project_dir)
        print(f"\n--- {rel_path} ---")
        for f in file_findings:
            print(f"  Line {f['line']:>4}  [{f['pattern']}]")
            print(f"           {f['match']}")

    # Summary
    print("\n" + "=" * 78)
    print("SUMMARY BY PATTERN TYPE")
    print("=" * 78)
    by_pattern = {}
    for f in findings:
        by_pattern.setdefault(f["pattern"], []).append(f)

    for pattern, pattern_findings in sorted(by_pattern.items()):
        print(f"  {pattern}: {len(pattern_findings)} occurrence(s)")

    # Warnings
    print("\n" + "=" * 78)
    print("SECURITY WARNINGS")
    print("=" * 78)

    password_findings = [
        f for f in findings
        if "password" in f["pattern"].lower() or "secret" in f["pattern"].lower()
    ]
    if password_findings:
        print(f"\n  WARNING: Found {len(password_findings)} password/secret reference(s).")
        print("  Ensure these are NOT hardcoded and use environment variables instead.")
        print("  Files affected:")
        for f in password_findings:
            rel = os.path.relpath(f["file"], project_dir)
            print(f"    - {rel} (line {f['line']})")

    env_findings = [f for f in findings if ".env" in f["file"]]
    if env_findings:
        print(f"\n  NOTE: Found {len(env_findings)} reference(s) in .env files.")
        print("  Ensure .env files are in .gitignore and never committed to version control.")


def print_json_report(findings, project_dir):
    """Print findings as JSON."""
    report = {
        "project": str(project_dir),
        "date": datetime.now().isoformat(),
        "total_findings": len(findings),
        "findings": findings,
    }
    print(json.dumps(report, indent=2))


def main():
    parser = argparse.ArgumentParser(
        description="Nayo Database Credentials Finder - Scan for credentials in your project"
    )
    parser.add_argument(
        "--project-dir",
        default=".",
        help="Path to Nayo project root (default: current directory)",
    )
    parser.add_argument(
        "--format",
        choices=["text", "json"],
        default="text",
        help="Output format (default: text)",
    )
    parser.add_argument(
        "--include-env",
        action="store_true",
        help="Also scan .env files for credentials",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Show file context around matches",
    )

    args = parser.parse_args()
    project_dir = Path(args.project_dir).resolve()

    if not project_dir.exists():
        print(f"Error: Directory not found: {project_dir}", file=sys.stderr)
        sys.exit(1)

    findings = scan_project(project_dir, include_env=args.include_env)

    if args.format == "json":
        print_json_report(findings, project_dir)
    else:
        print_text_report(findings, project_dir)

    # Exit with code 1 if passwords/secrets found (useful for CI)
    password_findings = [
        f for f in findings
        if "password" in f["pattern"].lower() or "secret" in f["pattern"].lower()
    ]
    sys.exit(1 if password_findings else 0)


if __name__ == "__main__":
    main()
