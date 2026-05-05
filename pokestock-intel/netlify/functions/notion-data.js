import { requireAdmin, response } from "./_admin-session.js";

const notionVersion = "2025-09-03";
const notionHeaders = () => ({
  authorization: `Bearer ${process.env.NOTION_API_KEY}`,
  "content-type": "application/json",
  "notion-version": notionVersion,
});

const richText = (property) => property?.rich_text?.map((item) => item.plain_text).join("") || "";
const title = (property) => property?.title?.map((item) => item.plain_text).join("") || "";
const select = (property) => property?.select?.name || "";
const number = (property) => property?.number ?? 0;
const date = (property) => property?.date?.start || "";
const relationId = (property) => property?.relation?.[0]?.id || "";

async function queryDataSource(dataSourceId) {
  const notionResponse = await fetch(`https://api.notion.com/v1/data_sources/${dataSourceId}/query`, {
    method: "POST",
    headers: notionHeaders(),
    body: JSON.stringify({ page_size: 100 }),
  });
  if (!notionResponse.ok) {
    throw new Error(`Notion query failed: ${notionResponse.status} ${await notionResponse.text()}`);
  }
  return notionResponse.json();
}

const normalizeStore = (page) => ({
  id: page.id,
  name: title(page.properties.Name),
  address: richText(page.properties.Address),
  city: richText(page.properties.City),
  state: select(page.properties.State) || "Other",
  latitude: number(page.properties.Latitude),
  longitude: number(page.properties.Longitude),
  notes_summary: richText(page.properties["Notes Summary"]),
  confidence_score: number(page.properties["Confidence Score"]),
  created_at: page.created_time,
});

const normalizeLog = (page) => ({
  id: page.id,
  store_id: relationId(page.properties.Store),
  date: date(page.properties.Date),
  time: richText(page.properties.Time),
  stock_type: richText(page.properties["Stock Type"]),
  sellout_speed_minutes: number(page.properties["Sellout Speed Minutes"]),
  notes: richText(page.properties.Notes),
  created_at: page.created_time,
});

const normalizeNote = (page) => ({
  id: page.id,
  store_id: relationId(page.properties.Store),
  note: title(page.properties.Note),
  source_type: select(page.properties["Source Type"]) || "observation",
  created_at: page.created_time,
});

const normalizeInventoryItem = (page) => ({
  id: page.id,
  item: title(page.properties.Item),
  category: select(page.properties.Category) || "Other",
  quantity: number(page.properties.Quantity),
  condition: select(page.properties.Condition) || "Sealed",
  location: richText(page.properties.Location),
  cost: number(page.properties.Cost),
  market_value: number(page.properties["Market Value"]),
  notes: richText(page.properties.Notes),
  created_at: page.created_time,
});

export const handler = async (event) => {
  if (!requireAdmin(event)) return response(401, { error: "Admin login required." });
  if (!process.env.NOTION_API_KEY) return response(500, { error: "Missing NOTION_API_KEY." });

  try {
    const [stores, restockLogs, intelNotes, inventoryItems] = await Promise.all([
      queryDataSource(process.env.NOTION_STORES_DATA_SOURCE_ID),
      queryDataSource(process.env.NOTION_RESTOCK_LOGS_DATA_SOURCE_ID),
      queryDataSource(process.env.NOTION_INTEL_NOTES_DATA_SOURCE_ID),
      queryDataSource(process.env.NOTION_INVENTORY_DATA_SOURCE_ID),
    ]);

    return response(200, {
      stores: stores.results.map(normalizeStore),
      restock_logs: restockLogs.results.map(normalizeLog),
      intel_notes: intelNotes.results.map(normalizeNote),
      inventory_items: inventoryItems.results.map(normalizeInventoryItem),
    });
  } catch (error) {
    return response(500, { error: error.message || "Unable to read Notion data." });
  }
};
