import { execFileSync } from "node:child_process";
import { test, expect } from "@playwright/test";

const BASE_URL = process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:3000";
const PASSWORD = "password123";

function runRails(code) {
  return execFileSync("bin/rails", ["runner", code], {
    cwd: process.cwd(),
    encoding: "utf8",
  }).trim();
}

function rubyString(value) {
  return value.replace(/\\/g, "\\\\").replace(/'/g, "\\'");
}

test.describe("autodetections panel", () => {
  test.setTimeout(90_000);

  let email;
  let pendingId;
  let processingId;

  test.beforeEach(() => {
    email = `playwright-autodetections-${Date.now()}@example.com`;

    const result = runRails(`
      email = '${rubyString(email)}'
      user = User.find_or_initialize_by(email: email)
      user.name = 'Playwright QA'
      user.password = '${PASSWORD}'
      user.password_confirmation = '${PASSWORD}'
      user.initial_setup_completed = true
      user.save!

      user.autodetections.destroy_all
      fixture = Rails.root.join('spec/fixtures/files/test_image.png')
      pending = nil
      processing = nil

      File.open(fixture) do |file|
        pending = user.autodetections.create!(status: 'pending', photo: file)
      end

      File.open(fixture) do |file|
        processing = user.autodetections.create!(status: 'processing', photo: file)
      end

      puts "AUTODETECTION_IDS=#{[pending.id.to_s, processing.id.to_s].join(',')}"
    `);

    const ids = result.match(/AUTODETECTION_IDS=([^\n]+)/);
    if (!ids) throw new Error(`Could not create autodetections: ${result}`);

    [pendingId, processingId] = ids[1].split(",");
  });

  test.afterEach(() => {
    if (!email) return;

    runRails(`
      User.where(email: '${rubyString(email)}').each(&:destroy)
    `);
  });

  test("renders icons and updates counts after status broadcasts", async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 });

    await page.goto(`${BASE_URL}/users/sign_in`);
    await page.fill("#user_email_login", email);
    await page.fill("#user_password_login", PASSWORD);
    await page.click("#sign_in_submit");
    await expect(page).toHaveURL(/\/cars/);

    const panel = page.locator("#autodetections_panel");
    await expect(panel).toContainText(/2 autodetec/);
    await expect(page.locator(".autodetection-status-chip-pending")).toContainText(/\b1\s/);
    await expect(page.locator(".autodetection-status-chip-processing")).toContainText(/\b1\s/);

    const iconFont = await page.locator(".collection-autodetections-icon .bi").evaluate((element) =>
      getComputedStyle(element, "::before").fontFamily,
    );
    expect(iconFont).toContain("bootstrap-icons");

    const fontAsset = await page.request.get(`${BASE_URL}/fonts/bootstrap-icons.woff2`);
    expect(fontAsset.ok()).toBe(true);

    const fontStatus = await page.evaluate(async () => {
      await document.fonts.ready;

      return Array.from(document.fonts)
        .filter((font) => font.family === "bootstrap-icons")
        .map((font) => font.status);
    });
    expect(fontStatus).toContain("loaded");

    runRails(`Autodetection.find('${rubyString(pendingId)}').update!(status: 'to_verify')`);
    await expect(page.locator(".autodetection-status-chip-pending")).toHaveCount(0);
    await expect(page.locator(".autodetection-status-chip-to_verify")).toContainText(/\b1\s/);
    await expect(panel).toContainText(/2 autodetec/);

    runRails(`Autodetection.find('${rubyString(processingId)}').update!(status: 'completed')`);
    await expect(page.locator(".autodetection-status-chip-processing")).toHaveCount(0);
    await expect(panel).toContainText(/1 autodetec/);
    await expect(page.locator(".autodetection-status-chip-to_verify")).toContainText(/\b1\s/);

    await page.screenshot({ path: "test-results/autodetections-panel-desktop.png", fullPage: false });

    await page.setViewportSize({ width: 390, height: 844 });
    await page.reload({ waitUntil: "domcontentloaded" });
    await expect(panel).toBeVisible();

    const panelBox = await panel.boundingBox();
    expect(panelBox.x).toBeGreaterThanOrEqual(0);
    expect(panelBox.x + panelBox.width).toBeLessThanOrEqual(390);
    await page.screenshot({ path: "test-results/autodetections-panel-mobile.png", fullPage: false });
  });
});
