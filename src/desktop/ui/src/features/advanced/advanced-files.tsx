import {
  Check,
  FileDiff,
  FolderOpen,
  Hammer,
  Info,
  LayoutGrid,
  PanelTop,
  SquareDashed,
  type LucideIcon,
} from "lucide-react";
import { useState } from "react";

import type { GeneratedFileId } from "~/bridge/protocol";
import { StatusDot, type StatusDotTone } from "~/components/charts/status-dot";
import { Button } from "~/components/ui/button";
import { Card, CardHeader } from "~/components/ui/card";
import { IconButton } from "~/components/ui/icon-button";
import { IconTile } from "~/components/ui/icon-tile";
import { PreviewTag } from "~/components/ui/preview-tag";
import { TruncatedText } from "~/components/ui/truncated-text";
import { cn } from "~/lib/cn";

import { type DiffLine, fileEdits, fileWritten } from "./advanced-mock";

/** The files Macarchy writes from your preferences. */
export const generatedFiles = [
  {
    id: "yabairc",
    title: "Window layout",
    tool: "yabai",
    icon: LayoutGrid,
    path: "~/Library/Application Support/Macarchy/config/yabairc",
  },
  {
    id: "sketchybarrc",
    title: "Menu bar",
    tool: "SketchyBar",
    icon: PanelTop,
    path: "~/Library/Application Support/Macarchy/config/sketchybarrc",
  },
  {
    id: "bordersrc",
    title: "Window borders",
    tool: "JankyBorders",
    icon: SquareDashed,
    path: "~/Library/Application Support/Macarchy/config/bordersrc",
  },
] as const satisfies readonly {
  id: GeneratedFileId;
  title: string;
  tool: string;
  icon: LucideIcon;
  path: string;
}[];

type GeneratedFile = (typeof generatedFiles)[number];

/** Narrow cards drop the Modified column so the file's name keeps its room. */
const columns =
  "grid grid-cols-[minmax(0,1fr)_112px_64px] items-center gap-4 px-5 @min-[620px]:grid-cols-[minmax(0,1fr)_120px_120px_64px]";

interface StatusLook {
  tone: StatusDotTone;
  ink: string;
}

const quiet: StatusLook = { tone: "idle", ink: "text-fg-secondary" };
const attention: StatusLook = { tone: "warn", ink: "text-warning" };

/** The rebuild outcomes the host reports, with how each should read. */
const outcomeLook: Record<string, StatusLook> = {
  Rebuilt: { tone: "ok", ink: "text-success" },
  "Up to date": quiet,
  "Edits backed up": attention,
};

function FileStatus({ outcome, edited }: { outcome: string | undefined; edited: boolean }) {
  const label = outcome ?? (edited ? "Custom edits" : "Generated");
  const look = outcome ? (outcomeLook[outcome] ?? quiet) : edited ? attention : quiet;
  return (
    <span className={cn("flex min-w-0 items-center gap-2 text-detail", look.ink)}>
      <StatusDot tone={look.tone} />
      <span className="truncate">{label}</span>
    </span>
  );
}

interface DiffMark {
  sign: string;
  /** Read before the line, since the sign itself is hidden. */
  word: string;
  ink: string;
  row: string;
}

const diffMarks: Record<DiffLine["kind"], DiffMark> = {
  "+": { sign: "+", word: "Added:", ink: "text-success", row: "bg-success-soft" },
  "-": { sign: "-", word: "Removed:", ink: "text-danger", row: "bg-danger-soft" },
  " ": { sign: "", word: "", ink: "", row: "" },
};

function Edits({ lines }: { lines: readonly DiffLine[] }) {
  if (!lines.length) {
    return (
      <p className="flex items-center gap-2 text-detail text-fg-secondary">
        <Check aria-hidden size={13} className="text-fg-tertiary" />
        No edits made outside Macarchy
      </p>
    );
  }
  const added = lines.filter((line) => line.kind === "+").length;
  const removed = lines.filter((line) => line.kind === "-").length;
  return (
    <>
      <div className="mb-2 flex items-center justify-between gap-3 text-small text-fg-secondary">
        <span className="flex items-center gap-2">
          Rebuilding replaces these edits
          <PreviewTag />
        </span>
        <span className="font-mono text-mono text-fg-tertiary">
          <span className="sr-only">
            {added} added, {removed} removed
          </span>
          <span aria-hidden>
            +{added} -{removed}
          </span>
        </span>
      </div>
      <div className="overflow-hidden rounded-tile border border-hairline bg-card py-1.5 font-mono text-mono leading-5 select-text">
        {lines.map((line, index) => {
          const mark = diffMarks[line.kind];
          return (
            <div
              // The lines are a fixed excerpt; their order never changes.
              key={index}
              className={cn("flex gap-3 px-3", mark.row)}
            >
              <span
                aria-hidden
                className="w-4 shrink-0 text-right text-fg-tertiary tabular-nums select-none"
              >
                {line.line}
              </span>
              <span aria-hidden className={cn("w-2 shrink-0 select-none", mark.ink)}>
                {mark.sign}
              </span>
              {mark.word ? <span className="sr-only">{mark.word}</span> : null}
              <span className="min-w-0 truncate whitespace-pre text-fg">{line.text}</span>
            </div>
          );
        })}
      </div>
    </>
  );
}

function FileRow({
  file,
  outcome,
  open,
  busy,
  rebuilding,
  onToggle,
  onRebuild,
}: {
  file: GeneratedFile;
  outcome: string | undefined;
  open: boolean;
  busy: boolean;
  rebuilding: boolean;
  onToggle: () => void;
  onRebuild: () => void;
}) {
  // Mock: the host cannot compare a file with what Macarchy would write yet; a rebuild clears it.
  const edits = outcome ? [] : fileEdits[file.id];
  const panel = `file-edits-${file.id}`;
  const Icon = file.icon;
  return (
    <div className="border-t border-hairline">
      <div className={cn("group h-14 transition-colors hover:bg-side", columns, open && "bg-side")}>
        <div className="flex min-w-0 items-center gap-3">
          <IconTile variant="outline">
            <Icon strokeWidth={1.75} />
          </IconTile>
          <div className="min-w-0">
            <div className="flex min-w-0 items-baseline gap-2">
              <span className="truncate font-mono text-detail font-medium text-fg">{file.id}</span>
              <span className="shrink-0 text-meta text-fg-tertiary">{file.tool}</span>
            </div>
            <TruncatedText text={file.path} className="font-mono text-mono text-fg-tertiary" />
          </div>
        </div>
        <FileStatus outcome={outcome} edited={edits.length > 0} />
        <span className="hidden text-detail text-fg-secondary tabular-nums @min-[620px]:block">
          {/* Mock: the host does not report when each file was written yet. */}
          {outcome ? "Just now" : fileWritten[file.id]}
        </span>
        <div
          className={cn(
            "flex items-center justify-end gap-0.5 transition-opacity",
            open || rebuilding
              ? "opacity-100"
              : "opacity-0 group-focus-within:opacity-100 group-hover:opacity-100",
          )}
        >
          <IconButton
            size="sm"
            label={`Rebuild ${file.title.toLowerCase()} from preferences`}
            busy={rebuilding}
            disabled={busy}
            onClick={onRebuild}
          >
            <Hammer aria-hidden />
          </IconButton>
          <IconButton
            size="sm"
            label={open ? `Hide edits to ${file.id}` : `Show edits to ${file.id}`}
            pressed={open}
            aria-expanded={open}
            aria-controls={open ? panel : undefined}
            onClick={onToggle}
          >
            <FileDiff aria-hidden />
          </IconButton>
        </div>
      </div>
      {open ? (
        <div id={panel} className="border-t border-hairline bg-side px-5 py-3">
          <Edits lines={edits} />
        </div>
      ) : null}
    </div>
  );
}

/** The generated files, their state, and rebuilding them from preferences. */
export function ConfigFilesCard({
  outcomes,
  busy,
  pending,
  onRebuild,
  onRebuildAll,
  onReveal,
}: {
  outcomes: Partial<Record<GeneratedFileId, string>>;
  busy: boolean;
  /** The id of the file being rebuilt, or "all". */
  pending: string | null;
  onRebuild: (id: GeneratedFileId) => void;
  onRebuildAll: () => void;
  onReveal: () => void;
}) {
  const [open, setOpen] = useState<GeneratedFileId | null>(null);
  // Mock: edits made outside Macarchy are placeholders until the host can compare files.
  const edited = generatedFiles.filter((file) => !outcomes[file.id] && fileEdits[file.id].length);
  const editedNote = `${edited.length === 1 ? "1 file has" : `${edited.length} files have`} edits made outside Macarchy`;
  return (
    <Card className="@container overflow-hidden">
      <CardHeader
        title="Config files"
        action={
          <>
            <Button size="sm" variant="ghost" onClick={onReveal}>
              <FolderOpen aria-hidden />
              Open settings folder
            </Button>
            <Button size="sm" busy={pending === "all"} disabled={busy} onClick={onRebuildAll}>
              {pending === "all" ? null : <Hammer aria-hidden />}
              Rebuild all
            </Button>
          </>
        }
      />
      <div
        aria-hidden
        className={cn(
          "h-8 border-t border-hairline bg-side text-meta font-medium text-fg-tertiary",
          columns,
        )}
      >
        <span>File</span>
        <span>Status</span>
        <span className="hidden @min-[620px]:block">Modified</span>
        <span />
      </div>
      {generatedFiles.map((file) => (
        <FileRow
          key={file.id}
          file={file}
          outcome={outcomes[file.id]}
          open={open === file.id}
          busy={busy}
          rebuilding={pending === file.id}
          onToggle={() => setOpen((current) => (current === file.id ? null : file.id))}
          onRebuild={() => onRebuild(file.id)}
        />
      ))}
      {edited.length ? (
        <p className="flex items-center gap-2 border-t border-hairline px-5 py-2.5 text-small text-fg-secondary">
          <Info aria-hidden size={13} className="shrink-0 text-fg-tertiary" />
          {editedNote}
        </p>
      ) : null}
    </Card>
  );
}
