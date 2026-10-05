#!/bin/bash
# Minimal end-to-end example: OCR a page with nko-v2.
# Requires: tesseract >= 5.0
set -e
cd "$(dirname "$0")/.."

tesseract "$1" "${2:-output.txt}" -l nko-v2 --tessdata-dir ./models
echo "Done -> ${2:-output.txt}"
