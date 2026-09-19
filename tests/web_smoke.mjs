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

async function waitMarker(marker, timeout = 30000) {
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
await waitMarker("[A4] A4_BOOT_OK");

const httpIndex = consoleLines.findIndex(line => line.includes("[A4] PACK_HTTP_OK id=stub_packed"));
const loadIndex = consoleLines.findIndex(line => line.includes("[A4] PACK_LOAD_OK id=stub_packed"));
const bootIndex = consoleLines.findIndex(line => line.includes("[A4] A4_BOOT_OK"));
if (httpIndex < 0 || loadIndex < 0 || bootIndex < 0 || !(httpIndex < loadIndex && loadIndex < bootIndex)) {
  throw new Error("Runtime PCK ordering invalid: HTTP -> load_resource_pack -> A4_BOOT_OK was not observed.");
}
console.log("[A4_WEB_TEST] PACK_HTTP_LOAD_ORDER_OK");

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

let platformFlow = null;
if (mode === "desktop") {
  const rounds = [];
  for (let round = 0; round < 2; round++) {
    const ids = [];
    for (let i = 0; i < 3; i++) {
      const launchBefore = markerCount("[A3] GAME_RUNNING");
      const returnBefore = markerCount("[A3] HUB_RETURN");

      await page.keyboard.press("Space");
      await waitMarkerCountAbove("[A3] GAME_RUNNING", launchBefore);
      const id = lastGameRunningId();
      if (!id) throw new Error("Could not resolve launched game id.");
      ids.push(id);

      await page.keyboard.press("z");
      await page.waitForTimeout(80);
      await page.keyboard.press("x");
      await page.waitForTimeout(80);

      await page.keyboard.press("Escape");
      await waitMarkerCountAbove("[A3] HUB_RETURN", returnBefore);

      const returnLine = [...consoleLines].reverse().find(line => line.includes("[A3] HUB_RETURN"));
      if (!returnLine || !returnLine.includes("audio_scopes=0")) {
        throw new Error("Audio scope did not cleanly teardown after " + id);
      }

      await page.keyboard.press("ArrowRight");
      await page.waitForTimeout(120);
    }
    if (new Set(ids).size !== 3 || !ids.includes("stub_packed") || !ids.includes("stub_tall") || !ids.includes("stub_wide")) {
      throw new Error("Registry focus cycle did not launch all three games: " + JSON.stringify(ids));
    }
    rounds.push(ids);
  }

  platformFlow = {
    allGames: ["stub_packed", "stub_tall", "stub_wide"],
    rounds,
    launchCount: markerCount("[A3] GAME_RUNNING"),
    hubReturnCount: markerCount("[A3] HUB_RETURN"),
    relaunchEach: true,
    audioTeardown: true,
  };
  console.log("[A4_WEB_TEST] ALL_GAMES_RELAUNCH_FLOW_OK " + JSON.stringify(platformFlow));
}

if (pageErrors.length > 0) throw new Error("Browser page errors: " + pageErrors.join(" | "));

const baseUrl = new URL(".", page.url());
const resourceUrls = {
  "index.html": new URL("index.html", baseUrl).href,
  "index.pck": new URL("index.pck", baseUrl).href,
  "index.wasm": new URL("index.wasm", baseUrl).href,
  "packs/stub_packed.pck": new URL("packs/stub_packed.pck", baseUrl).href,
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
  a4BootMarker: consoleLines.some(line => line.includes("[A4] A4_BOOT_OK")),
  packHttpOk: httpIndex >= 0,
  packLoadOk: loadIndex >= 0,
  packLoadOrderOk: httpIndex < loadIndex && loadIndex < bootIndex,
  platformFlow,
  consoleLines,
  pageErrors,
  resourceChecks,
  userAgent: await page.evaluate(() => navigator.userAgent),
  maxTouchPoints: await page.evaluate(() => navigator.maxTouchPoints),
  timestamp: new Date().toISOString(),
};
fs.writeFileSync("artifacts/platform-" + mode + ".json", JSON.stringify(evidence, null, 2));

console.log("[A4_WEB_TEST] " + mode.toUpperCase() + "_BOOT_OK " + JSON.stringify(canvasInfo));
await browser.close();
