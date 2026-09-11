import fs from "node:fs/promises";
import { Workbook, SpreadsheetFile } from "@oai/artifact-tool";

const outputDir = "/Users/ilwonyoon/Documents/2026 Side/5more/outputs/2026-09-11-asset-inventory";
const workbook = Workbook.create();
const inventory = workbook.worksheets.add("Asset inventory");
const guide = workbook.worksheets.add("How to update");

const rows = [
  ["Asset", "Role", "Where used", "Current source", "Canvas / alpha", "Target display", "Template", "Status", "ImageGen brief"],
  ["AppIcon", "App identity", "Home screen", "art/generated/app-icon/app-icon-five-hand-v3-source.png", "1024×1024, opaque", "iOS app icon", "No", "Current", "Cute five-finger palm; warm peach clay/crayon form; cream background; no text."],
  ["BrandWordmark", "Legacy title", "Capture header", "art/generated/brand/wordmark-transparent-v4.png", "240×95 pt, transparent", "Retire from Home header", "Yes", "Replace planned", "Do not regenerate unless retaining the large centered wordmark."],
  ["SymbolFiveHand", "Brand mark", "Paywall, camera guide, voice flow", "art/generated/symbols/hand-five-v1.png", "140×140 pt, transparent", "28–88 pt", "No", "Current / reuse", "Friendly five-finger peach hand, tactile clay-watercolor, transparent background."],
  ["HeroSpace", "Home illustration", "Capture Home frame", "art/generated/brand/hero-space-transparent-v2.png", "360×394 pt, transparent", "Frame fill", "No", "Current", "Childlike crayon rocket and stars; blue crayon border; transparent background."],
  ["IconCamera", "Primary action", "Camera CTA, unavailable state", "art/generated/icons/camera-transparent-v3.png", "40×40 pt, transparent", "44 pt in CTA / 37 pt settings", "Yes", "Current", "Charcoal wax-crayon camera outline; minimal; transparent background."],
  ["IconHome", "Navigation", "Liquid Glass tab bar", "art/generated/icons/home-transparent-v2.png", "40×40 pt, transparent", "24 pt visual art", "Yes", "Scale down", "Charcoal/orange wax-crayon home outline with 30% transparent breathing room around art."],
  ["IconMemories", "Navigation", "Liquid Glass tab bar, empty state", "art/generated/icons/memories-transparent-v3.png", "40×40 pt, transparent", "24 pt visual art", "Yes", "Scale down", "Charcoal wax-crayon stacked-photo outline with 30% transparent breathing room around art."],
  ["IconSettings", "Secondary action", "Capture header, Settings", "art/generated/icons/settings-transparent-v2.png", "40×40 pt, transparent", "22–37 pt", "Yes", "Current", "Charcoal wax-crayon gear; low-detail, friendly, transparent background."],
  ["IconTrash", "Destructive action", "Moment and Cheer deletion", "art/generated/icons/icon-trash-v1-transparent.png", "40×40 pt, transparent", "22–23 pt", "Yes", "Current", "Charcoal wax-crayon wastebasket; transparent background; no fill."],
  ["SymbolCompletion", "Completion mark", "Completion, sound screens", "art/generated/symbols/completion-signal-v1.png", "96×96 pt, transparent", "68–82 pt", "No", "Current", "Warm yellow clay/crayon bell; transparent background; soft and celebratory."],
  ["Header hand mark", "Future header", "Capture Home / Camera header", "Reuse SymbolFiveHand first", "Transparent", "28 pt", "No", "Proposed", "Use the existing five-finger mark at small scale beside the words ‘Five More Minutes’; do not create a second logo until tested."],
];

inventory.getRange(`A1:I${rows.length}`).values = rows;
inventory.showGridLines = false;
inventory.freezePanes.freezeRows(1);
inventory.getRange("A1:I1").format = {
  fill: "#202120",
  font: { color: "#FFF9EE", bold: true, name: "Helvetica Neue", size: 10 },
  horizontalAlignment: "center",
  verticalAlignment: "center",
  wrapText: true,
  borders: { preset: "outside", style: "thin", color: "#202120" },
};
inventory.getRange(`A2:I${rows.length}`).format = {
  font: { color: "#202120", name: "Helvetica Neue", size: 10 },
  verticalAlignment: "center",
  wrapText: true,
};
inventory.getRange(`A2:I${rows.length}`).format.borders = { insideHorizontal: { style: "thin", color: "#E6DFD1" } };
inventory.getRange(`A2:A${rows.length}`).format.font = { bold: true, color: "#202120", name: "Helvetica Neue", size: 10 };
inventory.getRange(`H2:H${rows.length}`).conditionalFormats.add("containsText", { text: "Replace planned", format: { fill: "#FFE4A6", font: { color: "#6B4A00", bold: true } } });
inventory.getRange(`H2:H${rows.length}`).conditionalFormats.add("containsText", { text: "Scale down", format: { fill: "#DCEEFF", font: { color: "#075A93", bold: true } } });
inventory.getRange(`H2:H${rows.length}`).conditionalFormats.add("containsText", { text: "Proposed", format: { fill: "#F9E4D8", font: { color: "#9A4517", bold: true } } });
inventory.getRange("A1").format.columnWidth = 18;
inventory.getRange("B1").format.columnWidth = 18;
inventory.getRange("C1").format.columnWidth = 27;
inventory.getRange("D1").format.columnWidth = 46;
inventory.getRange("E1").format.columnWidth = 23;
inventory.getRange("F1").format.columnWidth = 22;
inventory.getRange("G1").format.columnWidth = 12;
inventory.getRange("H1").format.columnWidth = 18;
inventory.getRange("I1").format.columnWidth = 62;
inventory.getRange("A1:I1").format.rowHeight = 30;
inventory.getRange(`A2:I${rows.length}`).format.rowHeight = 54;

const guideRows = [
  ["5 More asset workflow", ""],
  ["1. Find", "Use Asset inventory: filter by role, screen, or Status."],
  ["2. Generate", "Use the ImageGen brief verbatim, include transparent background when Template is Yes."],
  ["3. Prepare", "Keep a source PNG in art/generated. Extract real alpha if the image model painted a checkerboard."],
  ["4. Export", "For icons: 40×40 pt plus @2x/@3x. For symbols: preserve the listed canvas and scale variants."],
  ["5. Replace", "Update the matching .imageset only. Do not overwrite AppIcon without an explicit product decision."],
  ["6. Verify", "Build in light and dark mode. Check Liquid Glass tabs at the actual iPhone size, not just image pixels."],
  ["Current priority", "1) scale down IconHome and IconMemories within their 40 pt canvases; 2) test the small five-hand + ‘Five More Minutes’ header; 3) decide whether to retire BrandWordmark."],
  ["Source of truth", "docs/asset-manifest.json mirrors this workbook in a machine-readable format."],
];
guide.getRange(`A1:B${guideRows.length}`).values = guideRows;
guide.showGridLines = false;
guide.getRange("A1:B1").merge();
guide.getRange("A1").format = { font: { color: "#202120", bold: true, name: "Helvetica Neue", size: 16 }, verticalAlignment: "center" };
guide.getRange("A1:B1").format.rowHeight = 30;
guide.getRange("A2:A9").format = { font: { color: "#202120", bold: true, name: "Helvetica Neue", size: 10 }, verticalAlignment: "center", wrapText: true };
guide.getRange("B2:B9").format = { font: { color: "#4E4B45", name: "Helvetica Neue", size: 10 }, verticalAlignment: "center", wrapText: true };
guide.getRange("A2:B9").format.borders = { insideHorizontal: { style: "thin", color: "#E6DFD1" } };
guide.getRange("A9:B9").format = { fill: "#FFF2CC", font: { color: "#6B4A00", bold: true, name: "Helvetica Neue", size: 10 }, verticalAlignment: "center", wrapText: true };
guide.getRange("A10:B10").format = { fill: "#EAF3FF", font: { color: "#075A93", name: "Helvetica Neue", size: 10 }, verticalAlignment: "center", wrapText: true };
guide.getRange("A1").format.columnWidth = 21;
guide.getRange("B1").format.columnWidth = 95;
guide.getRange("A2:B10").format.rowHeight = 34;

workbook.recalculate();
const check = await workbook.inspect({ kind: "table", range: "Asset inventory!A1:I12", include: "values", tableMaxRows: 12, tableMaxCols: 9 });
console.log(check.ndjson);
const preview = await workbook.render({ sheetName: "Asset inventory", range: "A1:I12", scale: 1.3, format: "png" });
await fs.mkdir(outputDir, { recursive: true });
await fs.writeFile(`${outputDir}/asset-inventory-preview.png`, new Uint8Array(await preview.arrayBuffer()));
const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(`${outputDir}/five-more-asset-inventory.xlsx`);
