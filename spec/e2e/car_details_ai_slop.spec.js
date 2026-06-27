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

test.describe("car detail records visual identity", () => {
  let email;
  let shareToken;
  let carId;

  test.beforeEach(() => {
    const timestamp = Date.now();
    email = `playwright-car-details-${timestamp}@example.com`;
    shareToken = `playwright-car-details-${timestamp}`;

    carId = runRails(`
      user = User.create!(
        name: 'Detalhes Playwright',
        email: '${rubyString(email)}',
        password: '${PASSWORD}',
        password_confirmation: '${PASSWORD}',
        initial_setup_completed: true,
        ai_upscaling_enabled: true,
        sharing_enabled: true,
        share_token: '${rubyString(shareToken)}'
      )

      small_photo_path = Rails.root.join('tmp', "playwright-small-ai-#{Time.now.to_i}.jpg")
      MiniMagick::Image.open(Rails.root.join('spec/fixtures/files/car_sample.jpg')).resize('240x240').write(small_photo_path)

      car = user.cars.create!(
        name: 'Datsun 240Z Rally',
        brand: 'Tomica',
        color: 'Vermelho',
        year: 1972,
        size: '1:64',
        observations: 'Ficha com pintura de corrida, escala pequena e detalhes do lote.',
        photo_upscale_strategy: 'ai'
      )

      File.open(small_photo_path) { |file| car.original_photo = file }
      File.open(Rails.root.join('spec/fixtures/files/car_sample.jpg')) { |file| car.enhanced_photo = file }
      car.photo_variant = 'ai'
      car.save!

      puts car.id.to_s
    `);
  });

  test.afterEach(() => {
    if (!email) return;

    runRails(`User.where(email: '${rubyString(email)}').each(&:destroy)`);
  });

  test("uses solid record surfaces in private and public car details", async ({ page }) => {
    await page.setViewportSize({ width: 1366, height: 768 });
    await page.addInitScript(() => localStorage.setItem("theme", "light"));

    await page.goto(`${BASE_URL}/users/sign_in`);
    await page.fill("#user_email_login", email);
    await page.fill("#user_password_login", PASSWORD);
    await page.click("#sign_in_submit");
    await expect(page).toHaveURL(/\/cars/);

    await page.goto(`${BASE_URL}/cars/${carId}`);
    await expect(page.getByRole("link", { name: /Voltar ao acervo/i })).toBeVisible();
    await expect(page.getByRole("heading", { name: "Datsun 240Z Rally" })).toBeVisible();
    await expect(page.getByText("Tomica")).toBeVisible();
    await expect(page.getByText(/Ficha com pintura de corrida/i)).toBeVisible();
    await expect(page.getByText(/Ver Detalhes|View Details|Minha Colecao|My Collection/i)).toHaveCount(0);

    const privateStyles = await page.evaluate(() => {
      const card = document.querySelector(".car-details-card");
      const edit = document.querySelector("[id^='car_details_'] .btn-premium");
      const danger = document.querySelector("[id^='car_details_'] .btn-outline-danger");
      const brand = document.querySelector(".car-details-card .badge.text-primary");
      const aiChip = document.querySelector(".metadata-chip-ai");
      const photo = document.querySelector(".car-details-empty-photo");
      const cardStyles = getComputedStyle(card);
      const editStyles = getComputedStyle(edit);
      const dangerStyles = getComputedStyle(danger);
      const brandStyles = getComputedStyle(brand);
      const aiChipStyles = getComputedStyle(aiChip);
      const photoStyles = photo ? getComputedStyle(photo) : null;

      return {
        cardRadius: Number.parseFloat(cardStyles.borderTopLeftRadius),
        editRadius: Number.parseFloat(editStyles.borderTopLeftRadius),
        dangerRadius: Number.parseFloat(dangerStyles.borderTopLeftRadius),
        brandRadius: Number.parseFloat(brandStyles.borderTopLeftRadius),
        aiChipBackground: aiChipStyles.backgroundColor,
        aiChipBorder: aiChipStyles.borderColor,
        photoBackground: photoStyles?.backgroundColor,
        editBackground: editStyles.backgroundColor,
        horizontalOverflow: document.documentElement.scrollWidth > window.innerWidth,
      };
    });

    expect(privateStyles.cardRadius).toBeLessThanOrEqual(8);
    expect(privateStyles.editRadius).toBeLessThanOrEqual(8);
    expect(privateStyles.dangerRadius).toBeLessThanOrEqual(8);
    expect(privateStyles.brandRadius).toBeLessThanOrEqual(8);
    expect(privateStyles.aiChipBackground).toBe("rgba(0, 0, 0, 0)");
    expect(privateStyles.aiChipBorder).toBe("rgba(0, 0, 0, 0)");
    expect(isPurpleOrBlue(privateStyles.editBackground)).toBe(false);
    expect(privateStyles.horizontalOverflow).toBe(false);

    await page.goto(`${BASE_URL}/s/${shareToken}/car/${carId}`);
    await expect(page.getByRole("link", { name: /Voltar para a cole/i })).toBeVisible();
    await expect(page.getByRole("heading", { name: "Datsun 240Z Rally" })).toBeVisible();
    await expect(page.getByText("Tomica")).toBeVisible();
    await expect(page.getByText(/Ficha com pintura de corrida/i)).toBeVisible();

    const publicStyles = await page.evaluate(() => {
      const cards = [...document.querySelectorAll(".car-detail-card")];
      const brand = document.querySelector(".car-detail-card .badge.text-primary");
      const photo = document.querySelector(".public-detail-empty-photo");

      return {
        cardRadii: cards.map((card) => Number.parseFloat(getComputedStyle(card).borderTopLeftRadius)),
        brandRadius: Number.parseFloat(getComputedStyle(brand).borderTopLeftRadius),
        photoBackground: photo ? getComputedStyle(photo).backgroundColor : null,
        hasBackdropBlurClass: Boolean(document.querySelector(".backdrop-blur")),
        horizontalOverflow: document.documentElement.scrollWidth > window.innerWidth,
      };
    });

    expect(publicStyles.cardRadii.every((radius) => radius <= 8)).toBe(true);
    expect(publicStyles.brandRadius).toBeLessThanOrEqual(8);
    expect(publicStyles.hasBackdropBlurClass).toBe(false);
    expect(publicStyles.horizontalOverflow).toBe(false);
  });
});
