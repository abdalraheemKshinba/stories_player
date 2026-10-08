// Takes the README screenshots of the stories_player example, at phone size.
import puppeteer from 'puppeteer-core';
import fs from 'node:fs';

const OUT = process.argv[2];
const BASE = process.env.BASE ?? 'http://localhost:8765/';
const only = process.argv[3]?.split(',');
fs.mkdirSync(OUT, { recursive: true });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const W = 412, H = 892;

const scenes = [
  { name: '01_home', url: '?scene=home', wait: 3000 },
  { name: '02_image_music', url: '?scene=player&group=market&freeze=2600', wait: 4500 },
  { name: '03_rtl_arabic', url: '?scene=player&group=market&item=market-raspberries&rtl=1&freeze=2400', wait: 4500 },
  { name: '04_custom_theme_cta', url: '?scene=player&group=coffee&theme=1&freeze=2200', wait: 4500 },
  { name: '05_tap_zones_ltr', url: '?scene=player&group=salad&zones=1&freeze=1500', wait: 4000 },
  { name: '06_tap_zones_rtl', url: '?scene=player&group=salad&zones=1&rtl=1&freeze=1500', wait: 4000 },
  { name: '07_lottie_music', url: '?scene=player&group=kitchen&freeze=1700', wait: 4500 },
  { name: '08_lottie_loop', url: '?scene=player&group=salad&item=salad-preparing&freeze=1300', wait: 4000 },
  { name: '09_widget_story', url: '?scene=player&group=kitchen&item=kitchen-free-delivery&freeze=2000', wait: 4500 },
  { name: '10_text_story', url: '?scene=player&group=bakery&item=bakery-croissants&freeze=2000', wait: 4500 },
  { name: '11_video', url: '?scene=player&group=market&item=market-fruit-video&freeze=1600', wait: 6000 },
  { name: '19_bakery_video', url: '?scene=player&group=bakery&item=bakery-video&freeze=1800', wait: 4500 },
  { name: '12_error_retry', url: '?scene=error', wait: 5000 },
  {
    name: '13_hold_to_pause', url: '?scene=player&group=bakery', wait: 3000,
    act: async (page) => {
      await page.mouse.move(W * 0.6, H * 0.55);
      await page.mouse.down();
      await sleep(900);
    },
    after: async (page) => page.mouse.up(),
  },
  {
    name: '14_swipe_down', url: '?scene=player&group=market&item=market-grapes', wait: 3000,
    act: async (page) => {
      await page.mouse.move(W / 2, 260);
      await page.mouse.down();
      for (let y = 260; y <= 470; y += 15) {
        await page.mouse.move(W / 2, y);
        await sleep(16);
      }
      await sleep(200);
    },
    after: async (page) => page.mouse.up(),
  },
  {
    name: '15_cube_swipe', url: '?scene=player&group=market&transition=cube', wait: 3000,
    act: async (page) => {
      let x = W * 0.85;
      await page.touchscreen.touchStart(x, H / 2);
      for (; x >= W * 0.45; x -= 10) {
        await page.touchscreen.touchMove(x, H / 2);
        await sleep(16);
      }
      await sleep(250);
    },
    after: async (page) => page.touchscreen.touchEnd(),
  },
  {
    name: '16_cube_swipe_rtl', url: '?scene=player&group=market&transition=cube&rtl=1', wait: 3000,
    act: async (page) => {
      let x = W * 0.15;
      await page.touchscreen.touchStart(x, H / 2);
      for (; x <= W * 0.55; x += 10) {
        await page.touchscreen.touchMove(x, H / 2);
        await sleep(16);
      }
      await sleep(250);
    },
    after: async (page) => page.touchscreen.touchEnd(),
  },
];

const browser = await puppeteer.launch({
  executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  headless: true,
  args: ['--autoplay-policy=no-user-gesture-required', '--hide-scrollbars'],
});

for (const scene of scenes) {
  if (only && !only.includes(scene.name)) continue;
  const page = await browser.newPage();
  await page.setViewport({ width: W, height: H, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
  const cdp = await page.createCDPSession();
  await cdp.send('Emulation.setFocusEmulationEnabled', { enabled: true });
  page.on('pageerror', (e) => console.log(`[${scene.name}] page error: ${e.message}`));
  await page.goto(BASE + scene.url, { waitUntil: 'networkidle2', timeout: 60000 });
  await sleep(scene.wait);
  if (scene.act) await scene.act(page);
  await page.screenshot({ path: `${OUT}/${scene.name}.png` });
  if (scene.after) await scene.after(page);
  console.log(`shot ${scene.name}`);
  await page.close();
}
await browser.close();
