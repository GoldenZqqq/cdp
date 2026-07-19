import assert from "node:assert/strict";
import { mkdir, mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { validateWebAssets } from "../scripts/Test-WebAssets.mjs";

async function createFixture() {
  const root = await mkdtemp(join(tmpdir(), "cdp-web-assets-"));
  await mkdir(join(root, "docs/assets"), { recursive: true });
  await mkdir(join(root, "videos"), { recursive: true });
  await writeFile(join(root, "README.md"), "# fixture\n");
  await writeFile(join(root, "README_ZH.md"), "# fixture\n");
  await writeFile(join(root, "docs/styles.css"), "body { color: black; }\n");
  await writeFile(join(root, "docs/index.html"), '<img src="assets/hero.png" alt="fixture">\n');
  await writeFile(join(root, "docs/assets/hero.png"), "hero");
  return root;
}

async function writePolicy(root, overrides = {}) {
  const policy = {
    version: 1,
    publishedRoots: ["docs/assets"],
    sourceRoots: ["videos"],
    referenceFiles: ["README.md", "README_ZH.md", "docs/index.html", "docs/styles.css"],
    mediaExtensions: [".mp4", ".png"],
    defaultMaxBytes: { ".mp4": 10, ".png": 10 },
    legacyFileMaxBytes: {},
    maxPublishedBytes: 20,
    maxRepositoryMediaBytes: 30,
    allowedUnreferencedPublished: [],
    allowedDuplicateGroups: [],
    ...overrides
  };
  await writeFile(join(root, "docs/media-policy.json"), `${JSON.stringify(policy, null, 2)}\n`);
}

test("accepts referenced media within the configured budget", async () => {
  const root = await createFixture();
  await writePolicy(root);

  const result = await validateWebAssets(root);

  assert.equal(result.publishedCount, 1);
  assert.equal(result.repositoryCount, 1);
});

test("rejects a missing local resource", async () => {
  const root = await createFixture();
  await writeFile(join(root, "docs/index.html"), '<img src="assets/missing.png" alt="fixture">\n');
  await writePolicy(root);

  await assert.rejects(() => validateWebAssets(root), /missing local resource/);
});

test("rejects a new media file over its extension budget", async () => {
  const root = await createFixture();
  await writeFile(join(root, "docs/assets/large.mp4"), "01234567890");
  await writeFile(join(root, "docs/index.html"), [
    '<img src="assets/hero.png" alt="fixture">',
    '<video src="assets/large.mp4"></video>'
  ].join("\n"));
  await writePolicy(root, { maxPublishedBytes: 30 });

  await assert.rejects(() => validateWebAssets(root), /media file exceeds budget/);
});

test("rejects new unreferenced published media", async () => {
  const root = await createFixture();
  await writeFile(join(root, "docs/assets/unused.png"), "unused");
  await writePolicy(root);

  await assert.rejects(() => validateWebAssets(root), /unreferenced published media/);
});

test("rejects growth beyond the published total budget", async () => {
  const root = await createFixture();
  await writePolicy(root, { maxPublishedBytes: 3 });

  await assert.rejects(() => validateWebAssets(root), /published media total exceeds budget/);
});

test("rejects an unregistered duplicate group", async () => {
  const root = await createFixture();
  await writeFile(join(root, "videos/hero.png"), "hero");
  await writePolicy(root);

  await assert.rejects(() => validateWebAssets(root), /unregistered duplicate media/);
});
