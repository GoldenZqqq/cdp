import assert from "node:assert/strict";
import test from "node:test";
import {
  assertNoSpecPlaceholders,
  assertNoStaleGuidance,
  assertTokensDocumented,
  compareReadmeStructures,
  parseManifestExports
} from "../scripts/Test-Documentation.mjs";

test("accepts aligned bilingual heading and code-block structure", () => {
  const english = "## One\n```bash\necho ok\n```\n### Two\n";
  const chinese = "## 一\n```bash\necho ok\n```\n### 二\n";

  assert.doesNotThrow(() => compareReadmeStructures(english, chinese));
});

test("rejects bilingual heading drift", () => {
  assert.throws(
    () => compareReadmeStructures("## One\n### Two\n", "## 一\n"),
    /README H2\/H3 structure differs/
  );
});

test("parses manifest exports and rejects undocumented commands", () => {
  const manifest = "FunctionsToExport = @('Invoke-Cdp', 'Switch-Project')\n";
  const exports = parseManifestExports(manifest, "FunctionsToExport");

  assert.deepEqual(exports, ["Invoke-Cdp", "Switch-Project"]);
  assert.throws(() => assertTokensDocumented("Invoke-Cdp", exports, "README"), /Switch-Project/);
});

test("rejects template placeholders in Trellis specs", () => {
  assert.throws(
    () => assertNoSpecPlaceholders([{ path: "spec.md", content: "(To be filled by the team)" }]),
    /Trellis spec placeholders remain/
  );
});

test("rejects outdated architecture and commit guidance", () => {
  assert.throws(
    () => assertNoStaleGuidance([{ path: "AGENTS.md", content: "src/cdp.psm1:61-87\nAdd: old style\n" }]),
    /stale documentation guidance/
  );
});
