#!/usr/bin/env node
// Run: node tests/test_model.js
const fs = require("fs")
const path = require("path")

function load(rel) {
  const source = fs
    .readFileSync(path.join(__dirname, "..", rel), "utf8")
    .replace(/^\.pragma library\s*$/m, "")
  const names = [...source.matchAll(/^function\s+([A-Za-z0-9_]+)/gm)].map((m) => m[1])
  const consts = [...source.matchAll(/^var\s+([A-Z][A-Z0-9_]*)/gm)].map((m) => m[1])
  return new Function(`${source}\nreturn {${[...names, ...consts].join(",")}};`)()
}

const Model = load("Model.js")
const Logic = load("PanelLogic.js")

let failed = 0
function eq(label, actual, expected) {
  const ok = JSON.stringify(actual) === JSON.stringify(expected)
  if (!ok) {
    failed++
    console.log(`FAIL ${label}: got ${JSON.stringify(actual)}, expected ${JSON.stringify(expected)}`)
  }
}
function ok(label, cond) {
  if (!cond) {
    failed++
    console.log(`FAIL ${label}`)
  }
}

const rates = { USD: 1, EUR: 0.87, ILS: 3.04 }
eq("usd→ils", Model.convert(10, "usd", "ils", rates), 30.4)
eq("ils→usd", Number(Model.convert(50, "ILS", "USD", rates).toFixed(6)), Number((50 / 3.04).toFixed(6)))
eq("same currency", Model.convert(5, "USD", "usd", rates), 5)
eq("bad amount", Model.convert("abc", "USD", "ILS", rates), null)
eq("missing rate", Model.convert(1, "USD", "XYZ", rates), null)

eq("swap", Logic.applySwap("USD", "ILS"), { from: "ILS", to: "USD" })
eq("swap back", Logic.applySwap("ILS", "USD"), { from: "USD", to: "ILS" })
eq("select from", Logic.applySelect("from", "EUR", "USD", "ILS"), { from: "EUR", to: "ILS" })
eq("select to", Logic.applySelect("to", "GBP", "USD", "ILS"), { from: "USD", to: "GBP" })

// Screenshot regression: labels said USD/USD while math was ILS→USD
ok("labels mismatch detected", !Logic.labelsMatchCodes("USD", "USD", "ILS", "USD"))
ok("labels match when synced", Logic.labelsMatchCodes("ILS", "USD", "ILS", "USD"))

const shotRates = { ILS: 1, USD: 0.33155 }
const shot = Logic.uiSnapshot("ILS", "USD", "1", shotRates, Model)
eq("shot rate text", shot.rateText, "1 ILS = 0.33155 USD")
eq("shot result", shot.resultText, "0.3316 USD")
eq("shot 50", Number(Model.convert(50, "ILS", "USD", shotRates).toFixed(2)), 16.58)

// After swap, snapshot codes flip and same-currency is identity
const afterSwap = Logic.applySwap("USD", "ILS")
eq("after swap codes", afterSwap, { from: "ILS", to: "USD" })
const same = Logic.uiSnapshot("USD", "USD", "1", rates, Model)
eq("same-currency converted", same.converted, 1)
eq("same-currency rate", same.rate, 1)

eq("frankfurter usd base", Model.frankfurterUrl("ILS"), "https://api.frankfurter.app/latest?from=USD")
eq("normalize pair", Model.normalizePair("ils", "usd", "USD", "ILS"), { from: "ILS", to: "USD" })

const fromOpts = Model.currencyOptions(["USD", "EUR"])
eq("from pin", [fromOpts[0].value, fromOpts[1].value], ["USD", "EUR"])
ok("options include ILS", fromOpts.some((o) => o.value === "ILS"))

if (failed) {
  console.log(`${failed} failed`)
  process.exit(1)
}
console.log("ok")
