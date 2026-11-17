// A small line-at-a-time highlighter for diff rows: comments, strings, numbers, keywords.
// Not a parser: a block comment or string that spans lines is only coloured on the lines that
// show its delimiters. Good enough to read a diff, cheap enough to run on every visible row.

const KEYWORDS = new Set((
  // Go, JS/TS, Python, Java/Kotlin, Rust, SQL (lower-case; SQL matched case-insensitively)
  "func package import return if else for range switch case default break continue go defer select chan map struct interface type var const nil " +
  "function let new this class extends super export from async await yield try catch finally throw typeof instanceof in of delete void null undefined true false " +
  "def lambda elif pass raise with as is not and or None True False self yield global nonlocal " +
  "public private protected static final abstract implements throws enum record val fun when object override " +
  "fn mut impl trait pub use mod crate where match loop unsafe ref " +
  "select insert update delete into values from where join left right inner outer on group by order having limit offset create table alter drop index primary key foreign references not null default unique begin commit rollback set as and or case when then end"
).split(/\s+/));

const COMMENT = {
  py: "#", rb: "#", sh: "#", bash: "#", zsh: "#", yml: "#", yaml: "#", toml: "#", conf: "#", r: "#", pl: "#", tf: "#", dockerfile: "#", makefile: "#",
  sql: "--", lua: "--", hs: "--",
};

export function langOf(path) {
  const name = (path ?? "").split("/").pop().toLowerCase();
  if (name === "dockerfile" || name === "makefile") return name;
  return name.includes(".") ? name.split(".").pop() : "";
}

// -> [{ text, kind }] with kind "kw" | "str" | "com" | "num" | null
export function tokens(text, lang) {
  if (!text || lang === "md" || lang === "txt" || lang === "") return [{ text: text || " ", kind: null }];
  const line = COMMENT[lang] ?? "//";
  const sql = lang === "sql";
  const out = [];
  let plain = "";
  const flush = () => { if (plain) { out.push({ text: plain, kind: null }); plain = ""; } };
  let i = 0;
  while (i < text.length) {
    const c = text[i];
    if (text.startsWith(line, i) || text.startsWith("/*", i)) { flush(); out.push({ text: text.slice(i), kind: "com" }); return out; }
    if (c === '"' || c === "'" || c === "`") {
      let j = i + 1;
      while (j < text.length && text[j] !== c) j += text[j] === "\\" ? 2 : 1;
      flush(); out.push({ text: text.slice(i, j + 1), kind: "str" }); i = j + 1; continue;
    }
    if (/[0-9]/.test(c) && !/[A-Za-z0-9_]/.test(text[i - 1] ?? "")) {
      const m = /^[0-9][0-9_.xXa-fA-F]*/.exec(text.slice(i))[0];
      flush(); out.push({ text: m, kind: "num" }); i += m.length; continue;
    }
    if (/[A-Za-z_]/.test(c) && !/[A-Za-z0-9_]/.test(text[i - 1] ?? "")) {
      const m = /^[A-Za-z_][A-Za-z0-9_]*/.exec(text.slice(i))[0];
      if (KEYWORDS.has(sql ? m.toLowerCase() : m)) { flush(); out.push({ text: m, kind: "kw" }); }
      else plain += m;
      i += m.length; continue;
    }
    plain += c; i++;
  }
  flush();
  return out;
}
