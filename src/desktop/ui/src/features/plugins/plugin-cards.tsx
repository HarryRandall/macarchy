import { BadgeCheck, Bell, BellRing, Sparkles } from "lucide-react";
import type { ReactNode } from "react";

import { focusRing, focusRingInset } from "~/components/ui/focus-ring";
import { Tooltip } from "~/components/ui/tooltip";
import { cn } from "~/lib/cn";

import {
  Avatar,
  hueGlass,
  hueInk,
  hueStyle,
  hueTint,
  PluginArt,
  PluginTile,
  Stage,
} from "./plugin-art";
import type { CardShape } from "./plugins-layout";
import { officialAuthor, type Plugin } from "./plugins-mock";

/** Below this width the grid falls to one column, so no card is squeezed. */
const shapeClass: Record<CardShape, string> = {
  normal: "",
  wide: "@min-[600px]:col-span-2",
  tall: "@min-[600px]:col-span-2 @min-[600px]:row-span-2",
  full: "@min-[600px]:col-span-3",
};

/** A bell that asks to hear when the plugin is ready, and says so once asked. */
export function NotifyButton({
  name,
  on,
  onClick,
}: {
  name: string;
  on: boolean;
  onClick: () => void;
}) {
  return (
    <Tooltip content={on ? "Stop notifying" : "Notify me when it's ready"} describe={false}>
      <button
        type="button"
        aria-pressed={on}
        aria-label={on ? `Stop notifying me about ${name}` : `Notify me when ${name} is ready`}
        onClick={onClick}
        className={cn(
          "relative z-[2] inline-flex h-[26px] shrink-0 items-center justify-center gap-[5px] rounded-full border text-meta font-medium transition-colors",
          focusRing,
          on
            ? "px-[9px] hover:brightness-110"
            : "w-[26px] border-hairline text-fg-tertiary hover:bg-hover hover:text-fg",
        )}
        style={
          on ? { background: hueTint(14), borderColor: hueGlass(40), color: hueInk } : undefined
        }
      >
        {on ? <BellRing aria-hidden size={12} strokeWidth={2.2} /> : <Bell aria-hidden size={13} />}
        {on ? "Notifying" : null}
      </button>
    </Tooltip>
  );
}

/**
 * The card's surface. The whole card opens the plugin's details through one
 * button stretched over it, so the bell inside stays a separate control
 * rather than a button nested in a button.
 */
function CardShell({
  plugin,
  onOpen,
  className,
  children,
}: {
  plugin: Plugin;
  onOpen: () => void;
  className?: string;
  children: ReactNode;
}) {
  return (
    <div
      data-slot="plugin-card"
      style={hueStyle(plugin)}
      className={cn(
        "group relative flex min-w-0 overflow-hidden rounded-[14px] border border-hairline bg-card shadow-card",
        "transition-[transform,border-color,box-shadow] duration-200 ease-out hover:-translate-y-0.5 motion-reduce:hover:translate-y-0",
        "hover:border-[color-mix(in_srgb,var(--pl)_45%,var(--line-hairline))] hover:shadow-[0_18px_38px_-20px_var(--pl)]",
        className,
      )}
    >
      <button
        type="button"
        aria-label={`${plugin.name} details`}
        onClick={onOpen}
        className={cn("absolute inset-0 z-[1] rounded-[14px]", focusRingInset)}
      />
      {children}
    </div>
  );
}

function CardBody({ plugin, text, big }: { plugin: Plugin; text: string; big?: boolean }) {
  return (
    <div className="flex-1 px-4 pt-3.5 pb-4">
      <div className="flex min-w-0 items-center gap-2.5">
        <PluginTile plugin={plugin} size={big ? 34 : 28} />
        <h3
          className={cn(
            "truncate font-semibold tracking-[-0.01em] text-fg",
            big ? "text-[15.5px] leading-5" : "text-card-title",
          )}
        >
          {plugin.name}
        </h3>
      </div>
      <p className="mt-2.5 line-clamp-3 text-detail leading-[1.55] text-fg-secondary">{text}</p>
    </div>
  );
}

function CardFooter({
  plugin,
  notified,
  onNotify,
}: {
  plugin: Plugin;
  notified: boolean;
  onNotify: () => void;
}) {
  return (
    <div className="flex h-11 shrink-0 items-center gap-[7px] border-t border-hairline px-4">
      <Avatar author={plugin.author} size={16} />
      <span className="min-w-0 truncate text-meta text-fg-tertiary">{plugin.author}</span>
      {plugin.author === officialAuthor ? (
        <span className="shrink-0" style={{ color: hueInk }}>
          <BadgeCheck aria-hidden size={12} strokeWidth={2.2} />
          <span className="sr-only">, official</span>
        </span>
      ) : null}
      <span className="flex-1" />
      <NotifyButton name={plugin.name} on={notified} onClick={onNotify} />
    </div>
  );
}

interface CardProps {
  plugin: Plugin;
  notified: boolean;
  onNotify: () => void;
  onOpen: () => void;
}

/** A plugin in its category's grid, drawn to the shape the bento gives it. */
export function PluginCard({
  plugin,
  shape,
  notified,
  onNotify,
  onOpen,
}: CardProps & { shape: CardShape }) {
  const footer = <CardFooter plugin={plugin} notified={notified} onNotify={onNotify} />;
  if (shape === "wide" || shape === "full") {
    return (
      <CardShell
        plugin={plugin}
        onOpen={onOpen}
        className={cn("flex-col @min-[600px]:flex-row", shapeClass[shape])}
      >
        <Stage
          plugin={plugin}
          scale={1.1}
          className="min-h-[236px] flex-[1.2] border-b border-hairline @min-[600px]:border-r @min-[600px]:border-b-0"
        >
          <PluginArt id={plugin.id} />
        </Stage>
        <div className="flex min-w-0 flex-1 flex-col">
          <CardBody plugin={plugin} text={plugin.about} big />
          {footer}
        </div>
      </CardShell>
    );
  }
  const tall = shape === "tall";
  return (
    <CardShell plugin={plugin} onOpen={onOpen} className={cn("flex-col", shapeClass[shape])}>
      <Stage
        plugin={plugin}
        height={tall ? undefined : 156}
        scale={tall ? 1.4 : 0.92}
        className={cn("border-b border-hairline", tall && "min-h-[300px] flex-1")}
      >
        <PluginArt id={plugin.id} />
      </Stage>
      <CardBody plugin={plugin} text={tall ? plugin.about : plugin.detail} big={tall} />
      {footer}
    </CardShell>
  );
}

/** One of the two large cards above the categories. */
export function FeaturedCard({ plugin, notified, onNotify, onOpen }: CardProps) {
  return (
    <CardShell plugin={plugin} onOpen={onOpen} className="flex-col">
      <Stage
        plugin={plugin}
        height={220}
        scale={1.35}
        className="border-b border-hairline"
        label={
          <>
            <Sparkles aria-hidden size={11} strokeWidth={2.2} />
            Featured
          </>
        }
      >
        <PluginArt id={plugin.id} />
      </Stage>
      <CardBody plugin={plugin} text={plugin.about} big />
      <CardFooter plugin={plugin} notified={notified} onNotify={onNotify} />
    </CardShell>
  );
}

/** A category's title over its grid, with an optional note at the trailing end. */
export function PluginSection({
  title,
  aside,
  children,
}: {
  title: string;
  aside?: ReactNode;
  children: ReactNode;
}) {
  return (
    <section aria-label={title}>
      <div className="mb-3.5 flex items-end gap-3">
        <h2 className="min-w-0 flex-1 truncate text-card-title text-fg">{title}</h2>
        {aside}
      </div>
      {children}
    </section>
  );
}

/** Nothing here can be installed yet. */
export function SoonNote() {
  return (
    <span className="inline-flex shrink-0 items-center gap-1.5 pb-px text-small text-fg-tertiary">
      <span aria-hidden className="size-1.5 rounded-full bg-warning" />
      Coming soon
    </span>
  );
}
