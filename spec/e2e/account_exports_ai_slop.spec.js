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

test.describe("account and export controls visual identity", () => {
  let email;

  test.beforeEach(() => {
    email = `playwright-account-export-${Date.now()}@example.com`;

    runRails(`
      user = User.create!(
        name: 'Conta Exportacao',
        email: '${rubyString(email)}',
        password: '${PASSWORD}',
        password_confirmation: '${PASSWORD}',
        initial_setup_completed: true,
        sharing_enabled: true
      )

      user.cars.create!(
        name: 'Ford Escort RS',
        brand: 'Matchbox',
        color: 'Azul',
        year: 1981,
        size: '1:64',
        observations: 'Miniatura cadastrada para validar exportacao.'
      )
    `);
  });

  test.afterEach(() => {
    if (!email) return;

    runRails(`User.where(email: '${rubyString(email)}').each(&:destroy)`);
  });

  test("uses concrete account copy and solid export controls", async ({ page }) => {
    await page.setViewportSize({ width: 1366, height: 768 });
    await page.addInitScript(() => localStorage.setItem("theme", "light"));

    await page.goto(`${BASE_URL}/users/sign_in`);
    await page.fill("#user_email_login", email);
    await page.fill("#user_password_login", PASSWORD);
    await page.click("#sign_in_submit");
    await expect(page).toHaveURL(/\/cars/);

    await page.goto(`${BASE_URL}/users/edit`);
    await expect(page.getByRole("heading", { name: "Dados da conta" })).toBeVisible();
    await expect(page.getByText(/Atualize login, senha, link publico/i)).toBeVisible();
    await expect(page.getByRole("heading", { name: "Login e seguranca" })).toBeVisible();
    await expect(page.getByRole("heading", { name: "Link publico do acervo" })).toBeVisible();
    await expect(page.getByRole("button", { name: "Salvar dados da conta" })).toBeVisible();
    await expect(page.getByText(/Configurações de Conta|Perfil e Segurança|Visão Pública|Salvar Alterações/i)).toHaveCount(0);

    const accountStyles = await page.evaluate(() => {
      const cards = [...document.querySelectorAll(".card")];
      const submit = document.querySelector("input[type='submit']");
      const sharingButton = document.querySelector("#sharing_settings_toggle .btn");
      const publicLink = document.querySelector("#sharing_settings_toggle input[readonly]");
      const icon = document.querySelector(".card .bg-primary");

      return {
        cardRadii: cards.map((card) => Number.parseFloat(getComputedStyle(card).borderTopLeftRadius)),
        submitRadius: Number.parseFloat(getComputedStyle(submit).borderTopLeftRadius),
        submitBackground: getComputedStyle(submit).backgroundColor,
        sharingRadius: Number.parseFloat(getComputedStyle(sharingButton).borderTopLeftRadius),
        linkRadius: Number.parseFloat(getComputedStyle(publicLink).borderTopLeftRadius),
        iconRadius: Number.parseFloat(getComputedStyle(icon).borderTopLeftRadius),
        horizontalOverflow: document.documentElement.scrollWidth > window.innerWidth,
      };
    });

    expect(accountStyles.cardRadii.every((radius) => radius <= 8)).toBe(true);
    expect(accountStyles.submitRadius).toBeLessThanOrEqual(8);
    expect(isPurpleOrBlue(accountStyles.submitBackground)).toBe(false);
    expect(accountStyles.sharingRadius).toBeLessThanOrEqual(8);
    expect(accountStyles.linkRadius).toBeLessThanOrEqual(8);
    expect(accountStyles.iconRadius).toBeLessThanOrEqual(8);
    expect(accountStyles.horizontalOverflow).toBe(false);

    await page.goto(`${BASE_URL}/cars`);
    await page.locator(".collection-secondary-actions > button").click();
    await expect(page.getByText("Exportar coleção")).toBeVisible();
    await expect(page.getByRole("button", { name: /Exportar CSV/i })).toBeVisible();
    await expect(page.getByRole("button", { name: /Exportar PDF/i })).toBeVisible();

    const exportStyles = await page.evaluate(() => {
      const buttons = [...document.querySelectorAll(".collection-secondary-menu .btn-export-action")];

      return {
        buttonRadii: buttons.map((button) => Number.parseFloat(getComputedStyle(button).borderTopLeftRadius)),
        buttonBackgrounds: buttons.map((button) => getComputedStyle(button).backgroundColor),
        horizontalOverflow: document.documentElement.scrollWidth > window.innerWidth,
      };
    });

    expect(exportStyles.buttonRadii.every((radius) => radius <= 8)).toBe(true);
    expect(exportStyles.buttonBackgrounds.every((color) => !isPurpleOrBlue(color))).toBe(true);
    expect(exportStyles.horizontalOverflow).toBe(false);
  });
});
