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
      require 'fileutils'

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

      exports_dir = Rails.root.join('tmp', 'playwright_exports')
      FileUtils.mkdir_p(exports_dir)

      export_prefix = '${rubyString(email)}'.parameterize
      csv_path = exports_dir.join("#{export_prefix}-catalogo.csv")
      pdf_path = exports_dir.join("#{export_prefix}-catalogo.pdf")
      File.write(csv_path, "modelo,marca\\nFord Escort RS,Matchbox\\n")
      File.binwrite(pdf_path, "%PDF-1.4\\n% Playwright export fixture\\n")

      File.open(csv_path) do |file|
        user.collection_exports.create!(format_type: 'csv', status: 'completed', file: file)
      end

      File.open(pdf_path) do |file|
        user.collection_exports.create!(format_type: 'pdf', status: 'completed', file: file)
      end
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
    await expect(page.getByText(/Atualize login, senha, link público/i)).toBeVisible();
    await expect(page.getByRole("heading", { name: "Login e segurança" })).toBeVisible();
    await expect(page.getByRole("heading", { name: "Link público do acervo" })).toBeVisible();
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
    await expect(page.getByRole("link", { name: /Baixar CSV/i })).toBeVisible();
    await expect(page.getByRole("link", { name: /Baixar PDF/i })).toBeVisible();

    const exportStyles = await page.evaluate(() => {
      const groups = [...document.querySelectorAll(".collection-secondary-menu .export-button-group")];
      const downloadButtons = [...document.querySelectorAll(".collection-secondary-menu .export-download-button")];
      const regenerateButtons = [...document.querySelectorAll(".collection-secondary-menu .export-regenerate-button")];

      return {
        groupRadii: groups.map((group) => Number.parseFloat(getComputedStyle(group).borderTopLeftRadius)),
        groupOverflows: groups.map((group) => getComputedStyle(group).overflow),
        downloadRadii: downloadButtons.map((button) => [
          Number.parseFloat(getComputedStyle(button).borderTopLeftRadius),
          Number.parseFloat(getComputedStyle(button).borderTopRightRadius),
        ]),
        regenerateRadii: regenerateButtons.map((button) => [
          Number.parseFloat(getComputedStyle(button).borderTopLeftRadius),
          Number.parseFloat(getComputedStyle(button).borderTopRightRadius),
        ]),
        regenerateBorderLefts: regenerateButtons.map((button) => getComputedStyle(button).borderLeftWidth),
        downloadBackgrounds: downloadButtons.map((button) => getComputedStyle(button).backgroundColor),
        regenerateBackgrounds: regenerateButtons.map((button) => getComputedStyle(button).backgroundColor),
        horizontalOverflow: document.documentElement.scrollWidth > window.innerWidth,
      };
    });

    expect(exportStyles.groupRadii.every((radius) => radius <= 8)).toBe(true);
    expect(exportStyles.groupOverflows.every((overflow) => overflow === "hidden")).toBe(true);
    expect(exportStyles.downloadRadii.every(([left, right]) => left === 0 && right === 0)).toBe(true);
    expect(exportStyles.regenerateRadii.every(([left, right]) => left === 0 && right === 0)).toBe(true);
    expect(exportStyles.regenerateBorderLefts.every((width) => width === "1px")).toBe(true);
    expect(exportStyles.downloadBackgrounds.every((color) => !isPurpleOrBlue(color))).toBe(true);
    expect(exportStyles.regenerateBackgrounds.every((color) => !isPurpleOrBlue(color))).toBe(true);
    expect(exportStyles.horizontalOverflow).toBe(false);
  });
});
