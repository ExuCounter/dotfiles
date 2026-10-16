#!/usr/bin/env python3
"""Stand-in page for one step that happens in an external app.

Serves a page labelled as a stand-in. Its button sends the request named in the
config, with {placeholders} filled from the page's query string, and shows the
real status and body on screen. It goes straight to the target, ignoring any
proxy, shows redirects without following them, and masks the header values it
sends wherever they appear, along with the page parameters that fill them.

Usage: standin.py <config.json> [--port 4100]

Config (the request must target localhost or 127.0.0.1):
  {
    "service": "Payments provider",
    "title": "Customer pays the invoice",
    "button": "Pay",
    "request": {
      "method": "POST",
      "url": "http://localhost:<app port>/api/<path>/{invoice_id}",
      "headers": {"authorization": "Bearer <the run's throwaway token>"},
      "body": {"amount": "{amount}"}
    },
    "ok": "The app accepted the payment",
    "fail": "The app rejected the payment"
  }

Open http://localhost:<port>/?invoice_id=123&amount=10.50 to fill the placeholders.
"""
import argparse
import html
import http.server
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

PLACEHOLDER = re.compile(r"\{(\w+)\}")
LOCAL_HOSTS = {"localhost", "127.0.0.1"}


class MissingPlaceholder(Exception):
    pass


class RequestFailed(Exception):
    pass

PAGE = """<!doctype html><html><head><meta charset="utf-8"><title>{title} (stand-in)</title>
<style>
body{{margin:0;font:17px -apple-system,Helvetica,Arial,sans-serif;background:#f3f1fa;color:#1f1d2b}}
.top{{background:#4c1d95;color:#fff;padding:16px 32px;font-weight:600;font-size:19px}}
.note{{background:#fff4d6;color:#6b4e00;padding:12px 32px;font-size:15px;border-bottom:1px solid #f0dca0}}
.card{{max-width:760px;margin:40px auto;background:#fff;border-radius:10px;padding:32px;box-shadow:0 2px 12px rgba(0,0,0,.08)}}
h1{{font-size:24px;margin:0 0 18px}}
dl{{display:grid;grid-template-columns:max-content 1fr;gap:6px 16px;margin:0 0 24px;font-size:15px}}
dt{{color:#666}} dd{{margin:0;font-family:Menlo,monospace;word-break:break-all}}
button{{background:#4c1d95;color:#fff;border:0;border-radius:6px;padding:13px 24px;font-size:17px;cursor:pointer}}
#result{{margin-top:26px;display:none;border-radius:8px;padding:18px;font-family:Menlo,monospace;font-size:16px;white-space:pre-wrap;word-break:break-all}}
.ok{{background:#e7f6ec;border:1px solid #86c99b;color:#14532d}}
.bad{{background:#fdecec;border:1px solid #e9a3a3;color:#7f1d1d}}
.verdict{{font-family:-apple-system,Helvetica,Arial,sans-serif;font-weight:700;font-size:19px;margin-bottom:10px}}
</style></head><body>
<div class="top">Stand-in · {service}: {title}</div>
<div class="note">Stand-in for {service}, which does not run locally. The button sends the same request {service} sends and shows the real response.</div>
<div class="card">
<h1>{title}</h1>
<dl id="params"></dl>
<button id="send">{button}</button>
<div id="result"></div>
</div>
<script>
const query = Object.fromEntries(new URLSearchParams(location.search));
const hidden = {hidden};
const params = document.getElementById("params");
for (const [name, value] of Object.entries(query)) {{
  if (hidden.includes(name)) continue;
  const term = document.createElement("dt"); term.textContent = name;
  const detail = document.createElement("dd"); detail.textContent = value;
  params.append(term, detail);
}}
function show(accepted, verdictText, detailText) {{
  const result = document.getElementById("result");
  result.className = accepted ? "ok" : "bad";
  result.style.display = "block";
  result.innerHTML = "";
  const verdict = document.createElement("div");
  verdict.className = "verdict";
  verdict.textContent = verdictText;
  result.append(verdict, document.createTextNode(detailText));
}}
document.getElementById("send").addEventListener("click", async () => {{
  try {{
    const response = await fetch("/send", {{method: "POST", headers: {{"content-type": "application/json"}}, body: JSON.stringify(query)}});
    const sent = await response.json();
    const accepted = sent.status >= 200 && sent.status < 300;
    const verdict = sent.error ? sent.error : sent.location ? "Redirected to " + sent.location : (accepted ? {ok} : {fail});
    show(accepted, verdict, sent.method + " " + sent.path + " → HTTP " + sent.status + "\\n" + sent.body);
  }} catch (error) {{
    show(false, "The stand-in itself failed", String(error));
  }}
}});
</script></body></html>"""


class ShowRedirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}), ShowRedirects)


def script_literal(text):
    return json.dumps(text).replace("<", "\\u003c")


def fill(value, params, quote):
    if isinstance(value, str):
        def substitute(match):
            name = match.group(1)
            if name not in params:
                raise MissingPlaceholder(name)
            return quote(str(params[name]))
        return PLACEHOLDER.sub(substitute, value)
    if isinstance(value, dict):
        return {key: fill(item, params, quote) for key, item in value.items()}
    if isinstance(value, list):
        return [fill(item, params, quote) for item in value]
    return value


def secrets_in(header_values):
    secrets = set()
    for value in header_values:
        secrets.add(value)
        secrets.update(part for part in value.split() if len(part) >= 8)
    return sorted((secret for secret in secrets if len(secret) >= 4), key=len, reverse=True)


def mask(text, secrets):
    for secret in secrets:
        text = text.replace(secret, "[masked]")
    return text


def header_placeholders(request_config):
    return sorted(set(PLACEHOLDER.findall(json.dumps(request_config.get("headers", {})))))


def send(request_config, params):
    url = fill(request_config["url"], params, lambda text: urllib.parse.quote(text, safe=""))
    headers = {"content-type": "application/json", **fill(request_config.get("headers", {}), params, str)}
    body = request_config.get("body")
    data = None if body is None else json.dumps(fill(body, params, str)).encode()
    method = request_config.get("method", "POST")
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    secrets = secrets_in(value for name, value in headers.items() if name.lower() != "content-type")
    try:
        with OPENER.open(request, timeout=60) as response:
            status, raw, location = response.status, response.read(), None
    except urllib.error.HTTPError as error:
        status, raw, location = error.code, error.read(), error.headers.get("location")
    except Exception as error:
        raise RequestFailed(mask(str(error), secrets)) from None
    text = raw.decode(errors="replace")
    try:
        text = json.dumps(json.loads(text), indent=2, ensure_ascii=False)
    except ValueError:
        pass
    if location:
        text = f"Location: {location}\n\n{text}"
        location = mask(location, secrets)
    return {"method": method, "path": urllib.parse.urlsplit(url).path, "status": status, "location": location, "body": mask(text, secrets)}


def check_config(config):
    for key in ("service", "title", "button", "ok", "fail"):
        if not isinstance(config.get(key), str):
            sys.exit(f"standin.py: config needs a string \"{key}\"")
    request = config.get("request")
    if not isinstance(request, dict) or not isinstance(request.get("url"), str):
        sys.exit("standin.py: config needs request.url")
    target = urllib.parse.urlsplit(request["url"])
    if target.scheme not in ("http", "https") or target.hostname not in LOCAL_HOSTS or "{" in target.netloc:
        sys.exit(f"standin.py: request.url must point at localhost or 127.0.0.1, not {target.netloc or request['url']}")


def handler_for(config, port):
    page = PAGE.format(
        service=html.escape(config["service"]),
        title=html.escape(config["title"]),
        button=html.escape(config["button"]),
        ok=script_literal(config["ok"]),
        fail=script_literal(config["fail"]),
        hidden=script_literal(header_placeholders(config["request"])),
    ).encode()
    own_hosts = {f"{host}:{port}" for host in LOCAL_HOSTS}
    own_origins = {f"http://{host}" for host in own_hosts}

    class StandIn(http.server.BaseHTTPRequestHandler):
        def reply(self, status, content_type, body):
            self.send_response(status)
            self.send_header("content-type", content_type)
            self.end_headers()
            self.wfile.write(body)

        def from_this_page(self):
            origin = self.headers.get("origin")
            return self.headers.get("host") in own_hosts and (origin is None or origin in own_origins)

        def do_GET(self):
            if not self.from_this_page():
                return self.reply(403, "text/plain", b"forbidden")
            self.reply(200, "text/html; charset=utf-8", page)

        def do_POST(self):
            if not self.from_this_page():
                return self.reply(403, "text/plain", b"forbidden")
            if not (self.headers.get("content-type") or "").startswith("application/json"):
                return self.reply(415, "text/plain", b"application/json only")
            try:
                params = json.loads(self.rfile.read(int(self.headers.get("content-length", 0))) or b"{}")
                sent = send(config["request"], params)
            except MissingPlaceholder as missing:
                sent = {"method": "-", "path": "-", "status": 0, "body": "", "error": f"Missing ?{missing.args[0]}= in the page URL"}
            except RequestFailed as error:
                sent = {"method": "-", "path": "-", "status": 0, "body": str(error), "error": "Request failed"}
            except Exception as error:
                sent = {"method": "-", "path": "-", "status": 0, "body": type(error).__name__, "error": "Request failed"}
            self.reply(200, "application/json", json.dumps(sent).encode())

        def log_message(self, *args):
            pass

    return StandIn


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("config")
    parser.add_argument("--port", type=int, default=4100)
    arguments = parser.parse_args()
    with open(arguments.config) as config_file:
        config = json.load(config_file)
    check_config(config)
    http.server.ThreadingHTTPServer(("127.0.0.1", arguments.port), handler_for(config, arguments.port)).serve_forever()


if __name__ == "__main__":
    main()
