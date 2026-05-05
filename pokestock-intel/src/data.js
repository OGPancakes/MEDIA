import { supabase } from "./supabaseClient";

const STORE_KEY = "pokestock-intel-data-v1";
const DATA_BACKEND = import.meta.env.VITE_DATA_BACKEND || "local";
export const dataBackend = DATA_BACKEND;

const now = () => new Date().toISOString();

export const seedData = {
  stores: [
    {
      id: "11111111-1111-4111-8111-111111111111",
      name: "Target East Ridge",
      address: "2210 Meridian Ave",
      city: "Tampa",
      state: "FL",
      latitude: 27.9642,
      longitude: -82.4526,
      notes_summary: "Vendor usually appears after grocery truck; electronics lead is friendly.",
      confidence_score: 86,
      created_at: now(),
    },
    {
      id: "22222222-2222-4222-8222-222222222222",
      name: "Walmart Supercenter North",
      address: "1448 Bayline Rd",
      city: "Tampa",
      state: "FL",
      latitude: 28.0218,
      longitude: -82.5056,
      notes_summary: "High traffic, fast sellouts, strong Tuesday pattern.",
      confidence_score: 74,
      created_at: now(),
    },
    {
      id: "33333333-3333-4333-8333-333333333333",
      name: "GameStop Midtown",
      address: "808 Archer St",
      city: "Tampa",
      state: "FL",
      latitude: 27.9465,
      longitude: -82.4897,
      notes_summary: "Smaller drops, staff will confirm delivery windows if asked quietly.",
      confidence_score: 61,
      created_at: now(),
    },
  ],
  restock_logs: [
    {
      id: "aaaaaaa1-1111-4111-8111-aaaaaaaaaaa1",
      store_id: "11111111-1111-4111-8111-111111111111",
      date: "2026-05-03",
      time: "10:20",
      stock_type: "Scarlet & Violet booster bundles",
      sellout_speed_minutes: 38,
      notes: "Two displays at front lanes; vendor left 10:35.",
      created_at: now(),
    },
    {
      id: "aaaaaaa2-2222-4222-8222-aaaaaaaaaaa2",
      store_id: "11111111-1111-4111-8111-111111111111",
      date: "2026-04-26",
      time: "10:05",
      stock_type: "Elite Trainer Boxes",
      sellout_speed_minutes: 55,
      notes: "Restocked behind electronics counter first.",
      created_at: now(),
    },
    {
      id: "bbbbbbb1-1111-4111-8111-bbbbbbbbbbb1",
      store_id: "22222222-2222-4222-8222-222222222222",
      date: "2026-04-29",
      time: "08:45",
      stock_type: "151 poster collections",
      sellout_speed_minutes: 22,
      notes: "Line formed before doors.",
      created_at: now(),
    },
    {
      id: "ccccccc1-1111-4111-8111-ccccccccccc1",
      store_id: "33333333-3333-4333-8333-333333333333",
      date: "2026-04-18",
      time: "13:30",
      stock_type: "Sleeved boosters",
      sellout_speed_minutes: 120,
      notes: "Small quantity, lower collector pressure.",
      created_at: now(),
    },
  ],
  intel_notes: [
    {
      id: "ddddddd1-1111-4111-8111-ddddddddddd1",
      store_id: "11111111-1111-4111-8111-111111111111",
      note: "Employee said vendor prefers Sunday late morning after grocery inventory clears.",
      source_type: "employee",
      created_at: now(),
    },
    {
      id: "eeeeeee1-1111-4111-8111-eeeeeeeeeee1",
      store_id: "22222222-2222-4222-8222-222222222222",
      note: "Observed restock cart staged near customer service before opening.",
      source_type: "observation",
      created_at: now(),
    },
    {
      id: "fffffff1-1111-4111-8111-fffffffffff1",
      store_id: "33333333-3333-4333-8333-333333333333",
      note: "Rumor from local group: distributor skipped last week and may double-drop.",
      source_type: "rumor",
      created_at: now(),
    },
  ],
  inventory_items: [
    {
      id: "44444444-4444-4444-8444-444444444444",
      item: "Scarlet & Violet Booster Bundle",
      category: "Booster bundle",
      quantity: 4,
      condition: "Sealed",
      location: "Main closet bin A",
      cost: 26.99,
      market_value: 34.99,
      notes: "Hold two, trade two if restock dries up.",
      created_at: now(),
    },
    {
      id: "55555555-5555-4555-8555-555555555555",
      item: "151 Poster Collection",
      category: "Collection box",
      quantity: 2,
      condition: "Sealed",
      location: "Shelf 2",
      cost: 14.99,
      market_value: 22,
      notes: "Fast mover locally.",
      created_at: now(),
    },
  ],
};

const readLocal = () => {
  const cached = localStorage.getItem(STORE_KEY);
  if (!cached) {
    localStorage.setItem(STORE_KEY, JSON.stringify(seedData));
    return seedData;
  }
  return JSON.parse(cached);
};

const writeLocal = (data) => {
  localStorage.setItem(STORE_KEY, JSON.stringify(data));
  return data;
};

const sortByCreated = (rows) =>
  [...rows].sort((a, b) => new Date(b.created_at) - new Date(a.created_at));

const authHeaders = () => {
  const token = sessionStorage.getItem("pokestock-admin-token");
  return token ? { authorization: `Bearer ${token}` } : {};
};

export async function loadIntelData() {
  if (DATA_BACKEND === "notion") {
    const response = await fetch("/api/notion-data", {
      headers: authHeaders(),
    });
    const data = await response.json();
    if (!response.ok) throw new Error(data.error || "Unable to load Notion data.");
    return data;
  }

  if (!supabase) return readLocal();

  const [stores, restockLogs, intelNotes] = await Promise.all([
    supabase.from("stores").select("*").order("created_at", { ascending: false }),
    supabase.from("restock_logs").select("*").order("date", { ascending: false }),
    supabase.from("intel_notes").select("*").order("created_at", { ascending: false }),
  ]);

  if (stores.error || restockLogs.error || intelNotes.error) {
    throw stores.error || restockLogs.error || intelNotes.error;
  }

  return {
    stores: stores.data || [],
    restock_logs: restockLogs.data || [],
    intel_notes: intelNotes.data || [],
    inventory_items: [],
  };
}

export async function addStore(payload) {
  if (DATA_BACKEND === "notion") {
    const response = await fetch("/api/notion-create", {
      method: "POST",
      headers: { "content-type": "application/json", ...authHeaders() },
      body: JSON.stringify({ type: "store", payload }),
    });
    const data = await response.json();
    if (!response.ok) throw new Error(data.error || "Unable to create Notion store.");
    return data;
  }

  const row = {
    id: crypto.randomUUID(),
    confidence_score: Number(payload.confidence_score || 50),
    latitude: Number(payload.latitude || 0),
    longitude: Number(payload.longitude || 0),
    created_at: now(),
    ...payload,
  };

  if (supabase) {
    const { data, error } = await supabase.from("stores").insert(row).select().single();
    if (error) throw error;
    return data;
  }

  const data = readLocal();
  writeLocal({ ...data, stores: sortByCreated([row, ...data.stores]) });
  return row;
}

export async function addRestockLog(payload) {
  if (DATA_BACKEND === "notion") {
    const response = await fetch("/api/notion-create", {
      method: "POST",
      headers: { "content-type": "application/json", ...authHeaders() },
      body: JSON.stringify({ type: "log", payload }),
    });
    const data = await response.json();
    if (!response.ok) throw new Error(data.error || "Unable to create Notion restock log.");
    return data;
  }

  const row = {
    id: crypto.randomUUID(),
    sellout_speed_minutes: Number(payload.sellout_speed_minutes || 0),
    created_at: now(),
    ...payload,
  };

  if (supabase) {
    const { data, error } = await supabase.from("restock_logs").insert(row).select().single();
    if (error) throw error;
    return data;
  }

  const data = readLocal();
  writeLocal({ ...data, restock_logs: sortByCreated([row, ...data.restock_logs]) });
  return row;
}

export async function addIntelNote(payload) {
  if (DATA_BACKEND === "notion") {
    const response = await fetch("/api/notion-create", {
      method: "POST",
      headers: { "content-type": "application/json", ...authHeaders() },
      body: JSON.stringify({ type: "note", payload }),
    });
    const data = await response.json();
    if (!response.ok) throw new Error(data.error || "Unable to create Notion note.");
    return data;
  }

  const row = {
    id: crypto.randomUUID(),
    created_at: now(),
    ...payload,
  };

  if (supabase) {
    const { data, error } = await supabase.from("intel_notes").insert(row).select().single();
    if (error) throw error;
    return data;
  }

  const data = readLocal();
  writeLocal({ ...data, intel_notes: sortByCreated([row, ...data.intel_notes]) });
  return row;
}

export async function addInventoryItem(payload) {
  if (DATA_BACKEND === "notion") {
    const response = await fetch("/api/notion-create", {
      method: "POST",
      headers: { "content-type": "application/json", ...authHeaders() },
      body: JSON.stringify({ type: "inventory", payload }),
    });
    const data = await response.json();
    if (!response.ok) throw new Error(data.error || "Unable to create Notion inventory item.");
    return data;
  }

  const row = {
    id: crypto.randomUUID(),
    quantity: Number(payload.quantity || 0),
    cost: Number(payload.cost || 0),
    market_value: Number(payload.market_value || 0),
    created_at: now(),
    ...payload,
  };

  const data = readLocal();
  writeLocal({
    ...data,
    inventory_items: sortByCreated([row, ...(data.inventory_items || [])]),
  });
  return row;
}

export async function deleteRecord(type, id, relatedIds = []) {
  if (DATA_BACKEND === "notion") {
    const response = await fetch("/api/notion-delete", {
      method: "POST",
      headers: { "content-type": "application/json", ...authHeaders() },
      body: JSON.stringify({ type, id, relatedIds }),
    });
    const data = await response.json();
    if (!response.ok) throw new Error(data.error || "Unable to delete Notion record.");
    return data;
  }

  if (supabase) {
    const table =
      type === "store"
        ? "stores"
        : type === "log"
          ? "restock_logs"
          : type === "inventory"
            ? "inventory_items"
            : "intel_notes";
    const { error } = await supabase.from(table).delete().eq("id", id);
    if (error) throw error;
    return { id };
  }

  const data = readLocal();
  if (type === "store") {
    writeLocal({
      stores: data.stores.filter((store) => store.id !== id),
      restock_logs: data.restock_logs.filter((log) => log.store_id !== id),
      intel_notes: data.intel_notes.filter((note) => note.store_id !== id),
    });
  }
  if (type === "log") {
    writeLocal({ ...data, restock_logs: data.restock_logs.filter((log) => log.id !== id) });
  }
  if (type === "note") {
    writeLocal({ ...data, intel_notes: data.intel_notes.filter((note) => note.id !== id) });
  }
  if (type === "inventory") {
    writeLocal({
      ...data,
      inventory_items: (data.inventory_items || []).filter((item) => item.id !== id),
    });
  }
  return { id };
}
