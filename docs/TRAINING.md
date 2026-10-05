# Training notes — nko-ocr v1 & v2

Condensed from the full build journal (Oct 4–5, 2026). Enough detail to reproduce the pipeline.

## Environment

- Tesseract **5.3.4**, `tesstrain` (`make training`), CPU-only VM
- Python 3, PIL + `raqm` (complex text layout), `python-bidi`
- Start model: `fra` from `tessdata_best` (full LSTM, 3.9 MB) — warm start, not from scratch

## Corpus

- `corpus-nko.txt`: **2,211 unique lines** of N'Ko (Bambara, Mali)
  - sources: N'Ko learning materials, ebook text extraction, real N'Ko Facebook posts
  - 913 authentic lines + 77 splits of long sentences + 1,221 recombined pairs
  - some mixed Latin/N'Ko lines kept (realistic bilingual text)
  - normalized to NFC (974 lines had non-canonical mark ordering — tesstrain normalizes to NFC, so input must match)

## Rendering (the hard part)

- Tesseract's `text2image` binary was broken on this machine → custom PIL + libraqm renderer, `direction='rtl'`, verified against a reference rendering
- Font problem: Noto Sans NKo covers N'Ko only (1/95 ASCII) → Latin runs in mixed lines rendered as tofu
  - solution: render **by runs** — N'Ko runs in Noto (RTL via raqm), Latin runs in DejaVu (LTR), neutrals attached to adjacent N'Ko run (RTL paragraph)
- 1,570 tofu images detected and regenerated

## v1

- **914 images**: 457 pure-N'Ko lines × 2 variants (40pt clean / 32pt noisy)
  - (mixed lines dropped: custom bidi ≠ python-bidi's UBA used for .box generation → inconsistent supervision)
- `make training MODEL_NAME=nko START_MODEL=fra LANG_TYPE=RTL MAX_ITERATIONS=8000`, LR 0.001 (0.0001 too weak for a new script)
- train BCER 13.45% @ 18k iters
- **eval (lstmeval, 92 held-out lines): CER 15.84% | WER 34.84%**
- real-world test (ebook p.6): reads N'Ko where official `nko.traineddata` outputs nothing

## v2

- **+4,000 images**: 500 targeted lines (4,677 diacritics, 1,504 N'Ko digits) × 4 variants (2 fonts: Noto Sans NKo, Afronik N'Ko) × (clean / noisy: blur 0.7, rotation ±1°, contrast 0.85–1.15)
- **Dictionary wordlist**: Baba Diane French–N'Ko dictionary (2014), 498 pages re-OCRed → 116,700 tokens → 2,072 words (freq ≥ 3) → merged to **2,856 clean N'Ko words, zero Latin leakage**
  - bug found & fixed: old wordlist had French+N'Ko concatenations ("beauߓߏbo") from a `\w` regex — re-extracted cleanly
  - empirical finding: Tesseract 5 LSTM has **no** `lstm-freq-dawg` slot (legacy engine only) → whole dictionary went into `lstm-word-dawg`, the real WER lever for LSTM
- warm start from v1 checkpoint (18k) → +32k iters, LR 0.0005, 4,822 training lines
- best checkpoint kept (BCER 20.945 @ iter 30,646)
- **eval (same 92 lines): CER 6.26% | WER 17.85%**
- real-world test (dictionary p.10): fluent reading with clean diacritics

## Known limits

- synthetic training images are small → Tesseract CLI page segmentation needs **≥120 DPI** input (upscale small images first)
- print only — no handwriting
- generalization to unseen fonts is the main risk; v3 should add more fonts + augmentation
