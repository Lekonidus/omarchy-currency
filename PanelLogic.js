.pragma library

// Pure panel state helpers — unit-tested without QML.

function applySwap(from, to) {
  return { from: to, to: from }
}

function applySelect(side, code, from, to) {
  if (side === "from") return { from: code, to: to }
  if (side === "to") return { from: from, to: code }
  return { from: from, to: to }
}

// Snapshot used by IPC status and UI consistency checks.
function uiSnapshot(from, to, amount, rates, Model) {
  var rate = Model.rateBetween(from, to, rates)
  var converted = Model.convert(amount, from, to, rates)
  return {
    from: from,
    to: to,
    amount: amount,
    rate: rate,
    converted: converted,
    rateText: rate === null ? "" : Model.rateLabel(from, to, rate),
    resultText: converted === null ? "" : (Model.formatMoney(converted) + " " + to),
    consistent: true
  }
}

// Detect the screenshot bug: labels claim one pair while math uses another.
function labelsMatchCodes(fromLabelCode, toLabelCode, from, to) {
  return fromLabelCode === from && toLabelCode === to
}
