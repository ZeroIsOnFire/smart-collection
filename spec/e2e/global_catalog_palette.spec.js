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

test.describe("global catalog palette", () => {
  let email;

  test.beforeEach(() => {
    email = `playwright-global-palette-${Date.now()}@example.com`;

    runRails(`
      email = '${rubyString(email)}'
      user = User.create!(
        name: 'Playwright Catalogo',
        email: email,
        password: '${PASSWORD}',
        password_confirmation: '${PASSWORD}',
        initial_setup_completed: true
      )

      user.cars.create!(
        name: 'Porsche 911 Carrera',
        brand: 'Porsche',
        color: 'Vermelho',
        year: 1987
      )
    `);
  });

  test.afterEach(() => {
    if (!email) return;

    runRails(`
      User.where(email: '${rubyString(email)}').each(&:destroy)
    `);
  });

  test("renders private catalog controls without SaaS purple gradients or glass blur", async ({ page }) => {
    await page.setViewportSize({ width: 1366, height: 768 });
    await page.addInitScript(() => localStorage.setItem("theme", "light"));

    await page.goto(`${BASE_URL}/users/sign_in`);
    await page.fill("#user_email_login", email);
    await page.fill("#user_password_login", PASSWORD);
    await page.click("#sign_in_submit");
    await expect(page).toHaveURL(/\/cars/);

    const button = page.locator(".btn-premium").first();
    const navbar = page.locator(".navbar").first();
    const card = page.locator(".premium-card").first();

    await expect(button).toBeVisible();
    await expect(card).toBeVisible();

    const styles = await page.evaluate(() => {
      const root = getComputedStyle(document.documentElement);
      const buttonElement = document.querySelector(".btn-premium");
      const navbarElement = document.querySelector(".navbar");
      const cardElement = document.querySelector(".premium-card");
      const buttonStyles = getComputedStyle(buttonElement);
      const buttonAfter = getComputedStyle(buttonElement, "::after");
      const navbarStyles = getComputedStyle(navbarElement);
      const cardStyles = getComputedStyle(cardElement);

      return {
        primaryToken: root.getPropertyValue("--primary-gradient").trim(),
        premiumToken: root.getPropertyValue("--premium-indigo").trim(),
        glassBgToken: root.getPropertyValue("--glass-bg").trim(),
        buttonBackgroundImage: buttonStyles.backgroundImage,
        buttonBackgroundColor: buttonStyles.backgroundColor,
        buttonAfterContent: buttonAfter.content,
        navbarBackdropFilter: navbarStyles.backdropFilter || navbarStyles.webkitBackdropFilter,
        navbarBackground: navbarStyles.backgroundColor,
        cardShadow: cardStyles.boxShadow,
        horizontalOverflow: document.documentElement.scrollWidth > window.innerWidth,
      };
    });

    expect(styles.primaryToken).not.toContain("linear-gradient");
    expect(styles.primaryToken).not.toContain("#4f46e5");
    expect(styles.primaryToken).not.toContain("#7c3aed");
    expect(styles.premiumToken).not.toBe("#4f46e5");
    expect(styles.glassBgToken).not.toContain("rgba");
    expect(styles.buttonBackgroundImage).toBe("none");
    expect(styles.buttonAfterContent).toBe("none");
    expect(isPurpleOrBlue(styles.buttonBackgroundColor)).toBe(false);
    expect(styles.navbarBackdropFilter).toBe("none");
    expect(styles.navbarBackground).not.toContain("rgba");
    expect(styles.cardShadow).not.toContain("99, 102, 241");
    expect(styles.horizontalOverflow).toBe(false);
  });
});
