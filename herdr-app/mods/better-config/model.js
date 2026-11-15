// model.js: what a mod's settings are, whether a value fits, and what changed.
// No Herdr calls here, so the tests can run it as it is.
//
// A mod describes its settings in mods/<name>/mod.schema.json, a JSON Schema of its whole
// mod.json. Under properties.settings, each setting has the standard title, description,
// type, default, enum, minimum and maximum, plus format "duration" or "size", and x-step,
// x-unit and x-labels ({ "id": "Label" } for an enum). mod.json's own settings block holds
// only what the person changed. A key there the schema doesn't describe still shows.

const isObject = (v) => v !== null && typeof v === "object" && !Array.isArray(v);
export const TYPES = ["boolean", "number", "choice", "duration", "size", "text", "list"];
const DURATION = /^\s*\d+(?:\.\d+)?\s*(ms|s|m|h)\s*$/;
const SIZE = /^\s*\d+(?:\.\d+)?\s*(B|KB|MB)\s*$/i;

// { "a.b": 1 } from { a: { b: 1 } }. Lists are values, not branches.
export function flatten(obj, prefix = "", out = {}) {
  for (const [key, value] of Object.entries(isObject(obj) ? obj : {})) {
    const name = prefix ? `${prefix}.${key}` : key;
    if (isObject(value) && Object.keys(value).length) flatten(value, name, out);
    else out[name] = value;
  }
  return out;
}

export function getPath(obj, dotted) {
  return dotted.split(".").reduce((at, key) => (isObject(at) ? at[key] : undefined), obj);
}

// Sets a.b.c, making the objects on the way.
export function setPath(obj, dotted, value) {
  const keys = dotted.split(".");
  let at = obj;
  for (const key of keys.slice(0, -1)) {
    if (!isObject(at[key])) at[key] = {};
    at = at[key];
  }
  at[keys.at(-1)] = value;
  return obj;
}

// Removes a.b.c, and any object it leaves empty.
export function deletePath(obj, dotted) {
  const keys = dotted.split(".");
  const trail = [obj];
  for (const key of keys.slice(0, -1)) {
    const next = trail.at(-1)[key];
    if (!isObject(next)) return obj;
    trail.push(next);
  }
  delete trail.at(-1)[keys.at(-1)];
  for (let i = trail.length - 1; i > 0; i--)
    if (!Object.keys(trail[i]).length) delete trail[i - 1][keys[i - 1]];
  return obj;
}

export function equal(a, b) {
  return JSON.stringify(a) === JSON.stringify(b);
}

function guessType(value) {
  if (typeof value === "boolean") return "boolean";
  if (typeof value === "number") return "number";
  if (Array.isArray(value)) return "list";
  if (typeof value === "string" && DURATION.test(value)) return "duration";
  if (typeof value === "string" && SIZE.test(value)) return "size";
  return "text";
}

// "max_width" → "Max width"
export function humanize(key) {
  const words = key.split(".").at(-1).replaceAll("_", " ");
  return words.charAt(0).toUpperCase() + words.slice(1);
}

// A schema leaf's type in Better Config's words.
function typeOf(spec) {
  const types = [spec.type].flat();
  if (Array.isArray(spec.enum)) return "choice";
  if (spec.format === "duration" || spec.format === "size") return spec.format;
  if (types.includes("boolean")) return "boolean";
  if (types.includes("integer") || types.includes("number")) return "number";
  if (types.includes("array")) return "list";
  if (types.includes("string")) return "text";
  return guessType(spec.default);
}

// The leaves under a schema's settings, as [dotted key, spec].
function leaves(node, prefix = "", out = []) {
  for (const [key, spec] of Object.entries(isObject(node?.properties) ? node.properties : {})) {
    const name = prefix ? `${prefix}.${key}` : key;
    if (!isObject(spec)) continue;
    if (spec.type === "object" || isObject(spec.properties)) leaves(spec, name, out);
    else out.push([name, spec]);
  }
  return out;
}

// Every setting a mod has: those its mod.schema.json describes, in order, then any others
// in its settings block, with a guessed type.
export function fieldsOf(schema, settings) {
  const fields = leaves(schema?.properties?.settings).map(([key, spec]) => {
    const choices = Array.isArray(spec.enum)
      ? Object.fromEntries(spec.enum.map((v) => [v, isObject(spec["x-labels"]) && typeof spec["x-labels"][v] === "string" ? spec["x-labels"][v] : humanize(String(v))]))
      : null;
    return {
      key,
      described: true,
      title: typeof spec.title === "string" ? spec.title : humanize(key),
      description: typeof spec.description === "string" ? spec.description : "",
      type: typeOf(spec),
      default: spec.default,
      choices,
      min: typeof spec.minimum === "number" ? spec.minimum : null,
      max: typeof spec.maximum === "number" ? spec.maximum : null,
      step: typeof spec["x-step"] === "number" && spec["x-step"] > 0 ? spec["x-step"] : 1,
      unit: typeof spec["x-unit"] === "string" ? spec["x-unit"] : "",
    };
  });
  const known = new Set(fields.map((f) => f.key));
  for (const [key, value] of Object.entries(flatten(settings)))
    if (!known.has(key))
      fields.push({
        key,
        described: false,
        title: humanize(key),
        description: "",
        type: guessType(value),
        default: undefined,
        choices: null,
        min: null,
        max: null,
        step: 1,
        unit: "",
      });
  return fields;
}

// Why a value doesn't fit its field, or null.
export function problemWith(field, value) {
  if (value === undefined) return null;
  const { type } = field;
  if (type === "boolean") return typeof value === "boolean" ? null : "Should be on or off.";
  if (type === "number") {
    if (typeof value !== "number" || !Number.isFinite(value)) return "Should be a number.";
    if (field.min !== null && value < field.min) return `Should be at least ${field.min}.`;
    if (field.max !== null && value > field.max) return `Should be at most ${field.max}.`;
    return null;
  }
  if (type === "choice")
    return field.choices && !(value in field.choices)
      ? `Should be one of: ${Object.keys(field.choices).join(", ")}.`
      : null;
  if (type === "duration")
    return (typeof value === "number" && value > 0) || (typeof value === "string" && DURATION.test(value))
      ? null
      : 'Should be a time such as "450ms", "10s" or "5m".';
  if (type === "size")
    return (typeof value === "number" && value >= 0) || (typeof value === "string" && SIZE.test(value))
      ? null
      : 'Should be a size such as "60KB" or "2MB".';
  if (type === "list")
    return Array.isArray(value) && value.every((v) => typeof v === "string")
      ? null
      : "Should be a list of words.";
  return typeof value === "string" ? null : "Should be text.";
}

// What a typed value means for a field: { value } or { error }.
export function parseInput(field, text) {
  const trimmed = text.trim();
  let value = trimmed;
  if (field.type === "number") value = trimmed === "" ? NaN : Number(trimmed);
  else if (field.type === "list") value = trimmed ? trimmed.split(",").map((s) => s.trim()).filter(Boolean) : [];
  else if ((field.type === "duration" || field.type === "size") && /^\d+$/.test(trimmed)) value = Number(trimmed);
  const error = problemWith(field, value);
  return error ? { error } : { value };
}

// How a value reads in a text box.
export function showValue(value) {
  if (value === undefined || value === null) return "";
  return Array.isArray(value) ? value.join(", ") : String(value);
}

// Set by the person: present and not the default. Without a default, anything present counts.
export function isChanged(field, value) {
  if (value === undefined) return false;
  return field.default === undefined ? false : !equal(value, field.default);
}

// The person's own values: what Better Config keeps a copy of.
export function changedValues(fields, settings) {
  const out = {};
  for (const field of fields) {
    const value = getPath(settings, field.key);
    if (isChanged(field, value)) out[field.key] = value;
  }
  return out;
}

// The kept values an update took away: gone, or back at the default. Another value is the
// person editing by hand. Without a described default, only a new version can tell.
export function lostValues(kept, fields, manifest) {
  if (!isObject(kept?.values)) return {};
  fields = new Map(fields.map((f) => [f.key, f]));
  const updated = kept.version !== (manifest?.version ?? null);
  const lost = {};
  for (const [key, value] of Object.entries(kept.values)) {
    const now = getPath(manifest?.settings, key);
    if (equal(now, value)) continue;
    const fallback = fields.get(key)?.default;
    if (now === undefined || (fallback !== undefined && equal(now, fallback)) || updated) lost[key] = value;
  }
  return lost;
}

// The manifest's text with one setting changed. Undefined, or the default, removes it,
// and an empty settings block goes too.
export function editManifest(raw, field, value) {
  const manifest = JSON.parse(raw);
  if (!isObject(manifest.settings)) manifest.settings = {};
  if (value === undefined || equal(value, field.default)) deletePath(manifest.settings, field.key);
  else setPath(manifest.settings, field.key, value);
  if (!Object.keys(manifest.settings).length) delete manifest.settings;
  return `${JSON.stringify(manifest, null, 2)}\n`;
}
