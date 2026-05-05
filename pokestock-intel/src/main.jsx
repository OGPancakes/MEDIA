import React, { useEffect, useMemo, useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import { AnimatePresence, motion } from "framer-motion";
import { importLibrary, setOptions } from "@googlemaps/js-api-loader";
import {
  Activity,
  Brain,
  CalendarClock,
  ChevronRight,
  Clock,
  Database,
  Flame,
  Gauge,
  Layers,
  LocateFixed,
  Map,
  MapPin,
  Package,
  Plus,
  Radar,
  Route,
  Search,
  Shield,
  Sparkles,
  Store,
  Timer,
  Trash2,
  X,
} from "lucide-react";
import {
  addIntelNote,
  addInventoryItem,
  addRestockLog,
  addStore,
  dataBackend,
  deleteRecord,
  loadIntelData,
} from "./data";
import { isSupabaseConfigured } from "./supabaseClient";
import "./styles.css";

let configuredMapsKey = null;

const tabs = [
  { id: "dashboard", label: "Dashboard", icon: Radar },
  { id: "stores", label: "Stores", icon: Store },
  { id: "inventory", label: "Inventory", icon: Package },
  { id: "map", label: "Map", icon: Map },
];

const sourceStyles = {
  employee: "bg-emerald-300/15 text-emerald-100 border-emerald-200/20",
  observation: "bg-sky-300/15 text-sky-100 border-sky-200/20",
  rumor: "bg-amber-300/15 text-amber-100 border-amber-200/20",
};

const formatDate = (value) =>
  new Intl.DateTimeFormat("en", { month: "short", day: "numeric" }).format(new Date(`${value}T12:00:00`));

const dayName = (value) =>
  new Intl.DateTimeFormat("en", { weekday: "long" }).format(new Date(`${value}T12:00:00`));

const minutesSince = (date) => {
  if (!date) return Infinity;
  const then = new Date(`${date}T12:00:00`).getTime();
  return Math.floor((Date.now() - then) / 60000);
};

const getStoreLogs = (store, logs) =>
  logs
    .filter((log) => log.store_id === store.id)
    .sort((a, b) => `${b.date}T${b.time}`.localeCompare(`${a.date}T${a.time}`));

const getStoreNotes = (store, notes) =>
  notes
    .filter((note) => note.store_id === store.id)
    .sort((a, b) => new Date(b.created_at) - new Date(a.created_at));

const getStatus = (store, logs) => {
  const last = getStoreLogs(store, logs)[0];
  const ageHours = minutesSince(last?.date) / 60;
  if (ageHours <= 72) return { label: "Recent restock", color: "green", tone: "bg-emerald-300" };
  if (store.confidence_score >= 70) return { label: "Likely soon", color: "yellow", tone: "bg-amber-300" };
  return { label: "Inactive", color: "red", tone: "bg-rose-400" };
};

const mapStyles = [
  { elementType: "geometry", stylers: [{ color: "#182131" }] },
  { elementType: "labels.text.fill", stylers: [{ color: "#cbd5e1" }] },
  { elementType: "labels.text.stroke", stylers: [{ color: "#111827" }] },
  { featureType: "administrative", elementType: "geometry", stylers: [{ visibility: "off" }] },
  { featureType: "poi", stylers: [{ visibility: "off" }] },
  { featureType: "road", elementType: "geometry", stylers: [{ color: "#2b3648" }] },
  { featureType: "road", elementType: "geometry.stroke", stylers: [{ color: "#111827" }] },
  { featureType: "road", elementType: "labels.icon", stylers: [{ visibility: "off" }] },
  { featureType: "transit", stylers: [{ visibility: "off" }] },
  { featureType: "water", elementType: "geometry", stylers: [{ color: "#0e7490" }] },
];

const markerColors = {
  green: "#86efac",
  yellow: "#fde68a",
  red: "#fb7185",
};

const markerIcon = (color) => ({
  url: `data:image/svg+xml;charset=UTF-8,${encodeURIComponent(`
    <svg width="42" height="42" viewBox="0 0 42 42" xmlns="http://www.w3.org/2000/svg">
      <filter id="glow" x="-80%" y="-80%" width="260%" height="260%">
        <feGaussianBlur stdDeviation="4" result="blur"/>
        <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
      </filter>
      <circle cx="21" cy="21" r="16" fill="${color}" opacity="0.2" filter="url(#glow)"/>
      <path d="M21 4.5c-6.15 0-11.15 4.84-11.15 10.82 0 8.12 11.15 22.18 11.15 22.18s11.15-14.06 11.15-22.18C32.15 9.34 27.15 4.5 21 4.5Z" fill="${color}" filter="url(#glow)"/>
      <circle cx="21" cy="15.7" r="4.45" fill="#111827" opacity="0.72"/>
    </svg>
  `)}`,
  scaledSize: new google.maps.Size(42, 42),
  anchor: new google.maps.Point(21, 38),
});

const escapeHtml = (value) =>
  String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");

const getStats = (store, logs) => {
  const storeLogs = getStoreLogs(store, logs);
  if (!storeLogs.length) {
    return { commonDay: "No signal", avgTime: "No logs", avgSellout: "Unknown" };
  }

  const dayCounts = storeLogs.reduce((acc, log) => {
    const day = dayName(log.date);
    acc[day] = (acc[day] || 0) + 1;
    return acc;
  }, {});
  const commonDay = Object.entries(dayCounts).sort((a, b) => b[1] - a[1])[0][0];

  const avgMinutes =
    storeLogs.reduce((sum, log) => {
      const [hour, minute] = log.time.split(":").map(Number);
      return sum + hour * 60 + minute;
    }, 0) / storeLogs.length;
  const avgHour = Math.floor(avgMinutes / 60);
  const avgMinute = Math.round(avgMinutes % 60);
  const avgTime = new Date(2026, 0, 1, avgHour, avgMinute).toLocaleTimeString([], {
    hour: "numeric",
    minute: "2-digit",
  });

  const sellouts = storeLogs
    .map((log) => Number(log.sellout_speed_minutes))
    .filter(Boolean);
  const avgSellout = sellouts.length
    ? `${Math.round(sellouts.reduce((sum, item) => sum + item, 0) / sellouts.length)} min`
    : "Unknown";

  return { commonDay, avgTime, avgSellout };
};

function GlassPanel({ children, className = "", delay = 0 }) {
  return (
    <motion.section
      initial={{ opacity: 0, y: 14 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.45, delay }}
      className={`glass-panel ${className}`}
    >
      {children}
    </motion.section>
  );
}

function StatTile({ icon: Icon, label, value }) {
  return (
    <div className="rounded-[18px] border border-white/10 bg-white/[0.055] p-4">
      <div className="mb-4 flex h-10 w-10 items-center justify-center rounded-2xl bg-white/10 text-cyan-100">
        <Icon size={18} />
      </div>
      <p className="text-xs uppercase tracking-[0.18em] text-slate-400">{label}</p>
      <p className="mt-1 text-2xl font-semibold text-white">{value}</p>
    </div>
  );
}

function Header({ activeTab, setActiveTab, setModal, onSignOut }) {
  return (
    <header className="glass-panel sticky top-4 z-30 mx-auto flex w-[calc(100%-2rem)] max-w-7xl items-center justify-between gap-4 px-4 py-3">
      <button className="brand-button" onClick={() => setActiveTab("dashboard")}>
        <span className="brand-mark"><Shield size={18} /></span>
        <span>
          <span className="block text-sm font-semibold leading-none text-white">POKÉSTOCK</span>
          <span className="block text-[10px] font-medium uppercase tracking-[0.28em] text-cyan-100/70">Intel</span>
        </span>
      </button>

      <nav className="hidden items-center rounded-full border border-white/10 bg-white/[0.055] p-1 md:flex">
        {tabs.map((tab) => {
          const Icon = tab.icon;
          return (
            <button
              key={tab.id}
              className={`nav-pill ${activeTab === tab.id ? "active" : ""}`}
              onClick={() => setActiveTab(tab.id)}
            >
              <Icon size={16} />
              {tab.label}
            </button>
          );
        })}
      </nav>

      <div className="flex items-center gap-2">
        <button className="icon-button" title="Add store" onClick={() => setModal("store")}>
          <Plus size={18} />
        </button>
        <button className="hidden rounded-full border border-white/10 bg-white/[0.07] px-4 py-2 text-sm font-semibold text-white transition hover:-translate-y-0.5 hover:bg-white/[0.11] sm:inline-flex" onClick={() => setModal("log")}>
          Quick log
        </button>
        <button className="hidden rounded-full border border-white/10 bg-white/[0.045] px-4 py-2 text-sm font-semibold text-slate-300 transition hover:-translate-y-0.5 hover:bg-white/[0.09] sm:inline-flex" onClick={onSignOut}>
          Sign out
        </button>
      </div>
    </header>
  );
}

function Dashboard({ data, setActiveTab, selectStore, setModal }) {
  const recentLogs = [...data.restock_logs].sort((a, b) => `${b.date}T${b.time}`.localeCompare(`${a.date}T${a.time}`));
  const hotStores = [...data.stores].sort((a, b) => b.confidence_score - a.confidence_score).slice(0, 3);
  const avgConfidence = Math.round(data.stores.reduce((sum, store) => sum + Number(store.confidence_score || 0), 0) / Math.max(data.stores.length, 1));

  return (
    <main className="mx-auto grid w-full max-w-7xl gap-4 px-4 pb-8 pt-6 lg:grid-cols-[1.2fr_0.8fr]">
      <GlassPanel className="dashboard-hero relative min-h-[460px] overflow-hidden p-5 md:p-7" delay={0.05}>
        <MapSurface data={data} selectStore={selectStore} compact />
        <div className="pointer-events-none absolute inset-x-5 top-5 flex flex-wrap items-start justify-between gap-4 md:inset-x-7 md:top-7">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.24em] text-cyan-100/70">Private restock intelligence</p>
            <h1 className="mt-2 max-w-xl text-4xl font-semibold leading-tight text-white md:text-6xl">Predict the next clean hit.</h1>
          </div>
          <div className="rounded-full border border-emerald-200/20 bg-emerald-300/10 px-4 py-2 text-sm font-semibold text-emerald-100">
            {dataBackend === "notion" ? "Notion online" : isSupabaseConfigured ? "Supabase online" : "Local demo mode"}
          </div>
        </div>
        <div className="absolute bottom-5 left-5 right-5 grid gap-3 md:bottom-7 md:left-7 md:right-7 md:grid-cols-3">
          <StatTile icon={Store} label="Stores" value={data.stores.length} />
          <StatTile icon={Activity} label="Logs" value={data.restock_logs.length} />
          <StatTile icon={Gauge} label="Avg confidence" value={`${avgConfidence}%`} />
        </div>
      </GlassPanel>

      <div className="grid gap-4">
        <GlassPanel className="p-5" delay={0.12}>
          <div className="mb-4 flex items-center justify-between">
            <div>
              <p className="section-kicker">Fast entry</p>
              <h2 className="section-title">Field capture</h2>
            </div>
            <Database className="text-cyan-100/70" size={22} />
          </div>
          <div className="grid gap-3">
            <button className="action-row" onClick={() => setModal("store")}><Plus size={18} /> Add store <ChevronRight size={18} /></button>
            <button className="action-row" onClick={() => setModal("note")}><Brain size={18} /> Add intel note <ChevronRight size={18} /></button>
            <button className="action-row" onClick={() => setModal("log")}><Timer size={18} /> Add restock log <ChevronRight size={18} /></button>
          </div>
        </GlassPanel>

        <GlassPanel className="p-5" delay={0.18}>
          <div className="mb-4 flex items-center justify-between">
            <div>
              <p className="section-kicker">Highest signal</p>
              <h2 className="section-title">Go list</h2>
            </div>
            <Flame className="text-amber-100/80" size={22} />
          </div>
          <div className="space-y-3">
            {hotStores.map((store) => (
              <button key={store.id} className="store-row" onClick={() => selectStore(store.id)}>
                <span>
                  <span className="block font-semibold text-white">{store.name}</span>
                  <span className="text-sm text-slate-400">{store.city}, {store.state}</span>
                </span>
                <span className="confidence">{store.confidence_score}%</span>
              </button>
            ))}
          </div>
        </GlassPanel>

        <GlassPanel className="p-5" delay={0.24}>
          <div className="mb-4 flex items-center justify-between">
            <div>
              <p className="section-kicker">Latest field logs</p>
              <h2 className="section-title">Timeline</h2>
            </div>
            <CalendarClock className="text-cyan-100/70" size={22} />
          </div>
          <Timeline logs={recentLogs.slice(0, 4)} stores={data.stores} />
        </GlassPanel>
      </div>
    </main>
  );
}

function StoreList({ data, selectStore }) {
  const [query, setQuery] = useState("");
  const filtered = data.stores.filter((store) =>
    `${store.name} ${store.city} ${store.state}`.toLowerCase().includes(query.toLowerCase())
  );

  return (
    <main className="mx-auto w-full max-w-7xl px-4 pb-8 pt-6">
      <GlassPanel className="p-5">
        <div className="mb-5 flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
          <div>
            <p className="section-kicker">Store list</p>
            <h1 className="text-3xl font-semibold text-white">Tracked locations</h1>
          </div>
          <label className="search-shell">
            <Search size={18} />
            <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search stores" />
          </label>
        </div>
        <div className="grid gap-3 lg:grid-cols-3">
          {filtered.map((store) => {
            const stats = getStats(store, data.restock_logs);
            const status = getStatus(store, data.restock_logs);
            return (
              <motion.button whileHover={{ y: -4 }} key={store.id} className="store-card" onClick={() => selectStore(store.id)}>
                <div className="flex items-start justify-between gap-4">
                  <div>
                    <p className="text-lg font-semibold text-white">{store.name}</p>
                    <p className="mt-1 text-sm text-slate-400">{store.address}</p>
                  </div>
                  <span className={`status-dot ${status.tone}`} />
                </div>
                <div className="mt-5 grid grid-cols-3 gap-2 text-left">
                  <MiniMetric label="Day" value={stats.commonDay} />
                  <MiniMetric label="Time" value={stats.avgTime} />
                  <MiniMetric label="Sellout" value={stats.avgSellout} />
                </div>
              </motion.button>
            );
          })}
        </div>
      </GlassPanel>
    </main>
  );
}

function MiniMetric({ label, value }) {
  return (
    <span className="rounded-2xl bg-white/[0.055] p-3">
      <span className="block text-[10px] uppercase tracking-[0.16em] text-slate-500">{label}</span>
      <span className="mt-1 block truncate text-sm font-semibold text-slate-100">{value}</span>
    </span>
  );
}

function InventoryView({ data, setModal, onDelete }) {
  const [query, setQuery] = useState("");
  const items = data.inventory_items || [];
  const filtered = items.filter((item) =>
    `${item.item} ${item.category} ${item.condition} ${item.location}`.toLowerCase().includes(query.toLowerCase())
  );
  const totalUnits = items.reduce((sum, item) => sum + Number(item.quantity || 0), 0);
  const totalCost = items.reduce((sum, item) => sum + Number(item.cost || 0) * Number(item.quantity || 0), 0);
  const totalValue = items.reduce((sum, item) => sum + Number(item.market_value || 0) * Number(item.quantity || 0), 0);

  return (
    <main className="mx-auto w-full max-w-7xl px-4 pb-8 pt-6">
      <GlassPanel className="p-5">
        <div className="mb-5 flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
          <div>
            <p className="section-kicker">Inventory</p>
            <h1 className="text-3xl font-semibold text-white">Owned stock</h1>
          </div>
          <div className="flex flex-col gap-3 sm:flex-row">
            <label className="search-shell">
              <Search size={18} />
              <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search inventory" />
            </label>
            <button className="small-button" onClick={() => setModal("inventory")}><Plus size={16} /> Add item</button>
          </div>
        </div>

        <div className="mb-4 grid gap-3 md:grid-cols-3">
          <StatTile icon={Package} label="Units" value={totalUnits} />
          <StatTile icon={Gauge} label="Cost basis" value={`$${totalCost.toFixed(0)}`} />
          <StatTile icon={Sparkles} label="Market value" value={`$${totalValue.toFixed(0)}`} />
        </div>

        <div className="grid gap-3 lg:grid-cols-3">
          {filtered.map((item) => (
            <article key={item.id} className="inventory-card">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <p className="text-lg font-semibold text-white">{item.item}</p>
                  <p className="mt-1 text-sm text-slate-400">{item.category} · {item.condition}</p>
                </div>
                <button className="icon-danger-button" onClick={() => onDelete("inventory", item)} title="Delete inventory item">
                  <Trash2 size={14} />
                </button>
              </div>
              <div className="mt-5 grid grid-cols-3 gap-2">
                <MiniMetric label="Qty" value={item.quantity || 0} />
                <MiniMetric label="Cost" value={`$${Number(item.cost || 0).toFixed(2)}`} />
                <MiniMetric label="Value" value={`$${Number(item.market_value || 0).toFixed(2)}`} />
              </div>
              <p className="mt-4 text-sm text-slate-400">{item.location || "No location set"}</p>
              {item.notes && <p className="mt-2 text-sm leading-6 text-slate-300">{item.notes}</p>}
            </article>
          ))}
        </div>
      </GlassPanel>
    </main>
  );
}

function StoreProfile({ storeId, data, setStoreId, setModal, onDelete }) {
  const store = data.stores.find((item) => item.id === storeId) || data.stores[0];
  const logs = getStoreLogs(store, data.restock_logs);
  const notes = getStoreNotes(store, data.intel_notes);
  const stats = getStats(store, data.restock_logs);

  return (
    <main className="mx-auto grid w-full max-w-7xl gap-4 px-4 pb-8 pt-6 lg:grid-cols-[0.86fr_1.14fr]">
      <div className="grid gap-4">
        <GlassPanel className="p-5">
          <button className="mb-4 text-sm font-semibold text-cyan-100/80" onClick={() => setStoreId(null)}>Back to stores</button>
          <div className="flex items-start justify-between gap-4">
            <div>
              <p className="section-kicker">Store profile</p>
              <h1 className="mt-2 text-3xl font-semibold text-white">{store.name}</h1>
              <p className="mt-2 text-slate-300">{store.address}, {store.city}, {store.state}</p>
            </div>
            <div className="flex flex-col items-end gap-2">
              <span className="confidence text-lg">{store.confidence_score}%</span>
              <button className="danger-button" onClick={() => onDelete("store", store)} title="Delete store">
                <Trash2 size={15} /> Delete
              </button>
            </div>
          </div>
          <div className="mt-5 h-56 overflow-hidden rounded-[22px] border border-white/10">
            <MapSurface data={{ ...data, stores: [store] }} selectStore={() => {}} compact />
          </div>
        </GlassPanel>

        <GlassPanel className="p-5">
          <p className="section-kicker">Auto stats</p>
          <div className="mt-4 grid gap-3">
            <StatTile icon={CalendarClock} label="Most common restock day" value={stats.commonDay} />
            <StatTile icon={Clock} label="Average restock time" value={stats.avgTime} />
            <StatTile icon={Timer} label="Average sellout speed" value={stats.avgSellout} />
          </div>
        </GlassPanel>
      </div>

      <div className="grid gap-4">
        <GlassPanel className="p-5">
          <div className="mb-4 flex items-center justify-between">
            <div>
              <p className="section-kicker">Main feature</p>
              <h2 className="section-title">Intel notes</h2>
            </div>
            <button className="small-button" onClick={() => setModal("note")}><Plus size={16} /> Add note</button>
          </div>
          <div className="space-y-3">
            {notes.map((note) => (
              <article key={note.id} className="intel-note">
                <div className="mb-2 flex items-center justify-between gap-3">
                  <span className={`source-pill ${sourceStyles[note.source_type]}`}>{note.source_type}</span>
                  <div className="flex items-center gap-2">
                    <span className="text-xs text-slate-500">{new Date(note.created_at).toLocaleDateString()}</span>
                    <button className="icon-danger-button" onClick={() => onDelete("note", note)} title="Delete intel note">
                      <Trash2 size={14} />
                    </button>
                  </div>
                </div>
                <p className="text-sm leading-6 text-slate-200">{note.note}</p>
              </article>
            ))}
          </div>
        </GlassPanel>

        <GlassPanel className="p-5">
          <div className="mb-4 flex items-center justify-between">
            <div>
              <p className="section-kicker">Chronological</p>
              <h2 className="section-title">Restock timeline</h2>
            </div>
            <button className="small-button" onClick={() => setModal("log")}><Plus size={16} /> Add log</button>
          </div>
          <Timeline logs={logs} stores={data.stores} detailed onDelete={onDelete} />
        </GlassPanel>
      </div>
    </main>
  );
}

function Timeline({ logs, stores, detailed = false, onDelete }) {
  return (
    <div className="space-y-3">
      {logs.map((log) => {
        const store = stores.find((item) => item.id === log.store_id);
        return (
          <article key={log.id} className="timeline-item">
            <div className="flex items-start justify-between gap-4">
              <div>
                <p className="font-semibold text-white">{log.stock_type}</p>
                <p className="mt-1 text-sm text-slate-400">{store?.name} · {formatDate(log.date)} · {log.time}</p>
              </div>
              <div className="flex items-center gap-2">
                <span className="rounded-full bg-white/10 px-3 py-1 text-xs font-semibold text-cyan-100">{log.sellout_speed_minutes || "?"} min</span>
                {onDelete && (
                  <button className="icon-danger-button" onClick={() => onDelete("log", log)} title="Delete restock log">
                    <Trash2 size={14} />
                  </button>
                )}
              </div>
            </div>
            {detailed && <p className="mt-3 text-sm leading-6 text-slate-300">{log.notes}</p>}
          </article>
        );
      })}
    </div>
  );
}

function MapView({ data, selectStore }) {
  return (
    <main className="mx-auto w-full max-w-7xl px-4 pb-8 pt-6">
      <GlassPanel className="relative h-[calc(100dvh-9rem)] min-h-[620px] overflow-hidden p-4">
        <MapSurface data={data} selectStore={selectStore} />
        <div className="pointer-events-none absolute left-6 top-6 max-w-sm">
          <p className="section-kicker">Live area map</p>
          <h1 className="mt-2 text-3xl font-semibold text-white">Pins, heat, and go/no-go signals.</h1>
        </div>
        <div className="absolute bottom-6 left-6 flex flex-wrap gap-2">
          <Legend color="bg-emerald-300" label="Recent restock" />
          <Legend color="bg-amber-300" label="Likely soon" />
          <Legend color="bg-rose-400" label="Inactive" />
          <Legend color="bg-cyan-300" label="Heatmap activity" />
        </div>
      </GlassPanel>
    </main>
  );
}

function Legend({ color, label }) {
  return <span className="rounded-full border border-white/10 bg-slate-950/35 px-3 py-2 text-xs font-semibold text-slate-200 backdrop-blur-xl"><span className={`mr-2 inline-block h-2 w-2 rounded-full ${color}`} />{label}</span>;
}

function MapSurface({ data, selectStore, compact = false }) {
  const [activePin, setActivePin] = useState(null);
  const apiKey = import.meta.env.VITE_GOOGLE_MAPS_API_KEY;

  const bounds = useMemo(() => {
    const lats = data.stores.map((store) => Number(store.latitude));
    const lngs = data.stores.map((store) => Number(store.longitude));
    return {
      minLat: Math.min(...lats) - 0.03,
      maxLat: Math.max(...lats) + 0.03,
      minLng: Math.min(...lngs) - 0.03,
      maxLng: Math.max(...lngs) + 0.03,
    };
  }, [data.stores]);

  const positionFor = (store) => {
    const x = ((Number(store.longitude) - bounds.minLng) / (bounds.maxLng - bounds.minLng)) * 82 + 9;
    const y = (1 - (Number(store.latitude) - bounds.minLat) / (bounds.maxLat - bounds.minLat)) * 72 + 14;
    return { left: `${x}%`, top: `${y}%` };
  };

  return (
    <div className={`map-shell ${compact ? "compact-map" : ""}`}>
      {apiKey ? (
        <GoogleMapCanvas data={data} selectStore={selectStore} compact={compact} apiKey={apiKey} />
      ) : (
        <>
          <FallbackGrid />
          <div className="heat-layer">
            {data.stores.map((store) => (
              <span key={`heat-${store.id}`} className="heat-spot" style={positionFor(store)} />
            ))}
          </div>
          {data.stores.map((store) => {
            const status = getStatus(store, data.restock_logs);
            const logs = getStoreLogs(store, data.restock_logs);
            const notes = getStoreNotes(store, data.intel_notes);
            return (
              <button
                key={store.id}
                className={`map-pin ${status.color}`}
                style={positionFor(store)}
                onClick={() => (compact ? selectStore(store.id) : setActivePin(activePin === store.id ? null : store.id))}
                title={store.name}
              >
                <MapPin size={compact ? 18 : 22} fill="currentColor" />
                {!compact && activePin === store.id && (
                  <motion.span initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} className="pin-card">
                    <strong>{store.name}</strong>
                    <span>Last restock: {logs[0] ? `${formatDate(logs[0].date)} at ${logs[0].time}` : "No logs yet"}</span>
                    <span>Sellout: {logs[0]?.sellout_speed_minutes || "?"} min</span>
                    <span>Notes: {notes[0]?.note || store.notes_summary}</span>
                    <span className="confidence self-start">{store.confidence_score}% confidence</span>
                  </motion.span>
                )}
              </button>
            );
          })}
        </>
      )}
      {!compact && (
        <div className="absolute right-4 top-4 rounded-full border border-white/10 bg-slate-950/35 px-3 py-2 text-xs font-semibold text-cyan-100 backdrop-blur-xl">
          <Layers className="mr-2 inline" size={14} /> Heatmap
        </div>
      )}
    </div>
  );
}

function GoogleMapCanvas({ data, selectStore, compact, apiKey }) {
  const mapRef = useRef(null);
  const [mapError, setMapError] = useState("");

  useEffect(() => {
    let heatmap;
    let cancelled = false;
    const markers = [];
    const listenerCleanups = [];

    async function renderMap() {
      try {
        if (configuredMapsKey !== apiKey) {
          setOptions({
            key: apiKey,
            v: "weekly",
            libraries: ["visualization"],
          });
          configuredMapsKey = apiKey;
        }

        const [{ Map: GoogleMap }, visualization] = await Promise.all([
          importLibrary("maps"),
          importLibrary("visualization"),
        ]);

        if (cancelled || !mapRef.current) return;

        const map = new GoogleMap(mapRef.current, {
          center: {
            lat: Number(data.stores[0]?.latitude || 27.97),
            lng: Number(data.stores[0]?.longitude || -82.48),
          },
          zoom: compact ? 12 : 11,
          clickableIcons: false,
          disableDefaultUI: compact,
          fullscreenControl: !compact,
          mapTypeControl: false,
          streetViewControl: false,
          styles: mapStyles,
        });

        const bounds = new google.maps.LatLngBounds();
        const infoWindow = new google.maps.InfoWindow();

        data.stores.forEach((store) => {
          const position = {
            lat: Number(store.latitude),
            lng: Number(store.longitude),
          };
          if (!Number.isFinite(position.lat) || !Number.isFinite(position.lng)) return;

          bounds.extend(position);
          const status = getStatus(store, data.restock_logs);
          const logs = getStoreLogs(store, data.restock_logs);
          const notes = getStoreNotes(store, data.intel_notes);
          const marker = new google.maps.Marker({
            map,
            position,
            title: store.name,
            icon: markerIcon(markerColors[status.color]),
          });

          markers.push(marker);
          const listener = marker.addListener("click", () => {
            if (compact) {
              selectStore(store.id);
              return;
            }
            infoWindow.setContent(`
              <div class="gm-info-card">
                <strong>${escapeHtml(store.name)}</strong>
                <span>Last restock: ${logs[0] ? `${formatDate(logs[0].date)} at ${logs[0].time}` : "No logs yet"}</span>
                <span>Sellout: ${logs[0]?.sellout_speed_minutes || "?"} min</span>
                <span>${escapeHtml(notes[0]?.note || store.notes_summary || "No intel notes yet.")}</span>
                <b>${escapeHtml(store.confidence_score)}% confidence</b>
              </div>
            `);
            infoWindow.open({ anchor: marker, map });
          });
          listenerCleanups.push(listener);
        });

        if (data.stores.length > 1) {
          map.fitBounds(bounds, compact ? 72 : 96);
        }

        heatmap = new visualization.HeatmapLayer({
          data: data.restock_logs
            .map((log) => data.stores.find((store) => store.id === log.store_id))
            .filter(Boolean)
            .map((store) => ({
              location: new google.maps.LatLng(Number(store.latitude), Number(store.longitude)),
              weight: Math.max(1, Number(store.confidence_score || 50) / 25),
            })),
          map,
          radius: compact ? 34 : 56,
          opacity: compact ? 0.34 : 0.5,
          gradient: [
            "rgba(34, 211, 238, 0)",
            "rgba(34, 211, 238, 0.32)",
            "rgba(16, 185, 129, 0.46)",
            "rgba(253, 230, 138, 0.58)",
          ],
        });

        setMapError("");
      } catch (error) {
        setMapError(error.message || "Google Maps could not load.");
      }
    }

    renderMap();

    return () => {
      cancelled = true;
      listenerCleanups.forEach((listener) => listener.remove());
      markers.forEach((marker) => marker.setMap(null));
      if (heatmap) heatmap.setMap(null);
    };
  }, [apiKey, compact, data, selectStore]);

  return (
    <>
      <div ref={mapRef} className="google-map-canvas" />
      {mapError && (
        <div className="absolute inset-0">
          <FallbackGrid />
          <div className="absolute left-4 top-4 max-w-sm rounded-2xl border border-amber-200/20 bg-amber-300/10 p-3 text-sm text-amber-100 backdrop-blur-xl">
            Google Maps did not load. Check `VITE_GOOGLE_MAPS_API_KEY`, billing, API restrictions, and Maps JavaScript API access.
          </div>
        </div>
      )}
    </>
  );
}

function FallbackGrid() {
  return (
    <div className="absolute inset-0 overflow-hidden bg-[radial-gradient(circle_at_30%_20%,rgba(34,211,238,0.16),transparent_30%),linear-gradient(135deg,#111827,#0f172a_48%,#172033)]">
      <div className="map-grid" />
      <div className="map-road road-a" />
      <div className="map-road road-b" />
      <div className="map-road road-c" />
    </div>
  );
}

function Modal({ type, data, selectedStoreId, onClose, onSaved }) {
  const defaultStoreId = selectedStoreId || data.stores[0]?.id || "";
  const [form, setForm] = useState({
    store_id: defaultStoreId,
    source_type: "employee",
    date: new Date().toISOString().slice(0, 10),
    time: new Date().toTimeString().slice(0, 5),
    confidence_score: 60,
  });
  const [saving, setSaving] = useState(false);

  const update = (key, value) => setForm((current) => ({ ...current, [key]: value }));

  const submit = async (event) => {
    event.preventDefault();
    setSaving(true);
    try {
      if (type === "store") await addStore(form);
      if (type === "note") await addIntelNote(form);
      if (type === "log") await addRestockLog(form);
      if (type === "inventory") await addInventoryItem(form);
      await onSaved();
      onClose();
    } finally {
      setSaving(false);
    }
  };

  return (
    <motion.div className="modal-backdrop" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
      <motion.form className="modal-card" initial={{ scale: 0.96, y: 18 }} animate={{ scale: 1, y: 0 }} exit={{ scale: 0.96, y: 18 }} onSubmit={submit}>
        <div className="mb-5 flex items-start justify-between gap-4">
          <div>
            <p className="section-kicker">Fast capture</p>
            <h2 className="text-2xl font-semibold text-white">{type === "store" ? "Add store" : type === "note" ? "Add intel note" : type === "inventory" ? "Add inventory item" : "Add restock log"}</h2>
          </div>
          <button type="button" className="icon-button" onClick={onClose} title="Close"><X size={18} /></button>
        </div>

        {type !== "store" && type !== "inventory" && (
          <Field label="Store">
            <select value={form.store_id} onChange={(event) => update("store_id", event.target.value)} required>
              {data.stores.map((store) => <option key={store.id} value={store.id}>{store.name}</option>)}
            </select>
          </Field>
        )}

        {type === "store" && (
          <div className="grid gap-3 sm:grid-cols-2">
            <Field label="Name"><input required value={form.name || ""} onChange={(event) => update("name", event.target.value)} placeholder="Target East Ridge" /></Field>
            <Field label="Address"><input required value={form.address || ""} onChange={(event) => update("address", event.target.value)} placeholder="2210 Meridian Ave" /></Field>
            <Field label="City"><input required value={form.city || ""} onChange={(event) => update("city", event.target.value)} placeholder="Tampa" /></Field>
            <Field label="State"><input required value={form.state || ""} onChange={(event) => update("state", event.target.value)} placeholder="FL" /></Field>
            <Field label="Latitude"><input required type="number" step="any" value={form.latitude || ""} onChange={(event) => update("latitude", event.target.value)} placeholder="27.9642" /></Field>
            <Field label="Longitude"><input required type="number" step="any" value={form.longitude || ""} onChange={(event) => update("longitude", event.target.value)} placeholder="-82.4526" /></Field>
            <Field label="Confidence"><input type="number" min="0" max="100" value={form.confidence_score} onChange={(event) => update("confidence_score", event.target.value)} /></Field>
            <Field label="Notes summary"><textarea value={form.notes_summary || ""} onChange={(event) => update("notes_summary", event.target.value)} placeholder="Vendor pattern, staff signal, quirks" /></Field>
          </div>
        )}

        {type === "note" && (
          <div className="grid gap-3">
            <Field label="Source">
              <select value={form.source_type} onChange={(event) => update("source_type", event.target.value)}>
                <option value="employee">Employee</option>
                <option value="observation">Observation</option>
                <option value="rumor">Rumor</option>
              </select>
            </Field>
            <Field label="Note"><textarea required rows="5" value={form.note || ""} onChange={(event) => update("note", event.target.value)} placeholder="What did you learn?" /></Field>
          </div>
        )}

        {type === "log" && (
          <div className="grid gap-3 sm:grid-cols-2">
            <Field label="Date"><input required type="date" value={form.date} onChange={(event) => update("date", event.target.value)} /></Field>
            <Field label="Time"><input required type="time" value={form.time} onChange={(event) => update("time", event.target.value)} /></Field>
            <Field label="Stock type"><input required value={form.stock_type || ""} onChange={(event) => update("stock_type", event.target.value)} placeholder="Booster bundles" /></Field>
            <Field label="Sellout minutes"><input type="number" min="0" value={form.sellout_speed_minutes || ""} onChange={(event) => update("sellout_speed_minutes", event.target.value)} placeholder="38" /></Field>
            <Field label="Notes"><textarea value={form.notes || ""} onChange={(event) => update("notes", event.target.value)} placeholder="Quantity, placement, vendor detail" /></Field>
          </div>
        )}

        {type === "inventory" && (
          <div className="grid gap-3 sm:grid-cols-2">
            <Field label="Item"><input required value={form.item || ""} onChange={(event) => update("item", event.target.value)} placeholder="Scarlet & Violet Booster Bundle" /></Field>
            <Field label="Category">
              <select value={form.category || "Booster bundle"} onChange={(event) => update("category", event.target.value)}>
                <option value="Booster box">Booster box</option>
                <option value="ETB">ETB</option>
                <option value="Booster bundle">Booster bundle</option>
                <option value="Sleeved boosters">Sleeved boosters</option>
                <option value="Collection box">Collection box</option>
                <option value="Single card">Single card</option>
                <option value="Other">Other</option>
              </select>
            </Field>
            <Field label="Quantity"><input required type="number" min="0" value={form.quantity || ""} onChange={(event) => update("quantity", event.target.value)} placeholder="4" /></Field>
            <Field label="Condition">
              <select value={form.condition || "Sealed"} onChange={(event) => update("condition", event.target.value)}>
                <option value="Sealed">Sealed</option>
                <option value="Mint">Mint</option>
                <option value="Near mint">Near mint</option>
                <option value="Played">Played</option>
                <option value="Damaged">Damaged</option>
              </select>
            </Field>
            <Field label="Location"><input value={form.location || ""} onChange={(event) => update("location", event.target.value)} placeholder="Shelf 2" /></Field>
            <Field label="Cost"><input type="number" min="0" step="0.01" value={form.cost || ""} onChange={(event) => update("cost", event.target.value)} placeholder="26.99" /></Field>
            <Field label="Market value"><input type="number" min="0" step="0.01" value={form.market_value || ""} onChange={(event) => update("market_value", event.target.value)} placeholder="34.99" /></Field>
            <Field label="Notes"><textarea value={form.notes || ""} onChange={(event) => update("notes", event.target.value)} placeholder="Hold, trade, sell plan" /></Field>
          </div>
        )}

        <button className="submit-button" disabled={saving}>{saving ? "Saving..." : "Save intel"}</button>
      </motion.form>
    </motion.div>
  );
}

function ConfirmDeleteModal({ target, onClose, onConfirm }) {
  const label =
    target?.type === "store"
      ? target.record.name
      : target?.type === "log"
        ? target.record.stock_type
        : target?.record.note;
  const [busy, setBusy] = useState(false);

  const confirm = async () => {
    setBusy(true);
    try {
      await onConfirm();
    } finally {
      setBusy(false);
    }
  };

  return (
    <motion.div className="modal-backdrop" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
      <motion.div className="confirm-card" initial={{ scale: 0.96, y: 18 }} animate={{ scale: 1, y: 0 }} exit={{ scale: 0.96, y: 18 }}>
        <div className="mb-5 flex items-start justify-between gap-4">
          <div>
            <p className="section-kicker">Confirm delete</p>
            <h2 className="mt-1 text-2xl font-semibold text-white">Delete this record?</h2>
          </div>
          <button type="button" className="icon-button" onClick={onClose} title="Close"><X size={18} /></button>
        </div>
        <p className="text-sm leading-6 text-slate-300">
          This will remove <span className="font-semibold text-white">{label}</span>
          {target?.type === "store" ? " and its related logs and notes" : ""}.
        </p>
        <div className="mt-5 grid grid-cols-2 gap-3">
          <button className="small-button" onClick={onClose}>Cancel</button>
          <button className="danger-submit-button" onClick={confirm} disabled={busy}>
            {busy ? "Deleting..." : "Delete"}
          </button>
        </div>
      </motion.div>
    </motion.div>
  );
}

function Field({ label, children }) {
  return (
    <label className="field">
      <span>{label}</span>
      {children}
    </label>
  );
}

function AuthGate({ onAuthenticated }) {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);

  const submit = async (event) => {
    event.preventDefault();
    setBusy(true);
    setMessage("");
    try {
      if (dataBackend === "notion") {
        const response = await fetch("/api/admin-login", {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ username, password }),
        });
        const data = await response.json();
        if (!response.ok) throw new Error(data.error || "Sign in failed.");
        sessionStorage.setItem("pokestock-admin-token", data.token);
      } else {
        if (username !== "admin" || password !== "ilovepokemon!") {
          throw new Error("Invalid admin credentials.");
        }
        sessionStorage.setItem("pokestock-admin-token", "local-admin");
      }
      onAuthenticated();
    } catch (error) {
      setMessage(error.message || "Sign in failed.");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="app-shell auth-screen">
      <div className="ambient ambient-a" />
      <div className="ambient ambient-b" />
      <motion.form
        className="auth-card glass-panel"
        initial={{ opacity: 0, y: 18 }}
        animate={{ opacity: 1, y: 0 }}
        onSubmit={submit}
      >
        <div className="brand-mark mb-5"><Shield size={20} /></div>
        <p className="section-kicker">Private access</p>
        <h1 className="mt-2 text-4xl font-semibold leading-tight text-white">POKÉSTOCK INTEL</h1>
        <p className="mt-3 text-sm leading-6 text-slate-300">
          Enter the admin credentials to view and manage stores, restock logs, maps, and intel notes.
        </p>

        <div className="mt-5 grid gap-3">
          <Field label="Name">
            <input required value={username} onChange={(event) => setUsername(event.target.value)} placeholder="admin" autoComplete="username" />
          </Field>
          <Field label="Password">
            <input required type="password" value={password} onChange={(event) => setPassword(event.target.value)} placeholder="Admin password" autoComplete="current-password" />
          </Field>
        </div>

        {message && <p className="mt-4 rounded-2xl border border-white/10 bg-white/[0.055] p-3 text-sm text-cyan-100">{message}</p>}
        <button className="submit-button" disabled={busy}>{busy ? "Checking access..." : "Enter dashboard"}</button>
      </motion.form>
    </div>
  );
}

function App() {
  const [data, setData] = useState(null);
  const [isAdmin, setIsAdmin] = useState(() => Boolean(sessionStorage.getItem("pokestock-admin-token")));
  const [activeTab, setActiveTab] = useState("dashboard");
  const [selectedStoreId, setSelectedStoreId] = useState(null);
  const [modal, setModal] = useState(null);
  const [deleteTarget, setDeleteTarget] = useState(null);
  const [error, setError] = useState("");

  const refresh = async () => {
    try {
      setData(await loadIntelData());
      setError("");
    } catch (err) {
      if (err.message?.includes("Admin login required")) {
        sessionStorage.removeItem("pokestock-admin-token");
        setIsAdmin(false);
        setData(null);
      }
      setError(err.message || "Unable to load intel data.");
    }
  };

  useEffect(() => {
    if (isAdmin) {
      refresh();
    }
  }, [isAdmin]);

  const selectStore = (id) => {
    setSelectedStoreId(id);
    setActiveTab("stores");
  };

  const signOut = () => {
    sessionStorage.removeItem("pokestock-admin-token");
    setIsAdmin(false);
    setData(null);
    setSelectedStoreId(null);
    setActiveTab("dashboard");
  };

  const requestDelete = (type, record) => setDeleteTarget({ type, record });

  const confirmDelete = async () => {
    if (!deleteTarget) return;
    const { type, record } = deleteTarget;
    const relatedIds =
      type === "store"
        ? [
            ...data.restock_logs.filter((log) => log.store_id === record.id).map((log) => log.id),
            ...data.intel_notes.filter((note) => note.store_id === record.id).map((note) => note.id),
          ]
        : [];
    try {
      await deleteRecord(type, record.id, relatedIds);
      setDeleteTarget(null);
      if (type === "store") setSelectedStoreId(null);
      await refresh();
    } catch (err) {
      setError(err.message || "Unable to delete record.");
      setDeleteTarget(null);
    }
  };

  if (!isAdmin) {
    return <AuthGate onAuthenticated={() => setIsAdmin(true)} />;
  }

  if (!data) {
    return <div className="min-h-dvh bg-slate-950 p-8 text-white">Loading POKÉSTOCK INTEL...</div>;
  }

  return (
    <div className="app-shell">
      <div className="ambient ambient-a" />
      <div className="ambient ambient-b" />
      <Header activeTab={activeTab} setActiveTab={setActiveTab} setModal={setModal} onSignOut={signOut} />
      {error && <div className="mx-auto mt-4 max-w-7xl px-4"><div className="glass-panel border-rose-300/30 p-3 text-sm text-rose-100">{error}</div></div>}
      <AnimatePresence mode="wait">
        {activeTab === "dashboard" && <motion.div key="dashboard" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}><Dashboard data={data} setActiveTab={setActiveTab} selectStore={selectStore} setModal={setModal} /></motion.div>}
        {activeTab === "stores" && (
          <motion.div key={`stores-${selectedStoreId || "list"}`} initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
            {selectedStoreId ? <StoreProfile storeId={selectedStoreId} data={data} setStoreId={setSelectedStoreId} setModal={setModal} onDelete={requestDelete} /> : <StoreList data={data} selectStore={selectStore} />}
          </motion.div>
        )}
        {activeTab === "inventory" && <motion.div key="inventory" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}><InventoryView data={data} setModal={setModal} onDelete={requestDelete} /></motion.div>}
        {activeTab === "map" && <motion.div key="map" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}><MapView data={data} selectStore={selectStore} /></motion.div>}
      </AnimatePresence>

      <nav className="mobile-tabs glass-panel">
        {tabs.map((tab) => {
          const Icon = tab.icon;
          return (
            <button key={tab.id} className={activeTab === tab.id ? "active" : ""} onClick={() => setActiveTab(tab.id)}>
              <Icon size={18} />
            </button>
          );
        })}
      </nav>

      <AnimatePresence>
        {modal && <Modal type={modal} data={data} selectedStoreId={selectedStoreId} onClose={() => setModal(null)} onSaved={refresh} />}
        {deleteTarget && <ConfirmDeleteModal target={deleteTarget} onClose={() => setDeleteTarget(null)} onConfirm={confirmDelete} />}
      </AnimatePresence>
    </div>
  );
}

createRoot(document.getElementById("root")).render(<App />);
