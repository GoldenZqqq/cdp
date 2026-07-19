import { existsSync } from "node:fs";
import { readFile, readdir } from "node:fs/promises";
import { dirname, join, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

const scriptPath = fileURLToPath(import.meta.url);
const defaultRoot = resolve(dirname(scriptPath), "..");

function toPosix(value) {
  return value.split(sep).join("/");
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

export function extractMarkdownShape(content) {
  const headings = [];
  const fences = [];
  let insideFence = false;
  for (const line of content.split(/\r?\n/)) {
    const fence = line.match(/^```\s*([^\s`]*)/);
    if (fence) {
      if (!insideFence) fences.push(fence[1] || "plain");
      insideFence = !insideFence;
      continue;
    }
    if (insideFence) continue;
    const heading = line.match(/^(#{2,3})\s+\S/);
    if (heading) headings.push(heading[1].length);
  }
  return { headings, fences };
}

export function compareReadmeStructures(english, chinese) {
  const left = extractMarkdownShape(english);
  const right = extractMarkdownShape(chinese);
  assert(
    JSON.stringify(left.headings) === JSON.stringify(right.headings),
    "README H2/H3 structure differs between English and Chinese"
  );
  assert(
    JSON.stringify(left.fences) === JSON.stringify(right.fences),
    "README fenced-code language sequence differs between English and Chinese"
  );
}

export function parseManifestExports(manifest, field) {
  const match = manifest.match(new RegExp(`${field}\\s*=\\s*@\\(([^)]*)\\)`, "s"));
  assert(match, `manifest field not found: ${field}`);
  return [...match[1].matchAll(/'([^']+)'/g)].map((entry) => entry[1]);
}

export function assertTokensDocumented(content, tokens, label) {
  const missing = tokens.filter((token) => !content.includes(token));
  assert(missing.length === 0, `${label} is missing documented tokens: ${missing.join(", ")}`);
}

export function assertNoSpecPlaceholders(documents) {
  const pattern = /To fill|To be filled by the team|Replace with your actual structure|Document your project's/;
  const failures = documents.filter((document) => pattern.test(document.content));
  assert(failures.length === 0, `Trellis spec placeholders remain: ${failures.map((item) => item.path).join(", ")}`);
}

export function assertNoStaleGuidance(documents) {
  const patterns = [
    [/MinimumVersion 5\.5\.0/, "outdated Pester 5.5 guidance"],
    [/src\/cdp\.psm1:\d+/, "fragile source line reference"],
    [/Core implementation with all functions/, "obsolete single-file architecture"],
    [/(?:^|\n)(?:Add|Fix|Update|Docs|Refactor):\s/m, "obsolete non-Conventional commit example"]
  ];
  const failures = [];
  for (const document of documents) {
    for (const [pattern, description] of patterns) {
      if (pattern.test(document.content)) failures.push(`${document.path}: ${description}`);
    }
  }
  assert(failures.length === 0, `stale documentation guidance: ${failures.join("; ")}`);
}

async function collectMarkdown(root, relativeRoot) {
  const absoluteRoot = resolve(root, relativeRoot);
  const documents = [];
  for (const entry of await readdir(absoluteRoot, { withFileTypes: true })) {
    const absolutePath = join(absoluteRoot, entry.name);
    const relativePath = toPosix(relative(root, absolutePath));
    if (entry.isDirectory()) documents.push(...await collectMarkdown(root, relativePath));
    if (entry.isFile() && entry.name.endsWith(".md")) {
      documents.push({ path: relativePath, content: await readFile(absolutePath, "utf8") });
    }
  }
  return documents;
}

function assertIndexLinks(root, documents) {
  for (const document of documents.filter((item) => item.path.endsWith("/index.md"))) {
    for (const match of document.content.matchAll(/\]\((\.\/[^)]+\.md)\)/g)) {
      const target = resolve(root, dirname(document.path), match[1]);
      assert(existsSync(target), `broken Trellis spec index link: ${document.path} -> ${match[1]}`);
    }
  }
}

function requiredReadmeTokens() {
  return [
    "cdp status", "cdp workspace", "cdp hook trust", "cdp hook revoke",
    "--dry-run", "--yes", "--jobs", "--refresh", "-PassThru", "-WhatIf",
    "-Confirm", "-AllowHook", "--allow-hook", "--no-hook",
    "CDP_STATUS_CONCURRENCY", "CDP_STATUS_CACHE_TTL", "CDP_STATUS_TIMEOUT_SECONDS",
    "~/.cdp/config", "~/.cdp/state.json", "workspaces.json", "~/.cdp/hook-trust.json",
    "Invoke-PowerShellQualityGate.ps1", "Build-ShellScript.sh --check",
    "Test-ScoopPackage.sh", "Test-Documentation.mjs", "pnpm --dir tests/web test",
    "Bash 3.2"
  ];
}

export async function validateDocumentation(root = defaultRoot) {
  const repositoryRoot = resolve(root);
  const paths = ["README.md", "README_ZH.md", "CONTRIBUTING.md", "AGENTS.md", "CLAUDE.md"];
  const documents = await Promise.all(paths.map(async (path) => ({
    path,
    content: await readFile(resolve(repositoryRoot, path), "utf8")
  })));
  const byPath = new Map(documents.map((document) => [document.path, document.content]));
  const english = byPath.get("README.md");
  const chinese = byPath.get("README_ZH.md");
  const manifest = await readFile(resolve(repositoryRoot, "cdp.psd1"), "utf8");
  const exports = [
    ...parseManifestExports(manifest, "FunctionsToExport"),
    ...parseManifestExports(manifest, "AliasesToExport")
  ];

  compareReadmeStructures(english, chinese);
  for (const [label, content] of [["README.md", english], ["README_ZH.md", chinese]]) {
    assertTokensDocumented(content, exports, label);
    assertTokensDocumented(content, requiredReadmeTokens(), label);
  }

  const specs = [
    ...await collectMarkdown(repositoryRoot, ".trellis/spec/backend"),
    ...await collectMarkdown(repositoryRoot, ".trellis/spec/frontend")
  ];
  assertNoSpecPlaceholders(specs);
  assertIndexLinks(repositoryRoot, specs);
  assertNoStaleGuidance(documents);
  assertTokensDocumented(byPath.get("AGENTS.md"), [
    "src/PowerShell/*.ps1", "src/Shell/*.sh", "Conventional Commits"
  ], "AGENTS.md");
  assertTokensDocumented(byPath.get("CONTRIBUTING.md"), [
    "Invoke-PowerShellQualityGate.ps1", "pnpm --dir tests/web test", "test(web):"
  ], "CONTRIBUTING.md");
  assertTokensDocumented(byPath.get("CLAUDE.md"), ["AGENTS.md"], "CLAUDE.md");
  return { exportCount: exports.length, specCount: specs.length };
}

if (process.argv[1] && resolve(process.argv[1]) === scriptPath) {
  try {
    const result = await validateDocumentation(process.env.CDP_TEST_REPO_ROOT || defaultRoot);
    console.log(`Documentation gate passed: ${result.exportCount} exported commands and ${result.specCount} specs validated.`);
  } catch (error) {
    console.error(`Documentation gate failed: ${error.message}`);
    process.exitCode = 1;
  }
}
