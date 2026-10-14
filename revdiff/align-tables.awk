# Pads the cells of Markdown pipe tables so their columns line up in a
# monospaced view. Only spaces and separator dashes change inside a line: the
# line count and every line's place stay the same, so revdiff's line-numbered
# notes still point at the same lines. Tables in fenced code are left alone.
# Run with LC_ALL=C; width counts UTF-8 characters, not bytes.

function width(s,   t) { t = s; gsub(/[\200-\277]/, "", t); return length(t) }
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function is_sep(s) {
  return s ~ /\|/ && s ~ /^[ \t]*\|?[ \t]*:?-+:?[ \t]*(\|[ \t]*:?-+:?[ \t]*)*\|?[ \t]*$/
}
function is_row(s) { return s ~ /\|/ && s !~ /^[ \t]*$/ }

# Stores line as a table row: cells split on pipes not escaped by a backslash,
# joined with \001 (review.sh rejects control characters, so it never occurs).
function add_row(line,   i, c, cur, n, body, s) {
  nrows++
  match(line, /^[ \t]*/); ind_[nrows] = substr(line, 1, RLENGTH)
  body = substr(line, RLENGTH + 1)
  lead_[nrows] = (substr(body, 1, 1) == "|"); if (lead_[nrows]) body = substr(body, 2)
  trail_[nrows] = 0
  if (body ~ /\|[ \t]*$/ && body !~ /\\\|[ \t]*$/) { trail_[nrows] = 1; sub(/\|[ \t]*$/, "", body) }
  n = 0; cur = ""; s = ""
  for (i = 1; i <= length(body); i++) {
    c = substr(body, i, 1)
    if (c == "\\") { cur = cur c substr(body, i + 1, 1); i++; continue }
    if (c == "|") { s = s trim(cur) "\001"; cur = ""; continue }
    cur = cur c
  }
  rows[nrows] = s trim(cur)
}

function flush(   r, i, n, w, line, cell, left, right, len, parts) {
  for (r = 1; r <= nrows; r++) {
    if (r == 2) continue
    n = split(rows[r], parts, "\001")
    for (i = 1; i <= n; i++) { w = width(parts[i]); if (w > colw[i]) colw[i] = w }
  }
  # A separator cell needs a dash plus its colons.
  n = split(rows[2], parts, "\001")
  for (i = 1; i <= n; i++) {
    w = 1 + (substr(parts[i], 1, 1) == ":") + (substr(parts[i], length(parts[i]), 1) == ":")
    if (w > colw[i]) colw[i] = w
  }
  for (r = 1; r <= nrows; r++) {
    n = split(rows[r], parts, "\001")
    line = ""
    for (i = 1; i <= n; i++) {
      cell = parts[i]
      if (r == 2) {
        left = (substr(cell, 1, 1) == ":"); right = (substr(cell, length(cell), 1) == ":")
        cell = sprintf("%*s", colw[i], ""); gsub(/ /, "-", cell)
        if (left) cell = ":" substr(cell, 2)
        if (right) cell = substr(cell, 1, length(cell) - 1) ":"
      } else {
        cell = cell sprintf("%*s", colw[i] - width(cell), "")
      }
      line = line (i > 1 ? " | " : (lead_[r] ? "| " : "")) cell
    }
    if (trail_[r]) line = line " |"
    out[++nout] = ind_[r] line
  }
  for (r = 1; r <= nrows; r++) delete rows[r]
  for (i in colw) delete colw[i]
  nrows = 0
}

{ lines[NR] = $0 }
END {
  fence = ""
  for (k = 1; k <= NR; k++) {
    line = lines[k]
    if (fence != "") {
      out[++nout] = line
      if (match(line, /^ {0,3}(```+|~~~+)[ \t]*$/)) {
        t = line; gsub(/[ \t]/, "", t)
        if (substr(t, 1, 1) == substr(fence, 1, 1) && length(t) >= length(fence)) fence = ""
      }
      continue
    }
    if (match(line, /^ {0,3}(```+|~~~+)/)) {
      t = substr(line, 1, RLENGTH); gsub(/[ \t]/, "", t); fence = t
      out[++nout] = line; continue
    }
    # A table is a header row, a separator row, then rows up to a line with no pipe.
    if (is_row(line) && !is_sep(line) && k < NR && is_sep(lines[k + 1])) {
      add_row(line); add_row(lines[++k])
      while (k < NR && is_row(lines[k + 1])) add_row(lines[++k])
      flush(); continue
    }
    out[++nout] = line
  }
  for (k = 1; k <= nout; k++) print out[k]
}
