import { chromium, devices } from "playwright";
import fs from "node:fs";

const url = process.argv[2];
const mode = process.argv[3] || "desktop";
if (!url) {
  throw new Error("Usage: node tests/web_smoke.mjs <url> [desktop|mobile]");
}

fs.mkdirSync("artifacts", { recursive: true });

const browser = await chromium.launch({ headless: true });
const context = mode === "mobile"
  ? await browser.newContext({ ...devices["Pixel 7"] })
  : await browser.newContext({ viewport: { width: 1440, height: 900 } });

const page = await context.newPage();
const consoleLines = [];
const pageErrors = [];

page.on("console", msg => {
  const line = "[" + msg.type() + "] " + msg.text();
  consoleLines.push(line);
  console.log(line);
});
page.on("pageerror", error => {
  pageErrors.push(String(error));
  console.error("[pageerror]", error);
});

const response = await page.goto(url, { waitUntil: "networkidle", timeout: 120000 });
if (!response || !response.ok()) {
  throw new Error("HTTP boot failed: " + (response ? response.status() : "no response"));
}

await page.waitForSelector("canvas", { state: "attached", timeout: 120000 });
await page.waitForTimeout(5000);

const canvasInfo = await page.locator("canvas").evaluate(canvas => ({
  width: canvas.width,
  height: canvas.height,
  clientWidth: canvas.clientWidth,
  clientHeight: canvas.clientHeight,
}));

if (canvasInfo.width <= 0 || canvasInfo.height <= 0 || canvasInfo.clientWidth <= 0 || canvasInfo.clientHeight <= 0) {
  throw new Error("Canvas has invalid dimensions: " + JSON.stringify(canvasInfo));
}

const bootMarker = consoleLines.some(line => line.includes("A1_BOOT_OK"));
if (!bootMarker) {
  throw new Error("Godot boot marker A1_BOOT_OK was not observed in browser console.");
}
if (pageErrors.length > 0) {
  throw new Error("Browser page errors: " + pageErrors.join(" | "));
}

await page.screenshot({
  path: "artifacts/a1-" + mode + ".png",
  fullPage: true,
});

const evidence = {
  url,
  mode,
  canvasInfo,
  bootMarker,
  consoleLines,
  pageErrors,
  userAgent: await page.evaluate(() => navigator.userAgent),
  maxTouchPoints: await page.evaluate(() => navigator.maxTouchPoints),
  timestamp: new Date().toISOString(),
};
fs.writeFileSync(
  "artifacts/a1-" + mode + ".json",
  JSON.stringify(evidence, null, 2)
);

console.log("[A1_WEB_TEST] " + mode.toUpperCase() + "_BOOT_OK " + JSON.stringify(canvasInfo));
await browser.close();
