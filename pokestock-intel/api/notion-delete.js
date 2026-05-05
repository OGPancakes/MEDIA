import { requireAdmin } from "./_admin-session.js";

const notionVersion = "2025-09-03";

const notionHeaders = () => ({
  authorization: `Bearer ${process.env.NOTION_API_KEY}`,
  "content-type": "application/json",
  "notion-version": notionVersion,
});

async function archivePage(pageId) {
  const response = await fetch(`https://api.notion.com/v1/pages/${pageId}`, {
    method: "PATCH",
    headers: notionHeaders(),
    body: JSON.stringify({ archived: true }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Notion delete failed: ${response.status} ${body}`);
  }

  return response.json();
}

export default async function handler(request, response) {
  if (request.method !== "POST") {
    return response.status(405).json({ error: "Method not allowed." });
  }

  if (!requireAdmin(request, response)) return;

  try {
    if (!process.env.NOTION_API_KEY) {
      return response.status(500).json({ error: "Missing NOTION_API_KEY." });
    }

    const { type, id, relatedIds = [] } = request.body || {};
    if (!["store", "log", "note", "inventory"].includes(type) || !id) {
      return response.status(400).json({ error: "Missing delete type or record id." });
    }

    const ids = type === "store" ? [...relatedIds, id] : [id];
    await Promise.all([...new Set(ids)].map(archivePage));
    return response.status(200).json({ deleted: ids });
  } catch (error) {
    return response.status(500).json({ error: error.message || "Unable to delete Notion record." });
  }
}
