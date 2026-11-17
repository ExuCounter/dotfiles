// GitLab access in the tab row, as better-changes last saw it per host: a check when glab and
// git over SSH both get in, a cross when the SSO session expired or glab is logged out. A
// click logs in (the SSO page in the browser, or glab in a tab) and asks for a fresh look.
import { View, div, svg } from "gpui-kit";
import { h_flex } from "gpui-base";
import { run, theme, shared, setShared, exec } from "herdr";

const ACCESS = "better-changes.gitlab-access";
const ORANGE = "#fc6d26";

function gitlabAccess() {
  const hosts = Object.entries(shared(ACCESS) ?? {});
  if (!hosts.length) return null;
  for (const [host, state] of hosts) {
    if (state.git?.kind === "sso") return { host, problem: state.git };
    if (state.glab) return { host, problem: state.glab };
  }
  return { host: hosts[0][0], problem: null };
}

export default class GitlabStatus extends View {
  render() {
    const t = theme();
    const access = gitlabAccess();
    const root = h_flex().size_full().items_center().justify_center().bg(t.chrome).border_b(1).border_color(t.border);
    if (!access) return root;
    const { host, problem } = access;
    return root.child(
      h_flex().id("gitlab-access").h(26).px(8).gap(4).items_center().rounded(6)
        .bg(problem ? `${t.ansi1}22` : t.chrome)
        .hover((s) => s.bg(t.hover))
        .tooltip(problem?.kind === "sso" ? "GitLab SSO expired: click to log in"
          : problem ? "glab is logged out: click to log in" : `GitLab: logged in to ${host}`)
        .on_click(() => {
          if (problem?.kind === "sso") exec("open", [problem.url]);
          else if (problem) run("tab.new", { name: "glab login", argv: ["glab", "auth", "login", "--hostname", host] });
          const all = shared(ACCESS) ?? {};
          setShared(ACCESS, { ...all, [host]: { ...all[host], at: 0 } });
        })
        .child(svg("mods/gitlab-status/gitlab.svg").size(15).text_color(ORANGE))
        .child(div().text_size(12).font_semibold().text_color(problem ? t.ansi1 : t.ansi2).child(problem ? "✕" : "✓")),
    );
  }
}
