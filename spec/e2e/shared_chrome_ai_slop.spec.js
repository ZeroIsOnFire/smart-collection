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
  if (color.startsWith("#")) {
    const hex = color.replace("#", "");
    const expanded = hex.length === 3 ? hex.split("").map((digit) => digit + digit).join("") : hex;

    return [
      Number.parseInt(expanded.slice(0, 2), 16),
      Number.parseInt(expanded.slice(2, 4), 16),
      Number.parseInt(expanded.slice(4, 6), 16),
    ];
  }

  return color.match(/\d+(\.\d+)?/g).slice(0, 3).map(Number);
}

function isPurpleOrBlue(color) {
  const [red, green, blue] = rgbChannels(color);

  return blue > red + 20 && blue > green + 10;
}

test.describe("shared chrome visual identity", () => {
  let setupEmail;
  let catalogEmail;

  test.beforeEach(() => {
    const timestamp = Date.now();
    setupEmail = `playwright-setup-${timestamp}@example.com`;
    catalogEmail = `playwright-chrome-${timestamp}@example.com`;

    runRails(`
      User.create!(
        name: 'Setup Playwright',
        email: '${rubyString(setupEmail)}',
        password: '${PASSWORD}',
        password_confirmation: '${PASSWORD}',
        initial_setup_completed: false
      )

      user = User.create!(
        name: 'Chrome Playwright',
        email: '${rubyString(catalogEmail)}',
        password: '${PASSWORD}',
        password_confirmation: '${PASSWORD}',
        initial_setup_completed: true
      )

      user.cars.create!(
        name: 'Audi Quattro',
        brand: 'Hot Wheels',
        color: 'Branco',
        year: 1984,
        size: '1:64',
        observations: 'Miniatura usada para abrir modal.'
      )
    `);
  });

  test.afterEach(() => {
    runRails(`
      User.where(:email.in => ['${rubyString(setupEmail)}', '${rubyString(catalogEmail)}']).each(&:destroy)
    `);
  });

  test("keeps initial setup, navbar menu and modal surfaces solid", async ({ page }) => {
    await page.setViewportSize({ width: 1366, height: 768 });
    await page.addInitScript(() => localStorage.setItem("theme", "light"));

    await page.goto(`${BASE_URL}/users/sign_in`);
    await page.fill("#user_email_login", setupEmail);
    await page.fill("#user_password_login", PASSWORD);
    await page.click("#sign_in_submit");
    await expect(page).toHaveURL(/\/initial_setup/);

    await expect(page.getByRole("heading", { name: /Antes de/i })).toBeVisible();
    await expect(page.getByRole("button", { name: /Salvar e abrir meu acervo/i })).toBeVisible();

    const setupStyles = await page.evaluate(() => {
      const card = document.querySelector(".card");
      const badge = document.querySelector(".badge");
      const submit = document.querySelector("input[type='submit']");
      const switchInput = document.querySelector(".initial-setup-switch-input");
      const switchTrack = document.querySelector(".initial-setup-switch");
      const cardStyles = getComputedStyle(card);
      const badgeStyles = getComputedStyle(badge);
      const submitStyles = getComputedStyle(submit);
      const switchOffStyles = getComputedStyle(switchTrack);
      const switchOffBackground = switchOffStyles.backgroundColor;
      const switchOffBorder = switchOffStyles.borderColor;

      switchInput.click();

      const switchOnStyles = getComputedStyle(switchTrack);

      return {
        cardRadius: Number.parseFloat(cardStyles.borderTopLeftRadius),
        badgeRadius: Number.parseFloat(badgeStyles.borderTopLeftRadius),
        submitRadius: Number.parseFloat(submitStyles.borderTopLeftRadius),
        submitBackground: submitStyles.backgroundColor,
        switchOffBackground,
        switchOffBorder,
        switchOnBackground: switchOnStyles.backgroundColor,
        switchOnBorder: switchOnStyles.borderColor,
        horizontalOverflow: document.documentElement.scrollWidth > window.innerWidth,
      };
    });

    expect(setupStyles.cardRadius).toBeLessThanOrEqual(8);
    expect(setupStyles.badgeRadius).toBeLessThanOrEqual(8);
    expect(setupStyles.submitRadius).toBeLessThanOrEqual(8);
    expect(isPurpleOrBlue(setupStyles.submitBackground)).toBe(false);
    expect(isPurpleOrBlue(setupStyles.switchOffBackground)).toBe(false);
    expect(isPurpleOrBlue(setupStyles.switchOffBorder)).toBe(false);
    expect(isPurpleOrBlue(setupStyles.switchOnBackground)).toBe(false);
    expect(isPurpleOrBlue(setupStyles.switchOnBorder)).toBe(false);
    expect(setupStyles.horizontalOverflow).toBe(false);

    await page.evaluate(() => localStorage.setItem("theme", "dark"));
    await page.reload({ waitUntil: "domcontentloaded" });
    await expect(page.getByRole("heading", { name: /Antes de/i })).toBeVisible();

    const darkSwitchStyles = await page.evaluate(() => {
      const switchInput = document.querySelector(".initial-setup-switch-input");
      const switchTrack = document.querySelector(".initial-setup-switch");
      const switchOffStyles = getComputedStyle(switchTrack);
      const switchOffBackground = switchOffStyles.backgroundColor;
      const switchOffBorder = switchOffStyles.borderColor;

      switchInput.click();

      const switchOnStyles = getComputedStyle(switchTrack);

      return {
        switchOffBackground,
        switchOffBorder,
        switchOnBackground: switchOnStyles.backgroundColor,
        switchOnBorder: switchOnStyles.borderColor,
      };
    });

    expect(isPurpleOrBlue(darkSwitchStyles.switchOffBackground)).toBe(false);
    expect(isPurpleOrBlue(darkSwitchStyles.switchOffBorder)).toBe(false);
    expect(isPurpleOrBlue(darkSwitchStyles.switchOnBackground)).toBe(false);
    expect(isPurpleOrBlue(darkSwitchStyles.switchOnBorder)).toBe(false);

    await page.context().clearCookies();

    await page.goto(`${BASE_URL}/users/sign_in`);
    await page.fill("#user_email_login", catalogEmail);
    await page.fill("#user_password_login", PASSWORD);
    await page.click("#sign_in_submit");
    await expect(page).toHaveURL(/\/cars/);

    await page.locator(".navbar .dropdown > button").click();
    await expect(page.getByText("Chrome Playwright")).toBeVisible();

    const menuRadius = await page.locator(".navbar .dropdown-menu").evaluate((element) => (
      Number.parseFloat(getComputedStyle(element).borderTopLeftRadius)
    ));
    expect(menuRadius).toBeLessThanOrEqual(8);

    await page.keyboard.press("Escape");
    await page.locator(".collection-primary-actions a[href='/cars/new']").click();
    await expect(page.locator("#turboModal")).toBeVisible();
    const modalContent = page.locator("#turboModal .modal-content").first();
    await expect(modalContent).toBeVisible();

    const modalRadius = await modalContent.evaluate((element) => (
      Number.parseFloat(getComputedStyle(element).borderTopLeftRadius)
    ));
    expect(modalRadius).toBeLessThanOrEqual(8);
  });
});
