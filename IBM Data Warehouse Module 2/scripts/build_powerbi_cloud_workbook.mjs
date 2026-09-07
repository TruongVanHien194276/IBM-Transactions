import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

process.on("uncaughtException", (error) => {
  console.error(`BUILD_ERROR: ${error?.message ?? String(error)}`);
  process.exit(1);
});

process.on("unhandledRejection", (error) => {
  console.error(`BUILD_ERROR: ${error?.message ?? String(error)}`);
  process.exit(1);
});

const projectDir = "/Users/hoangyugi001/Documents/Coder/IBM Transactions";
const snapshotDir = path.join(projectDir, "powerbi/cloud/data_snapshot_compact");
const outputDir = path.join(projectDir, "outputs/powerbi_cloud_20260723");
const qaDir = path.join(projectDir, "work/powerbi_cloud_workbook_qa");
const outputPath = path.join(outputDir, "IBM_AML_PowerBI_Cloud_Source.xlsx");

const tables = [
  "dim_date",
  "dim_payment_currency",
  "dim_receiving_currency",
  "dim_payment_format",
  "dim_bank",
  "dim_pattern_type",
  "kpi_overview",
  "fact_daily_transaction",
  "fact_aml_payment_format",
  "fact_bank_activity",
  "fact_currency_flow",
  "fact_pattern_summary",
  "fact_aml_account_risk",
  "etl_batch_monitor",
  "etl_validation_result",
  "data_quality_overview",
];

function excelColumn(index) {
  let number = index;
  let result = "";
  while (number > 0) {
    const remainder = (number - 1) % 26;
    result = String.fromCharCode(65 + remainder) + result;
    number = Math.floor((number - 1) / 26);
  }
  return result;
}

function widthFor(header) {
  const value = header.toLowerCase();
  if (value.includes("details") || value.includes("error_message")) return 42;
  if (value.includes("name") || value.includes("format") || value.includes("currency")) return 25;
  if (value.includes("timestamp") || value.endsWith("_at")) return 24;
  if (value.includes("date")) return 15;
  if (value.includes("account") || value.includes("entity")) return 20;
  if (value.includes("status") || value.includes("type")) return 18;
  if (value.includes("amount")) return 20;
  if (value.includes("rate") || value.includes("duration")) return 16;
  return 15;
}

await fs.mkdir(outputDir, { recursive: true });
await fs.mkdir(qaDir, { recursive: true });

const workbook = Workbook.create();
const readme = workbook.worksheets.add("00_README");
readme.showGridLines = false;
readme.getRange("A1:F1").merge();
readme.getRange("A1").values = [["IBM AML — Power BI Cloud Source"]];
readme.getRange("A1:F1").format = {
  fill: "#0B1220",
  font: { color: "#FFFFFF", bold: true, size: 18 },
  verticalAlignment: "center",
};
readme.getRange("A1:F1").format.rowHeight = 38;
readme.getRange("A3:B11").values = [
  ["Purpose", "Single-file cloud import source for Power BI Service"],
  ["Source", "PostgreSQL DW curated reporting snapshot"],
  ["Dataset", "IBM AML HI-Medium"],
  ["Data period", "2022-09-01 to 2022-09-28"],
  ["Tables", "16 model tables, each stored as an Excel table"],
  ["Cloud scope", "Full KPI aggregates; Top 1,000 banks and Top 5,000 AML accounts"],
  ["Expected transactions", 31898238],
  ["Expected laundering", 35230],
  ["Important", "Do not import the 00_README sheet into the semantic model"],
];
readme.getRange("A3:A11").format = {
  fill: "#EAF1FF",
  font: { bold: true, color: "#253146" },
};
readme.getRange("A3:B11").format.borders = {
  preset: "inside",
  style: "thin",
  color: "#E4E8EF",
};
readme.getRange("A3:A11").format.columnWidth = 23;
readme.getRange("B3:B11").format.columnWidth = 65;
readme.getRange("A3:B11").format.rowHeight = 24;
readme.freezePanes.freezeRows(1);

const importStats = [];
const previewRanges = new Map([["00_README", "A1:F19"]]);
for (const tableName of tables) {
  const csvPath = path.join(snapshotDir, `${tableName}.csv`);
  const csvText = await fs.readFile(csvPath, "utf8");
  const importedWorkbook = await Workbook.fromCSV(csvText, { sheetName: tableName });
  const importedSheet = importedWorkbook.worksheets.getItem(tableName);
  const importedValues = importedSheet.getUsedRange(true).values;
  const rowCount = importedValues.length;
  const columnCount = importedValues[0].length;
  const headers = importedValues[0].map((value) => String(value));
  const identifierColumns = headers
    .map((header, index) => ({ header: header.toLowerCase(), index }))
    .filter(({ header }) => header.endsWith("_id") || header.endsWith("_number"));
  for (const { index } of identifierColumns) {
    for (let rowIndex = 1; rowIndex < rowCount; rowIndex += 1) {
      const value = importedValues[rowIndex][index];
      if (value !== null && value !== undefined && value !== "") {
        importedValues[rowIndex][index] = String(value);
      }
    }
  }

  const sheet = workbook.worksheets.add(tableName);
  const endColumn = excelColumn(columnCount);
  const usedAddress = `A1:${endColumn}${rowCount}`;
  for (const { index } of identifierColumns) {
    const columnLetter = excelColumn(index + 1);
    sheet.getRange(`${columnLetter}2:${columnLetter}${rowCount}`).format.numberFormat = "@";
  }
  sheet.getRange(usedAddress).values = importedValues;
  sheet.showGridLines = false;
  sheet.freezePanes.freezeRows(1);

  const headerRange = sheet.getRange(`A1:${endColumn}1`);
  headerRange.format = {
    fill: "#0B1220",
    font: { color: "#FFFFFF", bold: true, size: 9 },
    verticalAlignment: "center",
    wrapText: true,
    borders: { preset: "inside", style: "thin", color: "#26334A" },
  };
  headerRange.format.rowHeight = 30;

  for (let columnIndex = 0; columnIndex < columnCount; columnIndex += 1) {
    const columnLetter = excelColumn(columnIndex + 1);
    sheet.getRange(`${columnLetter}1:${columnLetter}${rowCount}`).format.columnWidth =
      widthFor(headers[columnIndex]);
  }

  const dataRange = sheet.getRange(`A2:${endColumn}${Math.min(rowCount, 5000)}`);
  dataRange.format.font = { size: 9, color: "#334055" };
  dataRange.format.rowHeight = 18;
  sheet.tables.add(usedAddress, true, `tbl_${tableName}`);
  importStats.push([tableName, rowCount - 1, columnCount]);
  previewRanges.set(tableName, `A1:${endColumn}${Math.min(rowCount, 24)}`);
}

readme.getRange("D3:F3").values = [["Table", "Rows", "Columns"]];
readme.getRange(`D4:F${3 + importStats.length}`).values = importStats;
readme.getRange("D3:F3").format = {
  fill: "#2563EB",
  font: { color: "#FFFFFF", bold: true },
};
readme.getRange(`D3:F${3 + importStats.length}`).format.borders = {
  insideHorizontal: { style: "thin", color: "#E4E8EF" },
};
readme.getRange(`D4:D${3 + importStats.length}`).format.columnWidth = 31;
readme.getRange(`E4:F${3 + importStats.length}`).format.columnWidth = 13;
readme.getRange(`E4:F${3 + importStats.length}`).format.numberFormat = "#,##0";

const check = await workbook.inspect({
  kind: "table",
  range: "00_README!A1:F19",
  include: "values,formulas",
  tableMaxRows: 20,
  tableMaxCols: 6,
});
console.log(check.ndjson);

const kpiCheck = await workbook.inspect({
  kind: "table",
  range: "kpi_overview!A1:I2",
  include: "values,formulas",
  tableMaxRows: 3,
  tableMaxCols: 10,
});
console.log(kpiCheck.ndjson);

const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 100 },
  summary: "final formula error scan",
});
console.log(errors.ndjson);

for (const sheetName of ["00_README", ...tables]) {
  const preview = await workbook.render({
    sheetName,
    range: previewRanges.get(sheetName),
    autoCrop: "all",
    scale: 1,
    format: "png",
  });
  const bytes = new Uint8Array(await preview.arrayBuffer());
  await fs.writeFile(path.join(qaDir, `${sheetName}.png`), bytes);
}

const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(outputPath);
console.log(`Created ${outputPath}`);
