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

const baseUrl = new URL(".", page.url());
const resourceUrls = {
  "index.html": new URL("index.html", baseUrl).href,
  "index.pck": new URL("index.pck", baseUrl).href,
  "index.wasm": new URL("index.wasm", baseUrl).href,
};
const resourceChecks = {};

for (const [name, assetUrl] of Object.entries(resourceUrls)) {
  const assetResponse = name === "index.html" ? response : await context.request.get(assetUrl);
  const headers = assetResponse.headers();
  resourceChecks[name] = {
    url: assetUrl,
    status: assetResponse.status(),
    ok: assetResponse.ok(),
    contentType: headers["content-type"] || null,
    contentLength: headers["content-length"] || null,
    coop: headers["cross-origin-opener-policy"] || null,
    coep: headers["cross-origin-embedder-policy"] || null,
  };

  if (!assetResponse.ok()) {
    throw new Error(name + " failed over HTTP: " + assetResponse.status());
  }
  if (headers["cross-origin-opener-policy"] || headers["cross-origin-embedder-policy"]) {
    throw new Error(name + " unexpectedly returned COOP/COEP headers: " + JSON.stringify(resourceChecks[name]));
  }

  console.log("[A1_WEB_TEST] RESOURCE_OK " + name + " " + assetResponse.status() + " " + assetUrl);
}

if (page.url().startsWith("https://")) {
  for (const item of Object.values(resourceChecks)) {
    if (!item.url.startsWith("https://")) {
      throw new Error("Live resource was not loaded over HTTPS: " + item.url);
    }
  }
  console.log("[A1_WEB_TEST] HTTPS_RESOURCES_OK");
}

console.log("[A1_WEB_TEST] COOP_COEP_ABSENT");

await page.screenshot({
  path: "artifacts/a1-" + mode + ".png",
  fullPage: true,
});

const evidence = {
  url,
  finalUrl: page.url(),
  mode,
  canvasInfo,
  bootMarker,
  consoleLines,
  pageErrors,
  resourceChecks,
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
