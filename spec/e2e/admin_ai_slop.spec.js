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

test.describe("admin visual identity", () => {
  let email;

  test.beforeEach(() => {
    email = `playwright-admin-ai-slop-${Date.now()}@example.com`;

    runRails(`
      user = User.create!(
        name: 'Playwright Admin',
        email: '${rubyString(email)}',
        password: '${PASSWORD}',
        password_confirmation: '${PASSWORD}',
        initial_setup_completed: true,
        admin: true
      )

      user.cars.create!(name: 'Porsche 911 Carrera', brand: 'Porsche', color: 'Vermelho', year: 1987)
    `);
  });

  test.afterEach(() => {
    if (!email) return;

    runRails(`User.where(email: '${rubyString(email)}').each(&:destroy)`);
  });

  test("uses operational catalog styling on dashboard and user list", async ({ page }) => {
    await page.setViewportSize({ width: 1366, height: 768 });
    await page.addInitScript(() => localStorage.setItem("theme", "light"));

    await page.goto(`${BASE_URL}/users/sign_in`);
    await page.fill("#user_email_login", email);
    await page.fill("#user_password_login", PASSWORD);
    await page.click("#sign_in_submit");
    await expect(page).toHaveURL(/\/admin/);

    await page.goto(`${BASE_URL}/admin`);
    await expect(page.getByRole("heading", { name: /Painel administrativo/i })).toBeVisible();
    await expect(page.getByText(/Leitura operacional de usuarios/i)).toBeVisible();
    await expect(page.getByText("Atalhos operacionais")).toBeVisible();

    const dashboardStyles = await page.evaluate(() => {
      const card = document.querySelector(".premium-card");
      const activeNav = document.querySelector(".admin-sidebar .nav-link.active");
      const action = document.querySelector(".btn-soft-secondary");
      const cardStyles = getComputedStyle(card);
      const activeNavStyles = getComputedStyle(activeNav);
      const actionStyles = getComputedStyle(action);

      return {
        cardRadius: Number.parseFloat(cardStyles.borderTopLeftRadius),
        activeBackground: activeNavStyles.backgroundColor,
        activeShadow: activeNavStyles.boxShadow,
        actionRadius: Number.parseFloat(actionStyles.borderTopLeftRadius),
        horizontalOverflow: document.documentElement.scrollWidth > window.innerWidth,
      };
    });

    expect(dashboardStyles.cardRadius).toBeLessThanOrEqual(8);
    expect(dashboardStyles.actionRadius).toBeLessThanOrEqual(8);
    expect(isPurpleOrBlue(dashboardStyles.activeBackground)).toBe(false);
    expect(dashboardStyles.activeShadow).not.toContain("99, 102, 241");
    expect(dashboardStyles.horizontalOverflow).toBe(false);

    await page.goto(`${BASE_URL}/admin/users`);
    await expect(page.getByRole("heading", { name: "Usuarios" })).toBeVisible();
    await expect(page.getByPlaceholder("Filtrar por nome ou e-mail")).toBeVisible();

    const usersStyles = await page.evaluate(() => {
      const card = document.querySelector(".premium-card");
      const search = document.querySelector("input[name='q']");
      const submit = document.querySelector("input[type='submit']");
      const badge = document.querySelector(".badge");
      const cardStyles = getComputedStyle(card);
      const searchStyles = getComputedStyle(search);
      const submitStyles = getComputedStyle(submit);
      const badgeStyles = getComputedStyle(badge);

      return {
        cardRadius: Number.parseFloat(cardStyles.borderTopLeftRadius),
        searchRadius: Number.parseFloat(searchStyles.borderTopRightRadius),
        submitRadius: Number.parseFloat(submitStyles.borderTopLeftRadius),
        submitBackground: submitStyles.backgroundColor,
        badgeRadius: Number.parseFloat(badgeStyles.borderTopLeftRadius),
      };
    });

    expect(usersStyles.cardRadius).toBeLessThanOrEqual(8);
    expect(usersStyles.searchRadius).toBeLessThanOrEqual(8);
    expect(usersStyles.submitRadius).toBeLessThanOrEqual(8);
    expect(usersStyles.badgeRadius).toBeLessThanOrEqual(8);
    expect(isPurpleOrBlue(usersStyles.submitBackground)).toBe(false);
  });
});
