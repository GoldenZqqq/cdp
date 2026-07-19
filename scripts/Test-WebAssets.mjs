import { createHash } from "node:crypto";
import { existsSync } from "node:fs";
import { readFile, readdir, stat } from "node:fs/promises";
import { dirname, extname, isAbsolute, join, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

const scriptPath = fileURLToPath(import.meta.url);
const defaultRoot = resolve(dirname(scriptPath), "..");

function toPosix(value) {
  return value.split(sep).join("/");
}

function formatBytes(value) {
  return new Intl.NumberFormat("en-US").format(value);
}

function isExternalReference(value) {
  return /^(?:[a-z][a-z\d+.-]*:|\/\/|#|data:|mailto:|tel:)/i.test(value);
}

function cleanReference(value) {
  return value.trim().replace(/^['"]|['"]$/g, "").split(/[?#]/, 1)[0];
}

function extractReferences(content, extension) {
  const values = [];
  const attributePattern = /\b(?:href|poster|src|srcset)\s*=\s*["']([^"']+)["']/gi;
  const cssPattern = /\burl\(\s*([^)]+?)\s*\)/gi;
  const markdownPattern = /!?\[[^\]]*\]\(([^)\s]+)(?:\s+["'][^"']*["'])?\)/g;
  for (const match of content.matchAll(attributePattern)) values.push(match[1]);
  if (extension === ".css") {
    for (const match of content.matchAll(cssPattern)) values.push(match[1]);
  }
  if (extension === ".md") {
    for (const match of content.matchAll(markdownPattern)) values.push(match[1]);
  }
  return values.flatMap((value) => value.split(",").map((part) => cleanReference(part.split(/\s+/, 1)[0])));
}

function resolveLocalReference(root, sourcePath, value) {
  if (!value || isExternalReference(value)) return null;
  const base = dirname(resolve(root, sourcePath));
  const candidate = isAbsolute(value) ? resolve(root, `.${value}`) : resolve(base, value);
  if (candidate !== root && !candidate.startsWith(`${root}${sep}`)) {
    throw new Error(`local resource escapes repository: ${sourcePath} -> ${value}`);
  }
  return candidate;
}

async function collectFiles(root, relativeRoot) {
  const absoluteRoot = resolve(root, relativeRoot);
  if (!existsSync(absoluteRoot)) return [];
  const files = [];
  const entries = await readdir(absoluteRoot, { withFileTypes: true });
  for (const entry of entries) {
    const child = join(absoluteRoot, entry.name);
    const childRelative = toPosix(relative(root, child));
    if (entry.isDirectory()) files.push(...await collectFiles(root, childRelative));
    if (entry.isFile()) files.push(childRelative);
  }
  return files;
}

async function collectReferencedPaths(root, policy) {
  const references = new Set();
  for (const sourcePath of policy.referenceFiles) {
    const absoluteSource = resolve(root, sourcePath);
    if (!existsSync(absoluteSource)) throw new Error(`reference file is missing: ${sourcePath}`);
    const content = await readFile(absoluteSource, "utf8");
    for (const value of extractReferences(content, extname(sourcePath).toLowerCase())) {
      const candidate = resolveLocalReference(root, sourcePath, value);
      if (!candidate) continue;
      if (!existsSync(candidate)) throw new Error(`missing local resource: ${sourcePath} -> ${value}`);
      references.add(toPosix(relative(root, candidate)));
    }
  }
  return references;
}

async function inspectMediaFile(root, filePath) {
  const absolutePath = resolve(root, filePath);
  const metadata = await stat(absolutePath);
  const content = await readFile(absolutePath);
  return {
    path: filePath,
    size: metadata.size,
    hash: createHash("sha256").update(content).digest("hex")
  };
}

function assertFileBudgets(files, policy) {
  for (const file of files) {
    const extension = extname(file.path).toLowerCase();
    const maximum = policy.legacyFileMaxBytes[file.path] ?? policy.defaultMaxBytes[extension];
    if (!Number.isInteger(maximum)) throw new Error(`missing media budget for extension: ${extension}`);
    if (file.size > maximum) {
      throw new Error(`media file exceeds budget: ${file.path} is ${file.size} bytes; maximum is ${maximum}`);
    }
  }
}

function assertUnreferencedPublished(files, references, policy) {
  const allowed = new Set(policy.allowedUnreferencedPublished);
  const unexpected = files.filter((file) => !references.has(file.path) && !allowed.has(file.path));
  if (unexpected.length > 0) {
    throw new Error(`unreferenced published media: ${unexpected.map((file) => file.path).join(", ")}`);
  }
}

function normalizeGroup(paths) {
  return [...paths].sort().join("\n");
}

function assertDuplicateGroups(files, policy) {
  const byHash = new Map();
  for (const file of files) {
    const group = byHash.get(file.hash) || [];
    group.push(file.path);
    byHash.set(file.hash, group);
  }
  const allowed = new Set(policy.allowedDuplicateGroups.map(normalizeGroup));
  const unexpected = [...byHash.values()].filter((group) => group.length > 1 && !allowed.has(normalizeGroup(group)));
  if (unexpected.length > 0) {
    throw new Error(`unregistered duplicate media: ${unexpected.map(normalizeGroup).join(" | ")}`);
  }
}

function sumBytes(files) {
  return files.reduce((sum, file) => sum + file.size, 0);
}

function assertTotalBudgets(publishedFiles, allFiles, policy) {
  const publishedBytes = sumBytes(publishedFiles);
  const repositoryBytes = sumBytes(allFiles);
  if (publishedBytes > policy.maxPublishedBytes) {
    throw new Error(`published media total exceeds budget: ${publishedBytes} > ${policy.maxPublishedBytes}`);
  }
  if (repositoryBytes > policy.maxRepositoryMediaBytes) {
    throw new Error(`repository media total exceeds budget: ${repositoryBytes} > ${policy.maxRepositoryMediaBytes}`);
  }
  return { publishedBytes, repositoryBytes };
}

function isMediaPath(filePath, extensions) {
  return extensions.has(extname(filePath).toLowerCase());
}

async function loadPolicy(root, policyPath) {
  const absolutePath = resolve(root, policyPath);
  const policy = JSON.parse(await readFile(absolutePath, "utf8"));
  if (policy.version !== 1) throw new Error(`unsupported media policy version: ${policy.version}`);
  return policy;
}

export async function validateWebAssets(root = defaultRoot, policyPath = "docs/media-policy.json") {
  const repositoryRoot = resolve(root);
  const policy = await loadPolicy(repositoryRoot, policyPath);
  const extensions = new Set(policy.mediaExtensions.map((value) => value.toLowerCase()));
  const references = await collectReferencedPaths(repositoryRoot, policy);
  const publishedPaths = (await Promise.all(policy.publishedRoots.map((entry) => collectFiles(repositoryRoot, entry))))
    .flat().filter((filePath) => isMediaPath(filePath, extensions));
  const sourcePaths = (await Promise.all(policy.sourceRoots.map((entry) => collectFiles(repositoryRoot, entry))))
    .flat().filter((filePath) => isMediaPath(filePath, extensions));
  const publishedFiles = await Promise.all(publishedPaths.map((filePath) => inspectMediaFile(repositoryRoot, filePath)));
  const allFiles = [...publishedFiles, ...await Promise.all(sourcePaths.map((filePath) => inspectMediaFile(repositoryRoot, filePath)))];

  assertFileBudgets(allFiles, policy);
  assertUnreferencedPublished(publishedFiles, references, policy);
  assertDuplicateGroups(allFiles, policy);
  const totals = assertTotalBudgets(publishedFiles, allFiles, policy);
  return { ...totals, publishedCount: publishedFiles.length, repositoryCount: allFiles.length };
}

if (process.argv[1] && resolve(process.argv[1]) === scriptPath) {
  try {
    const result = await validateWebAssets(process.env.CDP_TEST_REPO_ROOT || defaultRoot, process.env.CDP_MEDIA_POLICY || "docs/media-policy.json");
    console.log(
      `Web asset gate passed: ${result.publishedCount} published and ${result.repositoryCount} repository media files; ` +
      `${formatBytes(result.publishedBytes)}/${formatBytes(result.repositoryBytes)} bytes.`
    );
  } catch (error) {
    console.error(`Web asset gate failed: ${error.message}`);
    process.exitCode = 1;
  }
}
