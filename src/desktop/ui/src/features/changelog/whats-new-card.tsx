import { Sparkles, X } from "lucide-react";

import { Tooltip } from "~/components/ui/tooltip";
import { cn } from "~/lib/cn";

import { latestRelease } from "./changelog-mock";
import { ReleaseArt } from "./release-art";

const fallbackArt = { from: "#18181b", to: "#6366f1", caption: "" };

/**
 * The release card above the sidebar footer. It keeps a fixed width so the
 * sidebar's width transition clips it rather than reflowing it, and it
 * folds away in short windows where the sections need the height.
 */
export function WhatsNewCard({
  visible,
  fresh,
  onOpen,
  onDismiss,
}: {
  visible: boolean;
  fresh: boolean;
  onOpen: () => void;
  onDismiss: () => void;
}) {
  // Mock: the release comes from the placeholder changelog until there is a release feed.
  const release = latestRelease;
  return (
    <div
      inert={!visible}
      aria-hidden={!visible}
      className={cn(
        "grid transition-[grid-template-rows] duration-200 ease-out [@media(max-height:640px)]:hidden",
        visible ? "grid-rows-[1fr]" : "grid-rows-[0fr]",
      )}
    >
      <div className="min-h-0 overflow-hidden">
        <div
          className={cn(
            "w-[232px] px-2 pt-1 pb-3 transition-[opacity,transform] duration-200 ease-out",
            visible
              ? "translate-y-0 scale-100 opacity-100"
              : "translate-y-1.5 scale-[0.97] opacity-0",
          )}
        >
          <div className="group relative pt-2">
            {/* Two earlier releases peeking out behind the card. */}
            <div
              aria-hidden
              className="absolute inset-x-3.5 top-0 h-6 rounded-[10px] border border-hairline bg-card opacity-60 transition-transform duration-200 ease-out group-hover:-translate-y-0.5"
            />
            <div
              aria-hidden
              className="absolute inset-x-[7px] top-1 h-6 rounded-[10px] border border-hairline bg-card opacity-85 shadow-card transition-transform duration-200 ease-out group-hover:-translate-y-px"
            />
            <article className="relative overflow-hidden rounded-[10px] border border-hairline bg-card shadow-[0_1px_2px_rgb(9_9_11/0.06),0_8px_20px_-12px_rgb(9_9_11/0.25)] transition-[border-color,box-shadow,transform] duration-200 ease-out group-hover:-translate-y-px group-hover:border-line-strong group-hover:shadow-[0_1px_2px_rgb(9_9_11/0.06),0_14px_28px_-14px_rgb(9_9_11/0.35)]">
              <div className="relative m-1 h-14 overflow-hidden rounded-[7px] ring-1 ring-black/5 ring-inset">
                <ReleaseArt
                  art={release.art ?? fallbackArt}
                  className="transition-transform duration-500 ease-out group-hover:scale-[1.04]"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-black/45 via-black/5 to-transparent" />
                <span className="absolute bottom-1.5 left-[7px] inline-flex h-[18px] items-center gap-1 rounded-[5px] bg-black/40 px-1.5 text-[10.5px] font-semibold text-white ring-1 ring-white/15 backdrop-blur-[6px]">
                  <Sparkles aria-hidden size={10} strokeWidth={2} />
                  What's new
                </span>
              </div>
              <div className="px-2.5 pt-1.5 pb-2.5">
                <div className="flex items-center gap-1.5">
                  {fresh ? <span className="size-1.5 shrink-0 rounded-full bg-accent" /> : null}
                  <h3 className="truncate text-[12.5px] leading-[17px] font-semibold tracking-[-0.01em] text-fg">
                    {release.version}: {release.title}
                  </h3>
                </div>
                <p className="mt-[3px] line-clamp-2 text-[11.5px] leading-4 text-fg-secondary">
                  {release.summary}
                </p>
              </div>
              <button
                type="button"
                onClick={onOpen}
                aria-label={`What's new in Macarchy ${release.version}: ${release.title}. Open the changelog`}
                className="absolute inset-0 rounded-[10px] focus-visible:ring-2 focus-visible:ring-accent focus-visible:outline-none focus-visible:ring-inset"
              />
              <Tooltip content="Dismiss" describe={false}>
                <button
                  type="button"
                  onClick={onDismiss}
                  aria-label="Dismiss what's new"
                  className="absolute top-[9px] right-[9px] grid size-5 place-items-center rounded-full bg-black/40 text-white/85 opacity-0 ring-1 ring-white/15 backdrop-blur-[6px] transition-[opacity,background-color] duration-150 group-hover:opacity-100 hover:bg-black/60 hover:text-white focus-visible:opacity-100 focus-visible:ring-2 focus-visible:ring-accent focus-visible:outline-none"
                >
                  <X aria-hidden size={11} strokeWidth={2.25} />
                </button>
              </Tooltip>
            </article>
          </div>
        </div>
      </div>
    </div>
  );
}
