#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

required_files=(
  "README.md"
  "hackusb_setup.zsh"
  "hackusb_setup.ps1"
  "hackusb_cheatsheet.html"
)

for f in "${required_files[@]}"; do
  [[ -f "$repo_root/$f" ]] || { echo "Missing required file: $f"; exit 1; }
done

grep -q "hackusb_setup.ps1" "$repo_root/README.md" || { echo "README is missing hackusb_setup.ps1 reference"; exit 1; }
grep -Fq ".\\hackusb_setup.ps1" "$repo_root/hackusb_cheatsheet.html" || { echo "Cheatsheet is missing PowerShell launcher command"; exit 1; }
grep -q "^#!/usr/bin/env zsh" "$repo_root/hackusb_setup.zsh" || { echo "hackusb_setup.zsh shebang missing"; exit 1; }

echo "Documentation consistency checks passed."
