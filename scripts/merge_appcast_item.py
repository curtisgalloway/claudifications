#!/usr/bin/env python3
"""Merge new <item> entries from a freshly-generated appcast into the
persisted docs/appcast.xml, without needing every historical release zip
on disk.

Usage: merge_appcast_item.py <new-appcast.xml> <persisted-appcast.xml>

`new-appcast.xml` is the output of `generate_appcast` run against a scratch
folder holding only the current release's zip (see release.yml) — normally
containing exactly one <item>. Each item is inserted as the first <item>
child of the persisted appcast's <channel>, skipped if an item with the same
enclosure URL is already present, so re-running this script (e.g. on a
workflow retry) is idempotent.
"""

import sys
import xml.etree.ElementTree as ET

SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", SPARKLE_NS)


def enclosure_url(item):
    enclosure = item.find("enclosure")
    return enclosure.get("url") if enclosure is not None else None


def main():
    if len(sys.argv) != 3:
        sys.exit(f"usage: {sys.argv[0]} <new-appcast.xml> <persisted-appcast.xml>")

    new_path, persisted_path = sys.argv[1], sys.argv[2]

    new_channel = ET.parse(new_path).getroot().find("channel")
    if new_channel is None:
        sys.exit(f"{new_path}: no <channel> element found")
    new_items = new_channel.findall("item")
    if not new_items:
        sys.exit(f"{new_path}: no <item> elements found")

    persisted_tree = ET.parse(persisted_path)
    persisted_channel = persisted_tree.getroot().find("channel")
    if persisted_channel is None:
        sys.exit(f"{persisted_path}: no <channel> element found")

    existing_urls = {
        url for url in (enclosure_url(item) for item in persisted_channel.findall("item")) if url
    }

    added = 0
    for item in new_items:
        url = enclosure_url(item)
        if url is None or url in existing_urls:
            continue
        # Insert right after the channel's own metadata (title/link/etc.),
        # ahead of any existing <item>s, so the feed stays newest-first.
        insert_at = next(
            (i for i, child in enumerate(persisted_channel) if child.tag == "item"),
            len(persisted_channel),
        )
        persisted_channel.insert(insert_at, item)
        existing_urls.add(url)
        added += 1

    if added:
        ET.indent(persisted_tree, space="  ")
        persisted_tree.write(persisted_path, encoding="utf-8", xml_declaration=True)
        print(f"Added {added} item(s) to {persisted_path}")
    else:
        print(f"No new items to add to {persisted_path}")


if __name__ == "__main__":
    main()
