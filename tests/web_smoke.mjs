import { chromium, devices } from "playwright";
import fs from "node:fs";

const url = process.argv[2];
const mode = process.argv[3] || "desktop";
if (!url) throw new Error("Usage: node tests/web_smoke.mjs <url> [desktop|mobile]");

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

async function waitMarker(marker, timeout = 15000) {
  const started = Date.now();
  while (Date.now() - started < timeout) {
    if (consoleLines.some(line => line.includes(marker))) return true;
    await page.waitForTimeout(100);
  }
  throw new Error("Console marker not observed: " + marker);
}

function markerCount(marker) {
  return consoleLines.filter(line => line.includes(marker)).length;
}

function lastGameRunningId() {
  const line = [...consoleLines].reverse().find(item => item.includes("[A3] GAME_RUNNING"));
  if (!line) return null;
  const match = line.match(/id=([^\s]+)/);
  return match ? match[1] : null;
}

async function waitMarkerCountAbove(marker, previous, timeout = 15000) {
  const started = Date.now();
  while (Date.now() - started < timeout) {
    if (markerCount(marker) > previous) return;
    await page.waitForTimeout(100);
  }
  throw new Error("Console marker count did not increase: " + marker);
}

const response = await page.goto(url, { waitUntil: "networkidle", timeout: 120000 });
if (!response || !response.ok()) throw new Error("HTTP boot failed: " + (response ? response.status() : "no response"));

await page.waitForSelector("canvas", { state: "attached", timeout: 120000 });
await waitMarker("[A3] A3_BOOT_OK");

const canvas = page.locator("canvas");
await canvas.evaluate(node => node.focus());
await page.waitForTimeout(500);

const canvasInfo = await canvas.evaluate(node => ({
  width: node.width,
  height: node.height,
  clientWidth: node.clientWidth,
  clientHeight: node.clientHeight,
}));
if (canvasInfo.width <= 0 || canvasInfo.height <= 0 || canvasInfo.clientWidth <= 0 || canvasInfo.clientHeight <= 0) {
  throw new Error("Canvas has invalid dimensions: " + JSON.stringify(canvasInfo));
}

let keyboardFocusFlow = null;
if (mode === "desktop") {
  const launchBefore = markerCount("[A3] GAME_RUNNING");
  const returnBefore = markerCount("[A3] HUB_RETURN");

  await page.keyboard.press("Space");
  await waitMarkerCountAbove("[A3] GAME_RUNNING", launchBefore);
  const firstLaunchId = lastGameRunningId();
  if (!firstLaunchId) throw new Error("Could not resolve first launched game id.");
  await page.keyboard.press("Escape");
  await waitMarkerCountAbove("[A3] HUB_RETURN", returnBefore);

  const focusBefore = markerCount("via=move_right");
  await page.keyboard.press("ArrowRight");
  await page.waitForTimeout(300);
  if (markerCount("via=move_right") <= focusBefore) throw new Error("ArrowRight did not move Godot card focus.");

  const launchMid = markerCount("[A3] GAME_RUNNING");
  const returnMid = markerCount("[A3] HUB_RETURN");
  await page.keyboard.press("Space");
  await waitMarkerCountAbove("[A3] GAME_RUNNING", launchMid);
  const secondLaunchId = lastGameRunningId();
  if (!secondLaunchId) throw new Error("Could not resolve second launched game id.");
  if (secondLaunchId === firstLaunchId) {
    throw new Error("Focus navigation did not select a different game: " + firstLaunchId);
  }
  await page.keyboard.press("Escape");
  await waitMarkerCountAbove("[A3] HUB_RETURN", returnMid);

  keyboardFocusFlow = {
    focusNavigation: true,
    firstLaunchId,
    secondLaunchId,
    launchCount: markerCount("[A3] GAME_RUNNING"),
    hubReturnCount: markerCount("[A3] HUB_RETURN"),
  };
  console.log("[A3_WEB_TEST] KEYBOARD_FOCUS_FLOW_OK " + JSON.stringify(keyboardFocusFlow));
}

if (pageErrors.length > 0) throw new Error("Browser page errors: " + pageErrors.join(" | "));

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
  if (!assetResponse.ok()) throw new Error(name + " failed over HTTP: " + assetResponse.status());
  if (headers["cross-origin-opener-policy"] || headers["cross-origin-embedder-policy"]) {
    throw new Error(name + " unexpectedly returned COOP/COEP headers.");
  }
  console.log("[WEB_TEST] RESOURCE_OK " + name + " " + assetResponse.status() + " " + assetUrl);
}

if (page.url().startsWith("https://")) {
  for (const item of Object.values(resourceChecks)) {
    if (!item.url.startsWith("https://")) throw new Error("Live resource was not loaded over HTTPS: " + item.url);
  }
  console.log("[WEB_TEST] HTTPS_RESOURCES_OK");
}
console.log("[WEB_TEST] COOP_COEP_ABSENT");

await page.screenshot({ path: "artifacts/platform-" + mode + ".png", fullPage: true });

const evidence = {
  url,
  finalUrl: page.url(),
  mode,
  canvasInfo,
  a3BootMarker: consoleLines.some(line => line.includes("[A3] A3_BOOT_OK")),
  keyboardFocusFlow,
  consoleLines,
  pageErrors,
  resourceChecks,
  userAgent: await page.evaluate(() => navigator.userAgent),
  maxTouchPoints: await page.evaluate(() => navigator.maxTouchPoints),
  timestamp: new Date().toISOString(),
};
fs.writeFileSync("artifacts/platform-" + mode + ".json", JSON.stringify(evidence, null, 2));

console.log("[A3_WEB_TEST] " + mode.toUpperCase() + "_BOOT_OK " + JSON.stringify(canvasInfo));
await browser.close();
