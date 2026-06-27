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

function rgbChannels(color) {
  return color.match(/\d+(\.\d+)?/g).slice(0, 3).map(Number);
}

function isPurpleOrBlue(color) {
  const [red, green, blue] = rgbChannels(color);

  return blue > red + 20 && blue > green + 10;
}

test.describe("autodetection review visual identity", () => {
  test.setTimeout(90_000);

  let email;
  let autodetectionId;

  test.beforeEach(() => {
    email = `playwright-autodetection-review-${Date.now()}@example.com`;

    const result = runRails(`
      email = '${rubyString(email)}'
      user = User.create!(
        name: 'Playwright Revisao',
        email: email,
        password: '${PASSWORD}',
        password_confirmation: '${PASSWORD}',
        initial_setup_completed: true
      )

      fixture = Rails.root.join('spec/fixtures/files/test_image.png')
      autodetection = nil
      File.open(fixture) do |file|
        autodetection = user.autodetections.create!(status: 'to_verify', photo: file)
      end

      autodetection.detected_items.create!(
        label: 'Porsche 911 Carrera',
        brand: 'Porsche',
        color: 'Vermelho',
        year: 1987,
        size: '1:64',
        position_data: {
          'vertices' => [
            { 'x' => 12, 'y' => 12 },
            { 'x' => 96, 'y' => 12 },
            { 'x' => 96, 'y' => 72 },
            { 'x' => 12, 'y' => 72 }
          ]
        }
      )

      puts "AUTODETECTION_ID=#{autodetection.id}"
    `);

    const match = result.match(/AUTODETECTION_ID=([^\n]+)/);
    if (!match) throw new Error(`Could not create autodetection: ${result}`);

    autodetectionId = match[1];
  });

  test.afterEach(() => {
    if (!email) return;

    runRails(`
      User.where(email: '${rubyString(email)}').each(&:destroy)
    `);
  });

  test("uses catalog controls on manual review instead of blue gradient pills", async ({ page }) => {
    await page.setViewportSize({ width: 1366, height: 768 });
    await page.addInitScript(() => localStorage.setItem("theme", "light"));

    await page.goto(`${BASE_URL}/users/sign_in`);
    await page.fill("#user_email_login", email);
    await page.fill("#user_password_login", PASSWORD);
    await page.click("#sign_in_submit");
    await expect(page).toHaveURL(/\/cars/);

    await page.goto(`${BASE_URL}/autodetections/${autodetectionId}`);

    const reviewButton = page.locator(".btn-premium").first();
    const detectedCard = page.locator(".detected-item-card").first();

    await expect(reviewButton).toBeVisible();
    await expect(detectedCard).toBeVisible();

    const styles = await page.evaluate(() => {
      const buttonElement = document.querySelector(".btn-premium");
      const cardElement = document.querySelector(".detected-item-card");
      const inputElement = document.querySelector(".detected-item-form .form-control");
      const selectElement = document.querySelector(".detected-item-form .form-select");
      const loaderElement = document.querySelector(".detected-item-loader");
      const loaderContentElement = document.querySelector(".detected-item-loader-content");
      const buttonStyles = getComputedStyle(buttonElement);
      const buttonAfter = getComputedStyle(buttonElement, "::after");
      const cardStyles = getComputedStyle(cardElement);
      const inputStyles = getComputedStyle(inputElement);
      const selectStyles = getComputedStyle(selectElement);
      const loaderStyles = getComputedStyle(loaderElement);
      const loaderContentStyles = getComputedStyle(loaderContentElement);
      const loadingOverlay = document.createElement("div");
      const loadingContent = document.createElement("div");

      loadingOverlay.className = "turbo-loading-overlay";
      loadingContent.className = "turbo-loading-content rounded-3";
      document.body.append(loadingOverlay, loadingContent);

      const result = {
        buttonBackgroundImage: buttonStyles.backgroundImage,
        buttonBackgroundColor: buttonStyles.backgroundColor,
        buttonAfterContent: buttonAfter.content,
        buttonRadius: Number.parseFloat(buttonStyles.borderTopLeftRadius),
        cardRadius: Number.parseFloat(cardStyles.borderTopLeftRadius),
        cardBackground: cardStyles.backgroundColor,
        inputBackground: inputStyles.backgroundColor,
        inputBorder: inputStyles.borderColor,
        inputRadius: Number.parseFloat(inputStyles.borderTopLeftRadius),
        selectBackground: selectStyles.backgroundColor,
        selectBorder: selectStyles.borderColor,
        loaderBackground: loaderStyles.backgroundColor,
        loaderContentBackground: loaderContentStyles.backgroundColor,
        loadingOverlayBackground: getComputedStyle(loadingOverlay).backgroundColor,
        loadingContentRadius: Number.parseFloat(getComputedStyle(loadingContent).borderTopLeftRadius),
        hasLegacyInlineGradient: Array.from(document.querySelectorAll("style")).some((style) =>
          style.textContent.includes("linear-gradient(135deg, #0d6efd"),
        ),
        horizontalOverflow: document.documentElement.scrollWidth > window.innerWidth,
      };

      loadingOverlay.remove();
      loadingContent.remove();

      return result;
    });

    expect(styles.buttonBackgroundImage).toBe("none");
    expect(styles.buttonAfterContent).toBe("none");
    expect(isPurpleOrBlue(styles.buttonBackgroundColor)).toBe(false);
    expect(styles.buttonRadius).toBeLessThanOrEqual(8);
    expect(styles.cardRadius).toBeLessThanOrEqual(8);
    expect(styles.inputRadius).toBeLessThanOrEqual(8);
    expect(styles.loadingContentRadius).toBeLessThanOrEqual(8);
    expect(isPurpleOrBlue(styles.cardBackground)).toBe(false);
    expect(isPurpleOrBlue(styles.inputBackground)).toBe(false);
    expect(isPurpleOrBlue(styles.inputBorder)).toBe(false);
    expect(isPurpleOrBlue(styles.selectBackground)).toBe(false);
    expect(isPurpleOrBlue(styles.selectBorder)).toBe(false);
    expect(isPurpleOrBlue(styles.loaderBackground)).toBe(false);
    expect(isPurpleOrBlue(styles.loaderContentBackground)).toBe(false);
    expect(isPurpleOrBlue(styles.loadingOverlayBackground)).toBe(false);
    expect(styles.hasLegacyInlineGradient).toBe(false);
    expect(styles.horizontalOverflow).toBe(false);
  });
});
