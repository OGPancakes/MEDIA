import { requireAdmin, response } from "./_admin-session.js";

const notionVersion = "2025-09-03";
const validStates = new Set(["AL", "AK", "AZ", "AR", "CA", "CO", "CT", "FL", "GA", "IL", "MA", "MI", "NC", "NJ", "NY", "OH", "PA", "TX", "VA", "WA", "Other"]);
const validInventoryCategories = new Set(["Booster box", "ETB", "Booster bundle", "Sleeved boosters", "Collection box", "Single card", "Other"]);
const validConditions = new Set(["Sealed", "Mint", "Near mint", "Played", "Damaged"]);

const notionHeaders = () => ({
  authorization: `Bearer ${process.env.NOTION_API_KEY}`,
  "content-type": "application/json",
  "notion-version": notionVersion,
});
const text = (content = "") => ({ rich_text: [{ text: { content: String(content) } }] });
const title = (content = "") => ({ title: [{ text: { content: String(content) } }] });
const number = (value) => ({ number: Number(value || 0) });
const select = (name) => ({ select: { name } });
const relation = (pageId) => ({ relation: pageId ? [{ id: pageId }] : [] });
const storeStatus = (score) => Number(score) >= 80 ? "Recent restock" : Number(score) >= 60 ? "Likely soon" : "Inactive";

async function createPage(parentId, properties) {
  const notionResponse = await fetch("https://api.notion.com/v1/pages", {
    method: "POST",
    headers: notionHeaders(),
    body: JSON.stringify({ parent: { type: "data_source_id", data_source_id: parentId }, properties }),
  });
  if (!notionResponse.ok) {
    throw new Error(`Notion create failed: ${notionResponse.status} ${await notionResponse.text()}`);
  }
  return notionResponse.json();
}

export const handler = async (event) => {
  if (event.httpMethod !== "POST") return response(405, { error: "Method not allowed." });
  if (!requireAdmin(event)) return response(401, { error: "Admin login required." });
  if (!process.env.NOTION_API_KEY) return response(500, { error: "Missing NOTION_API_KEY." });

  try {
    const { type, payload } = JSON.parse(event.body || "{}");
    let page;

    if (type === "store") {
      const state = validStates.has(payload.state) ? payload.state : "Other";
      page = await createPage(process.env.NOTION_STORES_DATA_SOURCE_ID, {
        Name: title(payload.name),
        Address: text(payload.address),
        City: text(payload.city),
        State: select(state),
        Latitude: number(payload.latitude),
        Longitude: number(payload.longitude),
        "Notes Summary": text(payload.notes_summary),
        "Confidence Score": number(payload.confidence_score || 50),
        Status: select(storeStatus(payload.confidence_score || 50)),
      });
    }

    if (type === "log") {
      page = await createPage(process.env.NOTION_RESTOCK_LOGS_DATA_SOURCE_ID, {
        Log: title(`${payload.stock_type || "Restock"} - ${payload.date || ""}`),
        Store: relation(payload.store_id),
        Date: { date: { start: payload.date } },
        Time: text(payload.time),
        "Stock Type": text(payload.stock_type),
        "Sellout Speed Minutes": number(payload.sellout_speed_minutes),
        Notes: text(payload.notes),
      });
    }

    if (type === "note") {
      page = await createPage(process.env.NOTION_INTEL_NOTES_DATA_SOURCE_ID, {
        Note: title(payload.note),
        Store: relation(payload.store_id),
        "Source Type": select(payload.source_type || "observation"),
        Confidence: number(payload.confidence || 50),
      });
    }

    if (type === "inventory") {
      const category = validInventoryCategories.has(payload.category) ? payload.category : "Other";
      const condition = validConditions.has(payload.condition) ? payload.condition : "Sealed";
      page = await createPage(process.env.NOTION_INVENTORY_DATA_SOURCE_ID, {
        Item: title(payload.item),
        Category: select(category),
        Quantity: number(payload.quantity || 1),
        Condition: select(condition),
        Location: text(payload.location),
        Cost: number(payload.cost),
        "Market Value": number(payload.market_value),
        Notes: text(payload.notes),
      });
    }

    if (!page) return response(400, { error: "Unknown Notion create type." });
    return response(200, { id: page.id });
  } catch (error) {
    return response(500, { error: error.message || "Unable to create Notion record." });
  }
};
