#!/usr/bin/env node
// Run: node tests/test_model.js
const fs = require("fs")
const path = require("path")

const source = fs
  .readFileSync(path.join(__dirname, "..", "Model.js"), "utf8")
  .replace(/^\.pragma library\s*$/m, "")
const names = [...source.matchAll(/^function\s+([A-Za-z0-9_]+)/gm)].map((m) => m[1])
const consts = [...source.matchAll(/^var\s+([A-Z][A-Z0-9_]*)/gm)].map((m) => m[1])
const Model = new Function(`${source}\nreturn {${[...names, ...consts].join(",")}};`)()

let failed = 0
function eq(label, actual, expected) {
  const ok = JSON.stringify(actual) === JSON.stringify(expected)
  if (!ok) {
    failed++
    console.log(`FAIL ${label}: got ${JSON.stringify(actual)}, expected ${JSON.stringify(expected)}`)
  }
}

const rates = { USD: 1, EUR: 0.87, ILS: 3.04 }
eq("usd→ils", Model.convert(10, "usd", "ils", rates), 30.4)
eq("ils→usd cross", Number(Model.convert(50, "ILS", "USD", rates).toFixed(6)), Number((50 / 3.04).toFixed(6)))
eq("eur→ils cross", Number(Model.convert(1, "EUR", "ILS", rates).toFixed(6)), Number((3.04 / 0.87).toFixed(6)))
eq("same currency", Model.convert(5, "USD", "usd", rates), 5)
eq("bad amount", Model.convert("abc", "USD", "ILS", rates), null)
eq("rate label", Model.rateLabel("ils", "usd", 0.33155), "1 ILS = 0.33155 USD")
eq("missing rate", Model.convert(1, "USD", "XYZ", rates), null)
eq("known", Model.isKnownCode("ils"), true)
eq("unknown", Model.isKnownCode("XXX"), false)

const pair = Model.normalizePair("ils", "usd", "USD", "ILS")
eq("normalize pair", pair, { from: "ILS", to: "USD" })
eq("normalize junk", Model.normalizePair("nope", "nope", "EUR", "GBP"), { from: "EUR", to: "GBP" })

eq("frankfurter always usd base", Model.frankfurterUrl("ILS"), "https://api.frankfurter.app/latest?from=USD")

const fromOpts = Model.currencyOptions(["USD", "EUR"])
eq("from pin 0", fromOpts[0].value, "USD")
eq("from pin 1", fromOpts[1].value, "EUR")
eq("from has ils", fromOpts.some((o) => o.value === "ILS"), true)
eq("label ascii dash", fromOpts[0].label, "USD - United States Dollar")

const toOpts = Model.currencyOptions(["ILS", "USD", "EUR"])
eq("to pin 0", toOpts[0].value, "ILS")

// Screenshot regression: 50 ILS → USD at 0.33155
const shotRates = { ILS: 1, USD: 0.33155 }
eq("screenshot math", Number(Model.convert(50, "ILS", "USD", shotRates).toFixed(2)), 16.58)

if (failed) {
  console.log(`${failed} failed`)
  process.exit(1)
}
console.log("ok")
