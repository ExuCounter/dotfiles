import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

export const HERE = dirname(fileURLToPath(import.meta.url));
export const MOD = join(HERE, "..");
export const NOW = 1793779000;

// A fixture as the helper prints it: one compact JSON line.
export function read(name) {
  return JSON.stringify(JSON.parse(readFileSync(join(HERE, "fixtures", name), "utf8")));
}

export function claudeReply(rateLimits, extra = {}) {
  return JSON.stringify({
    type: "control_response",
    response: { subtype: "success", request_id: "t", response: { subscription_type: "max", rate_limits: rateLimits, ...extra } },
  });
}
