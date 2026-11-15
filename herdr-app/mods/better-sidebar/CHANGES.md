# Changes in this copy

Better Sidebar 3.3.0 from [munza/herdr-mods](https://github.com/munza/herdr-mods) (Apache-2.0),
with GitLab merge requests through `glab`. 3.4.0 adds, after the Orca layout's copy in
[VladTemp27/herdr-orca](https://github.com/VladTemp27/herdr-orca) (Apache-2.0):

- `git/pr-status.js`: a PR's checks or MR's pipeline as running, failed, passed or stopped
  (`pipelineState`, `pipelineAppearance`); an MR GitLab says needs a rebase shows "Needs rebase".
- `views/spaces.js`: the pipeline icon beside the PR badge, a plug icon when the checkout has
  live ports (shared `live-ports`, from the live-ports mod), and the hover card.
- `views/card.js`: the hover card, a window beside the row: the PR or MR with its pipeline,
  copy and open buttons, and the live ports. Shared `better-sidebar.hover` keeps it open while
  the pointer is on the row or the card.
- `icons/copy.svg`, `icons/external.svg`, `icons/plug.svg` from Orca.
