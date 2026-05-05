import { requireAdmin, response } from "./_admin-session.js";

const notionVersion = "2025-09-03";
const notionHeaders = () => ({
  authorization: `Bearer ${process.env.NOTION_API_KEY}`,
  "content-type": "application/json",
  "notion-version": notionVersion,
});

async function archivePage(pageId) {
  const notionResponse = await fetch(`https://api.notion.com/v1/pages/${pageId}`, {
    method: "PATCH",
    headers: notionHeaders(),
    body: JSON.stringify({ archived: true }),
  });
  if (!notionResponse.ok) {
    throw new Error(`Notion delete failed: ${notionResponse.status} ${await notionResponse.text()}`);
  }
  return notionResponse.json();
}

export const handler = async (event) => {
  if (event.httpMethod !== "POST") return response(405, { error: "Method not allowed." });
  if (!requireAdmin(event)) return response(401, { error: "Admin login required." });
  if (!process.env.NOTION_API_KEY) return response(500, { error: "Missing NOTION_API_KEY." });

  try {
    const { type, id, relatedIds = [] } = JSON.parse(event.body || "{}");
    if (!["store", "log", "note", "inventory"].includes(type) || !id) {
      return response(400, { error: "Missing delete type or record id." });
    }
    const ids = type === "store" ? [...relatedIds, id] : [id];
    await Promise.all([...new Set(ids)].map(archivePage));
    return response(200, { deleted: ids });
  } catch (error) {
    return response(500, { error: error.message || "Unable to delete Notion record." });
  }
};
