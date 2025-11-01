#!/usr/bin/env python3
"""
Script to remove emojis from ResilienceReport.qmd diagnostic sections.
These emojis are only shown in debug mode (data_guide_mode=TRUE).
"""

# Emoji replacements for diagnostic messages
REPLACEMENTS = [
    # Status emojis
    ("❌", "[X]"),
    ("✅", "[OK]"),
    ("⚠️", "[!]"),
    ("⚠", "[!]"),
]

def remove_emojis_from_qmd():
    """Remove all emojis from ResilienceReport.qmd"""
    input_file = "ResilienceReport.qmd"

    with open(input_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Apply replacements
    for emoji, replacement in REPLACEMENTS:
        content = content.replace(emoji, replacement)

    # Write back
    with open(input_file, 'w', encoding='utf-8') as f:
        f.write(content)

    print(f"Processed {input_file}")
    print(f"Applied {len(REPLACEMENTS)} replacement rules")

if __name__ == "__main__":
    remove_emojis_from_qmd()
