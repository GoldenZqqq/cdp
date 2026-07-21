import { expect, test } from "@playwright/test";

test("persists the selected language and translated metadata", async ({ page }) => {
  await page.goto("/");
  await expect(page.locator("html")).toHaveAttribute("lang", "en");

  await page.locator('[data-language="zh-CN"]').click();
  await expect(page.locator("html")).toHaveAttribute("lang", "zh-CN");
  await expect(page).toHaveTitle("cdp — 别再找路，直接开工");
  await expect(page.locator('[data-language="zh-CN"]')).toHaveAttribute("aria-pressed", "true");
  await expect(page.locator('meta[name="description"]')).toHaveAttribute("content", /终端项目工作台/);

  await page.reload();
  await expect(page.locator("html")).toHaveAttribute("lang", "zh-CN");
  await expect(page.locator("[data-footer-docs]")).toHaveAttribute("href", /README_ZH\.md$/);
});

test("routes command and install tabs with the keyboard", async ({ page }) => {
  await page.goto("/");
  const commandTabs = page.locator("[data-command-tabs]");
  const switchTab = commandTabs.locator('[data-command="switch"]');
  const statusTab = commandTabs.locator('[data-command="status"]');

  await switchTab.focus();
  await page.keyboard.press("ArrowRight");
  await expect(statusTab).toBeFocused();
  await expect(statusTab).toHaveAttribute("aria-selected", "true");
  await expect(page.locator("#command-panel")).toHaveAttribute("aria-labelledby", "command-status-tab");
  await expect(page.locator("[data-command-output]")).toContainText("cdp status --dirty");

  const installTabs = page.locator("[data-install-tabs]");
  await installTabs.locator('[data-platform="powershell"]').focus();
  await page.keyboard.press("End");
  await expect(installTabs.locator('[data-platform="macos"]')).toBeFocused();
  await expect(page.locator("#install-panel")).toHaveAttribute("aria-labelledby", "install-macos-tab");
  await expect(page.locator("[data-install-command]")).toContainText("brew install fzf jq");
});

test("demonstrates the AI CLI context route and tool boundary", async ({ page }) => {
  await page.goto("/");
  const workflowTabs = page.locator("[data-workflow-tabs]");
  const powershellTab = workflowTabs.locator('[data-workflow-platform="powershell"]');
  const shellTab = workflowTabs.locator('[data-workflow-platform="shell"]');

  await expect(page.locator("[data-workflow-command]")).toHaveText("PS C:\\> cdp api -Open codex");
  await expect(page.locator("[data-workflow-root]")).toHaveText("C:\\Work\\my-api");
  await powershellTab.focus();
  await page.keyboard.press("ArrowRight");
  await expect(shellTab).toBeFocused();
  await expect(page.locator("#workflow-panel")).toHaveAttribute("aria-labelledby", "workflow-shell-tab");
  await expect(page.locator("[data-workflow-command]")).toHaveText("$ cdp api --open codex");
  await expect(page.locator("[data-workflow-root]")).toHaveText("~/Work/my-api");
  await expect(page.locator(".comparison-table")).toContainText("zoxide / autojump");
  await expect(page.locator(".comparison-cdp")).toContainText("cdp api -Open codex");
});

test("copies the active install command and announces success", async ({ context, page }) => {
  await context.grantPermissions(["clipboard-read", "clipboard-write"], {
    origin: "http://127.0.0.1:4173"
  });
  await page.goto("/");
  const command = await page.locator("[data-install-command]").textContent();

  await page.locator("[data-copy-target]").click();
  await expect(page.locator("[data-copy-status]")).toContainText("Command copied to the clipboard");
  await expect(page.locator("[data-copy-label]")).toHaveText("Copied");
  const normalizeNewlines = (value) => value.replace(/\r\n/g, "\n");
  await expect.poll(async () => normalizeNewlines(
    await page.evaluate(() => navigator.clipboard.readText())
  )).toBe(normalizeNewlines(command));
});

test("closes the mobile navigation with Escape and returns focus", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");
  const toggle = page.locator("[data-nav-toggle]");
  const panel = page.locator("[data-nav-panel]");

  await toggle.click();
  await expect(toggle).toHaveAttribute("aria-expanded", "true");
  await expect(panel).toHaveClass(/is-open/);

  await page.keyboard.press("Escape");
  await expect(toggle).toHaveAttribute("aria-expanded", "false");
  await expect(toggle).toBeFocused();

  await toggle.click();
  await panel.locator('a[href="#pain"]').click();
  await expect(toggle).toHaveAttribute("aria-expanded", "false");
});

test("exposes landmarks, tab semantics, status feedback, and focus styles", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("navigation", { name: "Primary navigation" })).toBeVisible();
  await expect(page.locator("main#main")).toBeVisible();
  await expect(page.getByRole("tablist")).toHaveCount(3);
  await expect(page.getByRole("status")).toHaveCount(1);

  const skipLink = page.locator(".skip-link");
  await skipLink.focus();
  await expect(skipLink).toBeFocused();
  await expect(skipLink).toHaveAttribute("href", "#main");

  const focusOutline = await page.locator('[data-command="switch"]').evaluate((element) => {
    element.focus();
    const style = getComputedStyle(element);
    return { style: style.outlineStyle, width: style.outlineWidth };
  });
  expect(focusOutline.style).not.toBe("none");
  expect(Number.parseFloat(focusOutline.width)).toBeGreaterThanOrEqual(3);
});

test("limits animations and transitions for reduced motion", async ({ page }) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/");
  await expect.poll(() => page.evaluate(() => matchMedia("(prefers-reduced-motion: reduce)").matches)).toBe(true);
  const durations = await page.locator("[data-site-header]").evaluate((element) => {
    const style = getComputedStyle(element);
    return [style.animationDuration, style.transitionDuration];
  });
  for (const value of durations.flatMap((entry) => entry.split(","))) {
    expect(Number.parseFloat(value)).toBeLessThanOrEqual(0.001);
  }
});
