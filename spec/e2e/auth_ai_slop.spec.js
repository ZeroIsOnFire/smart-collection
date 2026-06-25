import { test, expect } from "@playwright/test";

const BASE_URL = process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:3000";

function rgbChannels(color) {
  return color.match(/\d+(\.\d+)?/g).slice(0, 3).map(Number);
}

function isPurpleOrBlue(color) {
  const [red, green, blue] = rgbChannels(color);

  return blue > red + 20 && blue > green + 10;
}

async function expectSolidCatalogAuth(page, path) {
  await page.goto(`${BASE_URL}${path}`);

  const card = page.locator(".auth-card");
  const submit = card.locator(".btn-primary").first();
  const link = card.locator(".auth-links a").first();
  const focusedInput = card.locator(".form-input").first();

  await expect(card).toBeVisible();
  await expect(submit).toBeVisible();
  await focusedInput.focus();

  const styles = await page.evaluate(() => {
    const cardElement = document.querySelector(".auth-card");
    const buttonElement = cardElement.querySelector(".btn-primary");
    const linkElement = cardElement.querySelector(".auth-links a");
    const inputElement = cardElement.querySelector(".form-input");

    return {
      cardRadius: getComputedStyle(cardElement).borderRadius,
      cardBackground: getComputedStyle(cardElement).backgroundColor,
      buttonBackground: getComputedStyle(buttonElement).backgroundImage,
      buttonColor: getComputedStyle(buttonElement).backgroundColor,
      inputBorder: getComputedStyle(inputElement).borderColor,
      linkColor: getComputedStyle(linkElement).color,
      horizontalOverflow: document.documentElement.scrollWidth > window.innerWidth,
    };
  });

  expect(styles.cardRadius).toBe("8px");
  expect(styles.buttonBackground).toBe("none");
  expect(isPurpleOrBlue(styles.buttonColor)).toBe(false);
  expect(isPurpleOrBlue(styles.inputBorder)).toBe(false);
  expect(isPurpleOrBlue(styles.linkColor)).toBe(false);
  expect(styles.horizontalOverflow).toBe(false);
}

test.describe("auth visual identity", () => {
  test("uses solid catalog palette instead of purple SaaS gradients", async ({ page }) => {
    await page.setViewportSize({ width: 1366, height: 768 });

    await expectSolidCatalogAuth(page, "/users/sign_in");
    await expectSolidCatalogAuth(page, "/users/sign_up");

    await page.screenshot({ path: "test-results/auth-ai-slop-desktop.png", fullPage: true });

    await page.setViewportSize({ width: 390, height: 844 });
    await expectSolidCatalogAuth(page, "/users/sign_in");

    const cardBox = await page.locator(".auth-card").boundingBox();
    expect(cardBox.x).toBeGreaterThanOrEqual(0);
    expect(cardBox.x + cardBox.width).toBeLessThanOrEqual(390);

    await page.screenshot({ path: "test-results/auth-ai-slop-mobile.png", fullPage: true });
  });
});
