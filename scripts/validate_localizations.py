#!/usr/bin/env python3
"""Validate language coverage, plural forms, keys and printf arguments without Xcode."""
import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = {"en", "pl", "de", "es", "fr", "it", "pt", "uk"}
ARGUMENT = re.compile(r"%(?:(\d+)\$)?(lld|@)")


def signature(value):
    matches = list(ARGUMENT.finditer(value))
    # Positional references permit translators to reorder arguments.
    result = Counter((int(match[1] or index), match[2]) for index, match in enumerate(matches, 1))
    assert not re.search(r"%(?!%)", ARGUMENT.sub("", value)), f"Unsupported format: {value}"
    return result


def units(localization):
    if "stringUnit" in localization:
        return [localization["stringUnit"]]
    plural = localization["variations"]["plural"]
    assert {"one", "other"} <= plural.keys(), "Missing required plural forms"
    return [entry["stringUnit"] for entry in plural.values()]


def main():
    catalog_keys = set()
    total = 0
    for path in sorted((ROOT / "Resources").glob("*.xcstrings")):
        catalog = json.loads(path.read_text())
        assert catalog["sourceLanguage"] == "en", path
        for key, entry in catalog["strings"].items():
            localizations = entry["localizations"]
            assert set(localizations) == LANGUAGES, f"{path.name}: language coverage for {key}"
            expected = signature(units(localizations["en"])[0]["value"])
            for language, localization in localizations.items():
                if "variations" in localization and language in {"pl", "uk"}:
                    assert {"one", "few", "many", "other"} <= localization["variations"]["plural"].keys(), key
                for unit in units(localization):
                    assert unit["state"] == "translated" and unit["value"].strip(), f"{language}: {key}"
                    assert signature(unit["value"]) == expected, f"Argument mismatch: {language}: {key}"
            total += 1
        if path.name == "Localizable.xcstrings":
            catalog_keys = set(catalog["strings"])
    api = (ROOT / "Core/Localization/L10n.swift").read_text()
    used_keys = set(re.findall(r'(?:text|format)\("([^"]+)"', api))
    assert used_keys == {key for key in catalog_keys if not key.startswith("server.")}, f"Catalog/API mismatch: {used_keys ^ catalog_keys}"
    definitions = set(re.findall(r'static (?:var|func|let) (\w+)', api))
    for directory in ["App", "Core", "Features", "Shared"]:
        for path in (ROOT / directory).rglob("*.swift"):
            for symbol in re.findall(r'\bL10n\.(\w+)', path.read_text()):
                assert symbol in definitions, f"Unknown L10n symbol {symbol} in {path}"
    print(f"Validated {total} keys in {len(LANGUAGES)} languages, including plural forms and arguments.")


if __name__ == "__main__":
    main()
