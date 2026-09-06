#!/usr/bin/env python3
"""main 전용 이력과 미반영 콘텐츠를 구분한다. ref/index/worktree는 변경하지 않는다."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import sys


class GateError(Exception):
    pass


class Repository:
    def __init__(self, path):
        self.path = path
        self.config = []

    def run(self, *args, check=True):
        result = subprocess.run(["git", *self.config, *args], cwd=self.path,
                                capture_output=True, text=True)
        if check and result.returncode != 0:
            raise GateError(f"git {args[0]} failed: {result.stderr.strip() or 'required history/object unavailable'}")
        return result

    def value(self, *args):
        return self.run(*args).stdout.strip()

    def commit(self, ref):
        result = self.run("rev-parse", "--verify", "--end-of-options", ref + "^{commit}", check=False)
        if result.returncode:
            raise GateError(f"missing or invalid ref: {ref}; fetch complete main/source history first")
        return result.stdout.strip()


def inspect_content(repo, main_ref, source_ref):
    if repo.value("rev-parse", "--is-shallow-repository") != "false":
        raise GateError("shallow history is not accepted; fetch with complete history")
    main = repo.commit(main_ref)
    source = repo.commit(source_ref)
    common = repo.run("merge-base", main, source, check=False)
    if common.returncode:
        raise GateError("no common ancestry or missing history; content parity cannot be established")

    lines = ["## main/source content gate", "", f"- main: `{main_ref}` → `{main}`",
             f"- source: `{source_ref}` → `{source}`"]
    candidates = []
    transport = []
    commits = repo.value("rev-list", "--reverse", source + ".." + main).splitlines()
    for commit in commits:
        parents = repo.value("rev-list", "--parents", "-n", "1", commit).split()[1:]
        if len(parents) == 2 and repo.value("rev-parse", commit + "^{tree}") == repo.value("rev-parse", parents[1] + "^{tree}"):
            transport.append(commit)
        else:
            candidates.append((commit, "non-merge" if len(parents) < 2 else "merge differs from source parent"))
    lines += [f"- main-only commits: {len(commits)}", f"- transport-only merges: {len(transport)}",
              f"- content candidates: {len(candidates)}"]
    lines += [f"  - transport `{commit}`: tree equals second parent" for commit in transport]
    lines += [f"  - candidate `{commit}`: {kind}" for commit, kind in candidates]

    # A custom driver such as 'ours' must not manufacture a no-op result by discarding main.
    # Disable configured external drivers for this calculation; never run their shell commands.
    drivers = repo.run("config", "--null", "--name-only", "--get-regexp", r"^merge\..*\.driver$", check=False)
    if drivers.returncode not in (0, 1):
        raise GateError("cannot inspect configured merge drivers")
    for key in filter(None, drivers.stdout.split("\0")):
        repo.config += ["-c", key + "=/usr/bin/false"]
    repo.config += ["-c", "merge.renormalize=false"]

    # This creates temporary tree/blob objects only. It does not merge into a branch or index.
    merged = repo.run("merge-tree", "--write-tree", "--no-messages", source, main, check=False)
    if merged.returncode not in (0, 1):
        raise GateError("merge-tree --write-tree failed; Git 2.38+ and complete objects are required: " + merged.stderr.strip())
    if merged.returncode == 1:
        lines += ["", "BLOCK: main/source content conflicts; resolve and incorporate main into source before proceeding."]
        paths = sorted({line.split("\t", 1)[1] for line in merged.stdout.splitlines()[1:] if "\t" in line})
        lines += [f"  - {path}" for path in paths]
        return 1, lines
    result_tree = merged.stdout.splitlines()[0] if merged.stdout else ""
    if not re.fullmatch(r"(?:[0-9a-f]{40}|[0-9a-f]{64})", result_tree):
        raise GateError("merge-tree did not return a valid tree object")
    source_tree = repo.value("rev-parse", source + "^{tree}")
    lines += [f"- source tree: `{source_tree}`", f"- prospective merge tree: `{result_tree}`"]
    if result_tree != source_tree:
        paths = repo.value("diff", "--name-only", "--no-ext-diff", source_tree, result_tree).splitlines()
        lines += ["", "BLOCK: main has content absent from source; incorporate it before proceeding."]
        lines += [f"  - {path}" for path in paths]
        return 1, lines
    if repo.run("merge-base", "--is-ancestor", main, source, check=False).returncode == 0:
        reason = "main ancestry is already incorporated"
    elif candidates:
        reason = "main content is already represented (equivalent/net content); no history-only merge required"
    else:
        reason = "transport-only history; no history-only merge required"
    lines += ["", "PASS: " + reason + "; merging main adds no content to source."]
    return 0, lines


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("main_ref", nargs="?", default="origin/main")
    parser.add_argument("source_ref", nargs="?", default="origin/devel")
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--summary-file", type=Path, default=os.environ.get("GITHUB_STEP_SUMMARY"))
    args = parser.parse_args()
    try:
        code, lines = inspect_content(Repository(args.repo), args.main_ref, args.source_ref)
    except (GateError, OSError) as error:
        code, lines = 2, ["## main/source content gate", "", "ERROR: " + str(error)]
    report = "\n".join(lines) + "\n"
    print(report, end="")
    if args.summary_file:
        try:
            with args.summary_file.open("a") as stream:
                stream.write(report + "\n")
        except OSError as error:
            print(f"ERROR: cannot write gate summary: {error}", file=sys.stderr)
            return 2
    return code


if __name__ == "__main__":
    sys.exit(main())
