# Currency for Omarchy

Convert currencies from the Omarchy bar using ECB reference rates
([Frankfurter](https://www.frankfurter.app/)).

Quickshell plugin for **Omarchy 4**. Icon-sized bar slot opens a panel with
amount entry, searchable from/to pickers (USD and EUR pinned for from, ILS
pinned for to), swap, and refresh.

## Install

```bash
omarchy plugin add https://github.com/Lekonidus/omarchy-currency.git --enable
```

Place it where you want on the bar:

```bash
omarchy bar move io.github.lekonidus.currency --section center --after omarchy.weather
```

Optional defaults:

```bash
omarchy bar set io.github.lekonidus.currency from USD
omarchy bar set io.github.lekonidus.currency to ILS
```

## Remove

```bash
omarchy plugin remove io.github.lekonidus.currency --yes
```

## Use

- Left-click the money icon to open the converter
- Middle-click refreshes rates
- In the panel: type an amount, pick currencies, **Swap** / **Refresh**
- Shortcuts while the panel is open: `s` swap, `r` refresh, `Esc` close

## Dependencies

- Omarchy 4 (`schemaVersion: 1` plugin API)
- `curl` (for Frankfurter HTTPS requests)
- Network access to `api.frankfurter.app`

No API key, npm, or pip packages.

## License

MIT. Exchange rates come from the European Central Bank via Frankfurter;
see [Frankfurter](https://www.frankfurter.app/) for upstream terms.
