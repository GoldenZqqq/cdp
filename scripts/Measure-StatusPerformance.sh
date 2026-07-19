#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_count="${CDP_BENCHMARK_PROJECTS:-50}"
runs="${CDP_BENCHMARK_RUNS:-5}"
jobs="${CDP_STATUS_CONCURRENCY:-4}"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/cdp-status-benchmark.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT

mkdir -p "$fixture_root/repos"
config_path="$fixture_root/projects.json"
printf '[\n' > "$config_path"
for ((i=1; i<=project_count; i++)); do
    repo="$fixture_root/repos/repo-$i"
    git init -q "$repo"
    git -C "$repo" config user.name cdp-benchmark
    git -C "$repo" config user.email cdp@example.invalid
    printf '%s\n' "$i" > "$repo/file.txt"
    git -C "$repo" add file.txt
    git -C "$repo" commit -q -m initial
    separator=','
    [[ "$i" -eq "$project_count" ]] && separator=''
    printf '  {"name":"Repo%s","rootPath":"%s","enabled":true}%s\n' "$i" "$repo" "$separator" >> "$config_path"
done
printf ']\n' >> "$config_path"

echo "cdp status benchmark"
echo "os: $(uname -s) $(uname -m)"
echo "bash: ${BASH_VERSION}"
echo "git: $(git --version)"
echo "projects: $project_count; runs: $runs; jobs: $jobs; cache ttl: 0"

timings="$fixture_root/timings.txt"
for ((run=1; run<=runs; run++)); do
    started=$(perl -MTime::HiRes=time -e 'printf "%.6f", time')
    CDP_STATUS_CACHE_TTL=0 bash -c '
        source "$1/src/cdp.sh"
        cdp-status --jobs "$2" "$3" >/dev/null 2>/dev/null
    ' _ "$repo_root" "$jobs" "$config_path"
    finished=$(perl -MTime::HiRes=time -e 'printf "%.6f", time')
    elapsed=$(awk -v start="$started" -v finish="$finished" 'BEGIN { printf "%.3f", finish - start }')
    echo "$elapsed" >> "$timings"
    echo "run $run: ${elapsed}s"
done

sort -n "$timings" | awk '
    { value[NR] = $1 }
    END {
        median = value[int((NR + 1) / 2)]
        p95Index = int((NR * 95 + 99) / 100)
        printf "min: %.3fs; median: %.3fs; p95: %.3fs\n", value[1], median, value[p95Index]
    }
'
