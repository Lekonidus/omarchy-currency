.pragma library

// Frankfurter / ECB set. Names match https://api.frankfurter.app/currencies.
var CURRENCY_NAMES = {
  AUD: "Australian Dollar",
  BRL: "Brazilian Real",
  CAD: "Canadian Dollar",
  CHF: "Swiss Franc",
  CNY: "Chinese Renminbi Yuan",
  CZK: "Czech Koruna",
  DKK: "Danish Krone",
  EUR: "Euro",
  GBP: "British Pound",
  HKD: "Hong Kong Dollar",
  HUF: "Hungarian Forint",
  IDR: "Indonesian Rupiah",
  ILS: "Israeli New Shekel",
  INR: "Indian Rupee",
  ISK: "Icelandic Krona",
  JPY: "Japanese Yen",
  KRW: "South Korean Won",
  MXN: "Mexican Peso",
  MYR: "Malaysian Ringgit",
  NOK: "Norwegian Krone",
  NZD: "New Zealand Dollar",
  PHP: "Philippine Peso",
  PLN: "Polish Zloty",
  RON: "Romanian Leu",
  SEK: "Swedish Krona",
  SGD: "Singapore Dollar",
  THB: "Thai Baht",
  TRY: "Turkish Lira",
  USD: "United States Dollar",
  ZAR: "South African Rand"
}

// Bar icon (nf-fa-money). Same slot size as weather / hass.
var BAR_ICON = "\uf0d6"

function normalizeCode(value) {
  return String(value || "").replace(/^\s+|\s+$/g, "").toUpperCase()
}

function parseAmount(value) {
  var n = parseFloat(String(value || "").replace(",", ".").replace(/[^\d.\-]/g, ""))
  return isNaN(n) ? 0 : n
}

function parseFrankfurter(raw) {
  try {
    var data = JSON.parse(String(raw || "{}"))
    if (!data || typeof data !== "object" || !data.rates) return null
    var rates = {}
    var base = normalizeCode(data.base)
    if (!base) return null
    rates[base] = 1
    for (var code in data.rates) {
      var rate = parseFloat(data.rates[code])
      if (!isNaN(rate) && rate > 0) rates[normalizeCode(code)] = rate
    }
    return { base: base, date: String(data.date || ""), rates: rates }
  } catch (e) {
    return null
  }
}

function rateBetween(from, to, rates) {
  var src = normalizeCode(from)
  var dst = normalizeCode(to)
  if (!src || !dst || !rates) return null
  if (src === dst) return 1
  var fromRate = rates[src]
  var toRate = rates[dst]
  if (fromRate === undefined || toRate === undefined) return null
  if (!fromRate) return null
  return toRate / fromRate
}

function convert(amount, from, to, rates) {
  var rate = rateBetween(from, to, rates)
  if (rate === null) return null
  return parseAmount(amount) * rate
}

function formatRate(rate) {
  if (rate === null || rate === undefined || isNaN(rate)) return ""
  var n = Number(rate)
  if (n >= 100) return n.toFixed(2)
  if (n >= 1) return n.toFixed(4).replace(/0+$/, "").replace(/\.$/, "")
  return n.toFixed(6).replace(/0+$/, "").replace(/\.$/, "")
}

function formatMoney(amount) {
  if (amount === null || amount === undefined || isNaN(amount)) return ""
  var n = Number(amount)
  var abs = Math.abs(n)
  var digits = abs >= 1000 ? 2 : abs >= 1 ? 2 : abs >= 0.01 ? 4 : 6
  return n.toFixed(digits).replace(/(\.\d*?[1-9])0+$/, "$1").replace(/\.0+$/, "")
}

function rateLabel(from, to, rate) {
  var src = normalizeCode(from)
  var dst = normalizeCode(to)
  var formatted = formatRate(rate)
  if (!src || !dst || !formatted) return ""
  return "1 " + src + " = " + formatted + " " + dst
}

function frankfurterUrl(from) {
  var base = normalizeCode(from) || "USD"
  return "https://api.frankfurter.app/latest?from=" + encodeURIComponent(base)
}

// preferFirst codes are pinned to the top (e.g. USD,EUR for from; ILS for to).
function currencyOptions(preferFirst) {
  var preferred = []
  var seen = {}
  var i
  var code
  var list = preferFirst || []
  for (i = 0; i < list.length; i++) {
    code = normalizeCode(list[i])
    if (!code || seen[code] || !CURRENCY_NAMES[code]) continue
    seen[code] = true
    preferred.push(code)
  }

  var rest = []
  for (code in CURRENCY_NAMES) {
    if (!seen[code]) rest.push(code)
  }
  rest.sort()

  var out = []
  var codes = preferred.concat(rest)
  for (i = 0; i < codes.length; i++) {
    code = codes[i]
    out.push({
      value: code,
      label: code + " — " + CURRENCY_NAMES[code],
      description: CURRENCY_NAMES[code]
    })
  }
  return out
}
