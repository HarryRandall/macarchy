import { CircleHelp } from "lucide-react";

import { Tooltip } from "./tooltip";

/**
 * The question mark beside a title. A real button so Tab and VoiceOver reach
 * it; the help text is its description, so its name stays short.
 */
function HelpTooltip({ text }: { text: string }) {
  return (
    <Tooltip content={text}>
      <button
        type="button"
        aria-label="Help"
        className="inline-flex size-[22px] shrink-0 items-center justify-center rounded-small text-fg-secondary transition-colors hover:text-fg"
      >
        <CircleHelp aria-hidden className="size-3" strokeWidth={2} />
      </button>
    </Tooltip>
  );
}

export { HelpTooltip };
