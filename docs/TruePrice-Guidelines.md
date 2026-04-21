# TruePrice MVP UX Design Direction

This design direction is based on the current Flutter implementation and the USD user-centered design checklist.

## Core Design Judgment

TruePrice should feel like a fast market assistant, not a data dashboard. The first visual priority is always the current decision:

1. What product did I find?
2. What is the local fair price?
3. What price did the seller quote?
4. Should I buy, negotiate, or walk away?

## Checklist-Driven Rules

- Discoverability: keep product, unit, average price, entered price, verdict, and next action visible.
- Readability: use short labels, strong numeric hierarchy, and high contrast.
- Simplicity: one primary task per screen; move secondary detail below the main action.
- Affordance: buttons, chips, icon buttons, steppers, and sliders must look interactive; labels and passive cards must not.
- Mapping: place related input and output together, especially total price, quantity, unit, and per-unit conversion.
- Consistency: use the same status colors, spacing, card shape, and action placement across screens.
- Error tolerance: permission denial, no detection, invalid price, empty data, and failed submission need visible recovery actions.
- Feedback: every scan, load, submit, or failed action needs a clear state message.
- Documentation: use concise helper text only where the next action may be unclear.

## Mobile Screen Set

Design target: mobile-first 390 x 844 frame.

### 1. Permission / Onboarding

- Three permission rows: Camera, Location, Audio.
- Primary action: `Allow permissions & get started`.
- Secondary action: `Set up later`.
- Limited mode copy must say exactly what changes: Cairo default prices, reduced nearby market accuracy, and no personalized location.
- Onboarding stays three slides: scan products, compare prices, negotiate confidently.

### 2. Scan / Upload

- Full-screen dark camera surface.
- Large scan frame in the center with short instruction: `Place product or price tag inside the frame`.
- Bottom action row:
  - Small icon button: Gallery
  - Large primary circular button: Scan
  - Small icon button: History
- Keep demo fallback visible but small: `Demo mode: gallery image returns sample result`.
- Remove or visibly disable non-functional controls such as flash if they are not implemented.

### 3. Product Price Summary

- Header confirms detected product, category/unit, and demo/confidence state.
- Primary card: regional average price.
- Secondary stats: min, max, mode.
- Histogram:
  - Green average range
  - Orange marker for scanned or entered price when available
- Primary bottom action: `Enter seller price`.
- Secondary action: `Scan again` or `Change product`.

### 4. Seller Price Input

- Product name remains visible at the top.
- Input blocks:
  - Total quoted price in EGP
  - Quantity stepper
  - Unit chips: kg, pcs, bunch
  - Per-unit calculation banner
- Example mapping: `130 EGP / 2 kg = 65 EGP per kg`.
- Disable `Analyze Price` until a valid price exists.
- Use inline validation for invalid price, not snackbar-only feedback.

### 5. Price Analysis Verdict

- Verdict card is the first visual element.
- Status color rules:
  - Fair: green
  - Negotiable: amber
  - Warning: red
- Hero content:
  - Seller price
  - Regional average
  - Percentage difference
  - Product/unit
- Histogram sits directly below the verdict.
- If negotiable or warning, show one short bargaining phrase and a target price suggestion.
- Primary action: `I bought at this price`.
- Secondary action: `Re-analyze with a different price`.

### 6. Final Share

- Success check, product, and final price are the first visible elements.
- Explain community value in one short card.
- Primary action: `Share price`.
- Secondary action: `Go back without sharing`.
- Submission failure must re-enable retry.

### 7. Supporting Tabs

- Nearby Markets: map markers open a bottom sheet with market name, specialty, and directions.
- Arabic Phrases: category chips plus speaker button for market phrases.
- Community: price report cards show product, market, time, reported price, average price, and status badge.

## Visual System

- Primary green: `#1F7A4D`
- Dark green: `#0E3B2E`
- Background: `#F6F7F2`
- Surface: `#FFFFFF`
- Text: `#222222`
- Muted text: `#6B7280`
- Fair: `#2E7D32`
- Negotiable: `#F9B233`
- Warning: `#D93A2F`

Component rules:

- Cards: max 12 px radius, 16-20 px padding, no nested cards.
- Price numbers: 32-48 px, bold.
- Section titles: 16-20 px, semibold.
- Helper text: 12-14 px, muted but readable.
- Primary action: bottom-aligned when the screen is task-oriented.
- Chips: use for unit/category choices.
- Stepper: use for quantity.
- Slider: optional mode for fast price entry only.

## Flutter Implementation Priority

1. Update `lib/features/scan/presentation/screens/scan_screen.dart` for clearer scan affordance and demo-safe states.
2. Update `lib/features/scan/presentation/screens/price_input_screen.dart` for stronger input-to-per-unit mapping and inline validation.
3. Update `lib/features/scan/presentation/screens/price_analysis_screen.dart` for a stronger verdict hero and shorter negotiation guidance.
4. Align supporting tabs only after the core scan-to-analysis demo is stable.
