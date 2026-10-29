# Opening a document for review

I review documents and specs in hunk, not an editor. To open one for review, print it
as a markdown link, `[name.md](file:///abs/path.md)`, outside backticks and code blocks,
with a space, `(`, `)` and `%` in the path written `%20`, `%28`, `%29` and `%25`:
Ctrl+click opens it in hunk in a new herdr tab, and its `S` key makes my notes the
session's next message. A bare `file://` URL, or one in a code span, is plain text to
herdr, and Ctrl+click on it does nothing. Never run `zed` or `$EDITOR` for this.
