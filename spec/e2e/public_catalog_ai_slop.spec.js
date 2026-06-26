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

test.describe("public catalog anti slop pass", () => {
  let email;
  let shareToken;

  test.beforeEach(() => {
    const timestamp = Date.now();
    email = `playwright-public-catalog-${timestamp}@example.com`;
    shareToken = `playwright-public-catalog-${timestamp}`;

    runRails(`
      user = User.create!(
        name: 'Oficina Teste',
        email: '${rubyString(email)}',
        password: '${PASSWORD}',
        password_confirmation: '${PASSWORD}',
        initial_setup_completed: true,
        sharing_enabled: true,
        share_token: '${rubyString(shareToken)}'
      )

      user.cars.create!(
        name: 'Porsche 911 Carrera',
        brand: 'Mini GT',
        color: 'Prata',
        year: 1988,
        size: '1:64',
        observations: 'Miniatura com rodas de borracha.'
      )
    `);
  });

  test.afterEach(() => {
    if (!email) return;

    runRails(`User.where(email: '${rubyString(email)}').each(&:destroy)`);
  });

  test("shows concrete home, public showcase and private catalog copy", async ({ page }) => {
    await page.setViewportSize({ width: 1366, height: 768 });
    await page.addInitScript(() => localStorage.setItem("theme", "light"));

    await page.goto(BASE_URL);
    await expect(page.getByText("Cadastre cada carro com foto, escala, cor e observacoes.")).toBeVisible();
    await expect(page.getByRole("link", { name: /Criar catalogo/i }).first()).toBeVisible();
    await expect(page.getByText(/Registre marca, modelo, ano, escala, cor/i)).toBeVisible();
    await expect(page.getByText(/Sua colecao elevada/i)).toHaveCount(0);
    await expect(page.getByText(/IA avancada/i)).toHaveCount(0);

    const homeStyles = await page.evaluate(() => {
      const sample = document.querySelector(".catalog-sample-card");
      const badge = document.querySelector(".hero-section .badge");
      const sampleStyles = getComputedStyle(sample);
      const badgeStyles = getComputedStyle(badge);

      return {
        sampleBackgroundImage: sampleStyles.backgroundImage,
        sampleRadius: Number.parseFloat(sampleStyles.borderTopLeftRadius),
        badgeRadius: Number.parseFloat(badgeStyles.borderTopLeftRadius),
        horizontalOverflow: document.documentElement.scrollWidth > window.innerWidth,
      };
    });

    expect(homeStyles.sampleBackgroundImage).toBe("none");
    expect(homeStyles.sampleRadius).toBeLessThanOrEqual(12);
    expect(homeStyles.badgeRadius).toBeLessThanOrEqual(8);
    expect(homeStyles.horizontalOverflow).toBe(false);

    await page.goto(`${BASE_URL}/s/${shareToken}`);
    await expect(page.getByText(/Navegue pelos carros cadastrados/i)).toBeVisible();
    await expect(page.getByPlaceholder(/Buscar por modelo, marca, ano ou cor/i)).toBeVisible();
    await expect(page.locator("#cars_grid_inner .card-title", { hasText: "Porsche 911 Carrera" })).toBeVisible();
    await expect(page.getByText(/curadoria/i)).toHaveCount(0);

    const publicStyles = await page.evaluate(() => {
      const rootStyles = getComputedStyle(document.documentElement);
      const navbar = document.querySelector(".navbar-glass");
      const search = document.querySelector(".premium-search-container");
      const toggle = document.querySelector(".public-view-toggle");
      const stat = document.querySelector(".public-collection-stat");
      const navbarStyles = getComputedStyle(navbar);
      const searchStyles = getComputedStyle(search);
      const toggleStyles = getComputedStyle(toggle);
      const statStyles = getComputedStyle(stat);

      return {
        primary: rootStyles.getPropertyValue("--public-primary").trim(),
        navbarBackdrop: navbarStyles.backdropFilter,
        searchRadius: Number.parseFloat(searchStyles.borderTopLeftRadius),
        toggleRadius: Number.parseFloat(toggleStyles.borderTopLeftRadius),
        statRadius: Number.parseFloat(statStyles.borderTopLeftRadius),
      };
    });

    expect(publicStyles.primary).not.toBe("#818cf8");
    expect(isPurpleOrBlue(publicStyles.primary)).toBe(false);
    expect(publicStyles.navbarBackdrop).toBe("none");
    expect(publicStyles.searchRadius).toBeLessThanOrEqual(8);
    expect(publicStyles.toggleRadius).toBeLessThanOrEqual(8);
    expect(publicStyles.statRadius).toBeLessThanOrEqual(8);

    await page.goto(`${BASE_URL}/users/sign_in`);
    await page.fill("#user_email_login", email);
    await page.fill("#user_password_login", PASSWORD);
    await page.click("#sign_in_submit");
    await expect(page).toHaveURL(/\/cars/);

    await expect(page.getByText(/Ficha do acervo com foto, escala, marca/i)).toBeVisible();
    await expect(page.getByPlaceholder(/Buscar por modelo, marca, ano, escala ou tag/i)).toBeVisible();
    await expect(page.locator(".collection-secondary-actions > button")).toBeVisible();
    await expect(page.getByText(/Sua colecao pessoal/i)).toHaveCount(0);

    const privateStyles = await page.evaluate(() => {
      const search = document.querySelector(".premium-search-container");
      const toggle = document.querySelector(".collection-view-controls .btn-group");
      const action = document.querySelector(".collection-primary-actions .btn-premium");
      const searchStyles = getComputedStyle(search);
      const toggleStyles = getComputedStyle(toggle);
      const actionStyles = getComputedStyle(action);

      return {
        searchRadius: Number.parseFloat(searchStyles.borderTopLeftRadius),
        toggleRadius: Number.parseFloat(toggleStyles.borderTopLeftRadius),
        actionRadius: Number.parseFloat(actionStyles.borderTopLeftRadius),
        actionBackground: actionStyles.backgroundColor,
        horizontalOverflow: document.documentElement.scrollWidth > window.innerWidth,
      };
    });

    expect(privateStyles.searchRadius).toBeLessThanOrEqual(8);
    expect(privateStyles.toggleRadius).toBeLessThanOrEqual(8);
    expect(privateStyles.actionRadius).toBeLessThanOrEqual(8);
    expect(isPurpleOrBlue(privateStyles.actionBackground)).toBe(false);
    expect(privateStyles.horizontalOverflow).toBe(false);
  });
});
