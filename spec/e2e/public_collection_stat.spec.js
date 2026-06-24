import { execFileSync } from "node:child_process";
import { test, expect } from "@playwright/test";

const BASE_URL = process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:3000";

function runRails(code) {
  return execFileSync("bin/rails", ["runner", code], {
    cwd: process.cwd(),
    encoding: "utf8",
  }).trim();
}

function contrastRatio(foreground, background) {
  const relativeLuminance = (color) => {
    const channels = color.match(/\d+(\.\d+)?/g).slice(0, 3).map(Number);
    const srgb = channels.map((channel) => {
      const value = channel / 255;
      return value <= 0.03928 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
    });

    return (0.2126 * srgb[0]) + (0.7152 * srgb[1]) + (0.0722 * srgb[2]);
  };

  const lighter = Math.max(relativeLuminance(foreground), relativeLuminance(background));
  const darker = Math.min(relativeLuminance(foreground), relativeLuminance(background));

  return (lighter + 0.05) / (darker + 0.05);
}

test.describe("public collection stat", () => {
  let shareToken;

  test.beforeEach(() => {
    shareToken = `playwright-public-stat-${Date.now()}`;

    runRails(`
      user = User.create!(
        name: 'Playwright Público',
        email: '${shareToken}@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        initial_setup_completed: true,
        sharing_enabled: true,
        share_token: '${shareToken}'
      )

      13.times do |index|
        user.cars.create!(name: "Veiculo #{index + 1}", brand: 'Marca', color: 'Azul')
      end
    `);
  });

  test.afterEach(() => {
    if (!shareToken) return;

    runRails(`User.where(share_token: '${shareToken}').each(&:destroy)`);
  });

  test("keeps cataloged count readable in public light and dark themes", async ({ page }) => {
    await page.setViewportSize({ width: 1366, height: 768 });
    await page.addInitScript(() => localStorage.setItem("theme", "light"));
    await page.goto(`${BASE_URL}/s/${shareToken}`);

    const stat = page.locator(".public-collection-stat");
    const number = page.locator(".public-collection-stat-number");
    const label = page.locator(".public-collection-stat-label");

    await expect(number).toHaveText("13");
    await expect(label).toContainText(/veículos catalogados/i);
    await expect(stat).toBeVisible();
    await expect(number).toBeVisible();
    await expect(label).toBeVisible();

    const lightContrast = await stat.evaluate((element) => {
      const numberStyles = getComputedStyle(element.querySelector(".public-collection-stat-number"));
      const background = getComputedStyle(element).backgroundColor;

      return { color: numberStyles.color, background };
    });

    expect(contrastRatio(lightContrast.color, lightContrast.background)).toBeGreaterThanOrEqual(4.5);

    await page.screenshot({ path: "test-results/public-collection-stat-light.png", fullPage: false });

    await page.evaluate(() => localStorage.setItem("theme", "dark"));
    await page.reload({ waitUntil: "domcontentloaded" });
    await expect(number).toHaveText("13");
    await expect(label).toContainText(/veículos catalogados/i);

    const darkContrast = await stat.evaluate((element) => {
      const numberStyles = getComputedStyle(element.querySelector(".public-collection-stat-number"));
      const background = getComputedStyle(element).backgroundColor;

      return { color: numberStyles.color, background };
    });

    expect(contrastRatio(darkContrast.color, darkContrast.background)).toBeGreaterThanOrEqual(4.5);

    await page.setViewportSize({ width: 390, height: 844 });
    await page.reload({ waitUntil: "domcontentloaded" });
    await expect(stat).toBeVisible();

    const statBox = await stat.boundingBox();
    expect(statBox.x).toBeGreaterThanOrEqual(0);
    expect(statBox.x + statBox.width).toBeLessThanOrEqual(390);
    await page.screenshot({ path: "test-results/public-collection-stat-mobile.png", fullPage: false });
  });
});
