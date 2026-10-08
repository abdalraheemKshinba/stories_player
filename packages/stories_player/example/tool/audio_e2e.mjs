// End-to-end sound check on the real web build: after each step, count the
// media elements that are actually audible (playing, unmuted, volume > 0).
import puppeteer from 'puppeteer-core';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const W = 412, H = 892;
const BASE = process.env.BASE ?? 'http://localhost:8765/';
const browser = await puppeteer.launch({
  executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  headless: true, args: ['--autoplay-policy=no-user-gesture-required'],
});
let failures = 0;
async function open(url) {
  const page = await browser.newPage();
  await page.setViewport({ width: W, height: H, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
  const cdp = await page.createCDPSession();
  await cdp.send('Emulation.setFocusEmulationEnabled', { enabled: true });
  await page.evaluateOnNewDocument(() => {
    window.__media = new Set();
    const play = HTMLMediaElement.prototype.play;
    HTMLMediaElement.prototype.play = function () { window.__media.add(this); return play.apply(this, arguments); };
  });
  await page.goto(BASE + url, { waitUntil: 'networkidle2' });
  await sleep(1800);
  return page;
}
const audible = (page) => page.evaluate(() => [...window.__media]
  .filter((m) => !m.paused && !m.muted && m.volume > 0 && document.contains(m) || (!m.paused && !m.muted && m.volume > 0 && m.tagName === 'AUDIO'))
  .map((m) => m.tagName.toLowerCase() + ':' + (m.currentSrc || m.src).split('/').pop()));
const tap = async (page, x) => { await page.touchscreen.tap(x, H * 0.5); };
const unmute = async (page) => { await page.touchscreen.tap(W - 46, 44); await sleep(500); };
async function check(label, page, expected) {
  const now = await audible(page);
  const ok = JSON.stringify(now.map((s) => s.split(':')[0]).sort()) === JSON.stringify(expected.sort());
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}: audible=${JSON.stringify(now)} expected kinds=${JSON.stringify(expected)}`);
}

// E1: music on an image, then a video with sound: only the video is heard.
let p = await open('?scene=player&group=market&freeze=999999');
await unmute(p);
await check('E1a image with music, unmuted', p, ['audio']);
await tap(p, W * 0.8); await sleep(1800);
await check('E1b next is a video with sound', p, ['video']);
// E2: hold pauses the video's sound; release brings it back.
await p.touchscreen.touchStart(W * 0.6, H * 0.5); await sleep(700);
await check('E2a holding', p, []);
await p.touchscreen.touchEnd(); await sleep(700);
await check('E2b released', p, ['video']);
// E3: next is a silent image: nothing is heard.
await tap(p, W * 0.8); await sleep(1200);
await check('E3 next is a silent image', p, []);
await p.close();

// E4: rapid taps from music through a video to silence.
p = await open('?scene=player&group=market&freeze=999999');
await unmute(p);
await tap(p, W * 0.8); await sleep(60); await tap(p, W * 0.8);
await sleep(2000);
await check('E4 two quick taps from music to a silent image', p, []);
await p.close();

// E5: Lottie with music, then a silent widget, then a network video.
p = await open('?scene=player&group=kitchen&freeze=999999');
await unmute(p);
await check('E5a Lottie with music', p, ['audio']);
await tap(p, W * 0.8); await sleep(1200);
await check('E5b silent widget story', p, []);
await tap(p, W * 0.8); await sleep(2000);
await check('E5c network video', p, ['video']);
await tap(p, W * 0.1); await sleep(1500);
await check('E5d back to the silent widget', p, []);
await p.close();

console.log(failures === 0 ? 'ALL PASS' : `${failures} FAILED`);
await browser.close();
process.exitCode = failures === 0 ? 0 : 1;
