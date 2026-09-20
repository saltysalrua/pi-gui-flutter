// Public Pi extension API only. No session-file reads/writes or Agent reimplementation.
export const historyCommand = "pi-gui-history";
const fail = (code) => { throw Object.assign(new Error(code), { code }); };
export function editorContent(entry) {
  const content = entry?.type === "custom_message" ? entry.content : entry?.message?.content;
  return {
    editorText: typeof content === "string" ? content : (content ?? []).filter((b) => b.type === "text").map((b) => b.text).join(""),
    images: Array.isArray(content) ? content.filter((b) => b.type === "image") : [],
  };
}
export async function historyAction(request, ctx, pi) {
  const sm = ctx.sessionManager;
  if (request.sessionId !== sm.getSessionId()) fail("HISTORY_STALE");
  const entry = sm.getEntry(request.entryId);
  if (!entry) fail("HISTORY_ENTRY_MISSING");
  if (request.operation === "entry") return { entry };
  if (!ctx.isIdle() || ctx.hasPendingMessages()) fail("HISTORY_BUSY");
  if (request.leafId !== sm.getLeafId()) fail("HISTORY_STALE");
  if (request.operation === "label") {
    if (typeof request.label !== "string" || request.label.length > 500) fail("HISTORY_INVALID");
    pi.setLabel(entry.id, request.label.trim() || undefined);
    return { cancelled: false };
  }
  if (request.operation !== "navigate") fail("HISTORY_INVALID");
  if (request.customInstructions != null && typeof request.customInstructions !== "string") fail("HISTORY_INVALID");
  const unchanged = entry.id === sm.getLeafId();
  const restore = !unchanged &&
    ((entry.type === "message" && entry.message.role === "user") || entry.type === "custom_message");
  const draft = restore ? editorContent(entry) : { editorText: "", images: [] };
  const result = await ctx.navigateTree(entry.id, {
    summarize: request.summarize === true,
    customInstructions: request.customInstructions,
    replaceInstructions: request.replaceInstructions === true,
  });
  return { cancelled: result.cancelled, ...(result.cancelled ? {} : { ...draft, unchanged }) };
}
export default function registerHistory(pi) {
  pi.on("session_shutdown", (event, ctx) => {
    if (["fork", "new", "resume"].includes(event.reason)) {
      ctx.ui.setStatus("pi-gui-history:reset", "reset");
    }
  });
  pi.registerCommand(historyCommand, {
    description: "Pi GUI history bridge",
    handler: async (args, ctx) => {
      let request;
      try { request = JSON.parse(args); } catch { return; }
      if (typeof request?.id !== "string" || !request.id.startsWith("adapter-history-")) return;
      let response;
      try {
        response = { success: true, data: await historyAction(request, ctx, pi) };
      } catch (error) {
        response = { success: false, error: error.code?.startsWith("HISTORY_") ? error.code : "HISTORY_FAILED" };
      }
      // Pi owns stdout in RPC mode. Use its public UI transport; PiChild
      // consumes only this private bridge namespace before normal UI routing.
      ctx.ui.setStatus(`pi-gui-history:${request.id}`, JSON.stringify({ type: "response", id: request.id, command: "gui_history_bridge", ...response }));
    },
  });
}
