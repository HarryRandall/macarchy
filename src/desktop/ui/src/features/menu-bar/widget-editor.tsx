import { ChevronLeft } from "lucide-react";
import { type ReactNode, useId, useRef } from "react";

import type { MenuBarSettings, WidgetInfo } from "~/bridge/protocol";
import { Card } from "~/components/ui/card";
import { focusRing } from "~/components/ui/focus-ring";
import { IconButton } from "~/components/ui/icon-button";
import { SegmentedControl } from "~/components/ui/segmented-control";
import { cn } from "~/lib/cn";

import { BarPreview } from "./bar-preview";
import { OriginBadge, type WidgetFileActions } from "./item-inspector";
import type { BarItem } from "./menu-bar-items";
import type { BarLook } from "./menu-bar-store";
import { ClickSection } from "./widget-click";
import { clickOf, type Sample, sampleOptions, settingOf } from "./widget-model";
import { MenuPreview, WidgetChip } from "./widget-preview";
import { AboutSection, ContentSection, LookSection } from "./widget-sections";

/** The inspector's tabs, as sections down one page. */
const sections = [
  { id: "content", title: "Content" },
  { id: "look", title: "Look" },
  { id: "click", title: "Click" },
  { id: "about", title: "About" },
] as const;

/**
 * One widget on the bar, with every setting in view. The preview shows the
 * bar with this widget picked out and its dropdown open under it. Changes go
 * in the page's draft, and Apply sends them with the rest.
 */
export function WidgetEditor({
  item,
  widget,
  items,
  bar,
  look,
  widgets,
  sample,
  onSample,
  selectedRow,
  onSelectRow,
  files,
  actions,
  onChange,
  onBack,
}: {
  item: BarItem;
  widget: WidgetInfo;
  items: BarItem[];
  bar: MenuBarSettings;
  look: BarLook;
  widgets: readonly WidgetInfo[];
  sample: Sample;
  onSample: (sample: Sample) => void;
  selectedRow: number | null;
  onSelectRow: (index: number | null) => void;
  files: WidgetFileActions;
  /** Revert and Apply, which act on the whole bar. */
  actions: ReactNode;
  onChange: (patch: Partial<BarItem>) => void;
  onBack: () => void;
}) {
  const ids = useId();
  const refs = useRef<Record<string, HTMLElement | null>>({});
  const rows = clickOf(item, widget)?.dropdown;
  const settings = Object.fromEntries(
    widget.settings.map((setting) => [setting.key, settingOf(item, setting)]),
  );
  const body: Record<(typeof sections)[number]["id"], ReactNode> = {
    content: (
      <ContentSection
        item={item}
        widget={widget}
        onChange={onChange}
        onOpenFile={(file) => files.open(widget.id, file)}
      />
    ),
    look: <LookSection item={item} widget={widget} onChange={onChange} />,
    click: (
      <ClickSection
        item={item}
        widget={widget}
        onChange={onChange}
        selectedRow={selectedRow}
        onSelectRow={onSelectRow}
      />
    ),
    about: (
      <AboutSection
        widget={widget}
        onReveal={() => files.reveal(widget.id)}
        onOpen={(file) => files.open(widget.id, file)}
        onDuplicate={() => files.duplicate(widget.id)}
        duplicated={files.duplicated}
      />
    ),
  };

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center gap-2">
        <IconButton label="Back to Menu Bar" onClick={onBack}>
          <ChevronLeft aria-hidden />
        </IconButton>
        <h2 className="text-card-title text-fg">{item.title}</h2>
        <OriginBadge widget={widget} />
        {actions}
      </div>

      <div className="grid grid-cols-1 items-start gap-5 @min-[900px]:grid-cols-[minmax(0,1fr)_420px]">
        <section
          aria-label="Preview"
          className="flex flex-col gap-4 @min-[900px]:sticky @min-[900px]:top-0"
        >
          <div className="flex items-center gap-3">
            <SegmentedControl
              label="Sample values"
              size="sm"
              value={sample}
              options={sampleOptions}
              onValueChange={onSample}
            />
          </div>
          <BarPreview
            items={items}
            bar={bar}
            look={look}
            widgets={widgets}
            sample={sample}
            active={item.id}
            focus={item.id}
            onSelect={() => undefined}
            below={
              rows ? (
                <MenuPreview
                  rows={rows}
                  settings={settings}
                  selected={selectedRow}
                  onSelect={(index) => {
                    onSelectRow(index);
                    refs.current.click?.scrollIntoView({ block: "start", behavior: "smooth" });
                  }}
                />
              ) : (
                <span className="self-center text-small text-white/60">
                  {clickOf(item, widget)?.open
                    ? `Opens ${clickOf(item, widget)?.open}`
                    : clickOf(item, widget)?.run
                      ? "Runs a command"
                      : "Clicking does nothing"}
                </span>
              )
            }
          />
          <div className="flex flex-col gap-2">
            <span className="text-label text-fg-secondary uppercase">Samples</span>
            <div className="grid grid-cols-3 gap-3">
              {sampleOptions.map((option) => (
                <figure key={option.value} className="m-0 flex flex-col gap-1.5">
                  <div
                    className="grid h-14 place-items-center rounded-control border border-hairline"
                    style={{ background: look.background }}
                  >
                    <WidgetChip item={item} widget={widget} sample={option.value} look={look} />
                  </div>
                  <figcaption className="text-small text-fg-secondary">{option.label}</figcaption>
                </figure>
              ))}
            </div>
          </div>
        </section>

        <div className="flex flex-col gap-3">
          <nav aria-label="Jump to" className="flex gap-1">
            {sections.map((section) => (
              <button
                key={section.id}
                type="button"
                onClick={() =>
                  refs.current[section.id]?.scrollIntoView({ block: "start", behavior: "smooth" })
                }
                className={cn(
                  "h-7 rounded-control px-2.5 text-detail font-medium text-fg-secondary hover:bg-hover hover:text-fg",
                  focusRing,
                )}
              >
                {section.title}
              </button>
            ))}
          </nav>
          {sections.map((section) => (
            <Card
              key={section.id}
              ref={(element) => {
                refs.current[section.id] = element;
              }}
              aria-labelledby={`${ids}-${section.id}`}
              className="scroll-mt-4 p-4"
            >
              <div className="mb-3 flex items-baseline gap-2">
                <h3 id={`${ids}-${section.id}`} className="text-card-title text-fg">
                  {section.title}
                </h3>
              </div>
              {body[section.id]}
            </Card>
          ))}
        </div>
      </div>
    </div>
  );
}
