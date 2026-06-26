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

test.describe("car form visual identity", () => {
  let email;

  test.beforeEach(() => {
    email = `playwright-car-form-${Date.now()}@example.com`;

    runRails(`
      User.create!(
        name: 'Playwright Formulario',
        email: '${rubyString(email)}',
        password: '${PASSWORD}',
        password_confirmation: '${PASSWORD}',
        initial_setup_completed: true
      )
    `);
  });

  test.afterEach(() => {
    if (!email) return;

    runRails(`
      User.where(email: '${rubyString(email)}').each(&:destroy)
    `);
  });

  test("shows concrete catalog copy with solid controls on the new car form", async ({ page }) => {
    await page.setViewportSize({ width: 1366, height: 768 });
    await page.addInitScript(() => localStorage.setItem("theme", "light"));

    await page.goto(`${BASE_URL}/users/sign_in`);
    await page.fill("#user_email_login", email);
    await page.fill("#user_password_login", PASSWORD);
    await page.click("#sign_in_submit");
    await expect(page).toHaveURL(/\/cars/);

    await page.goto(`${BASE_URL}/cars/new`);

    await expect(page.getByRole("heading", { name: /Cadastrar carro na coleção/i })).toBeVisible();
    await expect(page.getByText(/Registre foto, marca, modelo, ano, escala, cor e observações/i)).toBeVisible();
    await expect(page.getByRole("heading", { name: /Foto da miniatura/i })).toBeVisible();
    await expect(page.getByText("Adicionar foto do carro")).toBeVisible();
    await expect(page.getByText("Escala, ano e cor")).toBeVisible();

    const styles = await page.evaluate(() => {
      const formCard = document.querySelector("form .card");
      const dropzone = document.querySelector(".photo-dropzone");
      const submit = document.querySelector("input[type='submit'], button[type='submit']");
      const createAnother = document.querySelector("button[name='commit_action']");
      const brand = document.querySelector("#car_brand");

      brand.focus();

      const cardStyles = getComputedStyle(formCard);
      const dropzoneStyles = getComputedStyle(dropzone);
      const submitStyles = getComputedStyle(submit);
      const createAnotherStyles = createAnother ? getComputedStyle(createAnother) : null;
      const brandStyles = getComputedStyle(brand);

      return {
        cardRadius: Number.parseFloat(cardStyles.borderTopLeftRadius),
        dropzoneRadius: Number.parseFloat(dropzoneStyles.borderTopLeftRadius),
        dropzoneBorder: dropzoneStyles.borderColor,
        submitBackgroundImage: submitStyles.backgroundImage,
        submitBackgroundColor: submitStyles.backgroundColor,
        submitRadius: Number.parseFloat(submitStyles.borderTopLeftRadius),
        createAnotherRadius: createAnotherStyles ? Number.parseFloat(createAnotherStyles.borderTopLeftRadius) : 0,
        brandFocusShadow: brandStyles.boxShadow,
        brandFocusBorder: brandStyles.borderColor,
        horizontalOverflow: document.documentElement.scrollWidth > window.innerWidth,
      };
    });

    expect(styles.cardRadius).toBeLessThanOrEqual(8);
    expect(styles.dropzoneRadius).toBeLessThanOrEqual(8);
    expect(isPurpleOrBlue(styles.dropzoneBorder)).toBe(false);
    expect(styles.submitBackgroundImage).toBe("none");
    expect(isPurpleOrBlue(styles.submitBackgroundColor)).toBe(false);
    expect(styles.submitRadius).toBeLessThanOrEqual(8);
    expect(styles.createAnotherRadius).toBeLessThanOrEqual(8);
    expect(styles.brandFocusShadow).not.toContain("13, 110, 253");
    expect(isPurpleOrBlue(styles.brandFocusBorder)).toBe(false);
    expect(styles.horizontalOverflow).toBe(false);

    const toggleStyles = await page.evaluate(() => {
      const toggle = document.querySelector(".form-check-input");
      toggle.click();

      const checkedStyles = getComputedStyle(toggle);

      return {
        checkedBackground: checkedStyles.backgroundColor,
        checkedBorder: checkedStyles.borderColor,
      };
    });

    expect(isPurpleOrBlue(toggleStyles.checkedBackground)).toBe(false);
    expect(isPurpleOrBlue(toggleStyles.checkedBorder)).toBe(false);
  });
});
