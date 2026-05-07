#!/usr/bin/env node

const { chromium } = require("playwright");

const monthMap = {
  januari: 1,
  februari: 2,
  maart: 3,
  april: 4,
  mei: 5,
  juni: 6,
  juli: 7,
  augustus: 8,
  september: 9,
  oktober: 10,
  november: 11,
  december: 12
};

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg.startsWith("--")) {
      const key = arg.slice(2);
      const val = argv[i + 1] && !argv[i + 1].startsWith("--") ? argv[++i] : "true";
      args[key] = val;
    }
  }
  return args;
}

function parseDutchDate(dateText) {
  const cleaned = dateText.trim().toLowerCase();
  const match = cleaned.match(/^\w+\s+(\d{1,2})\s+([a-z]+)\s+(\d{4})$/);
  if (!match) return null;

  const day = Number(match[1]);
  const month = monthMap[match[2]];
  const year = Number(match[3]);
  if (!month) return null;

  const mm = String(month).padStart(2, "0");
  const dd = String(day).padStart(2, "0");
  return `${year}-${mm}-${dd}`;
}

async function scrape(url, waitMs) {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  try {
    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 120_000 });
    await page.waitForTimeout(waitMs);

    const result = await page.evaluate(() => {
      const cards = Array.from(document.querySelectorAll(".card.card-collapse.collapse-schedule"));
      const matches = [];

      cards.forEach((card, cardIndex) => {
        const dateText =
          card.querySelector(".card-header .card-header-title")?.textContent?.trim() ||
          card.querySelector(".card-header")?.textContent?.trim() ||
          null;

        const matchNodes = Array.from(card.querySelectorAll(".Match"));
        matchNodes.forEach((node, matchIndex) => {
          const poule = node.querySelector(".MatchPoule")?.textContent?.trim() || null;
          const field = node.querySelector(".MatchField")?.textContent?.trim() || null;
          const teamNames = Array.from(node.querySelectorAll(".TeamName span"))
            .map((el) => el.textContent.trim())
            .filter(Boolean);
          const matchTimes = Array.from(node.querySelectorAll(".MatchTime"))
            .map((el) => el.textContent.trim())
            .filter(Boolean);
          const referees = Array.from(node.querySelectorAll(".RefereeName"))
            .map((el) => el.textContent.trim())
            .filter(Boolean);

          matches.push({
            dateText,
            poule,
            field,
            teamA: teamNames[0] || null,
            teamB: teamNames[1] || null,
            st: matchTimes[0] || null,
            referee: referees[0] || null,
            status: "scheduled",
            ordinalInDay: matchIndex,
            cardIndex
          });
        });
      });

      return {
        title: document.title,
        count: matches.length,
        matches
      };
    });

    return result;
  } finally {
    await browser.close();
  }
}

async function main() {
  const args = parseArgs(process.argv);
  const url = args.url;
  const waitMs = Number(args.waitMs || 12_000);

  if (!url) {
    throw new Error("missing --url");
  }

  const scraped = await scrape(url, waitMs);

  const normalized = scraped.matches.map((match) => ({
    ...match,
    dateIso: parseDutchDate(match.dateText)
  }));

  process.stdout.write(
    JSON.stringify(
      {
        title: scraped.title,
        count: normalized.length,
        matches: normalized
      },
      null,
      2
    )
  );
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
