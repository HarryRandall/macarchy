import { useEffect, useState } from "react";

import { request } from "~/bridge/client";
import type { WidgetInfo } from "~/bridge/protocol";
import type { BarItem } from "./menu-bar-items";
import type { Sample } from "./widget-model";

/** Uses the clock's native formatter for the draft, including custom formats and time zones. */
export function useClockPreview(item: BarItem, widget: WidgetInfo | null, sample: Sample) {
  const [preview, setPreview] = useState<{ key: string; text: string } | null>(null);
  const settings = JSON.stringify(item.settings);
  const id = widget?.source === "date" && sample === "live" ? widget.id : null;
  const key = `${id}:${settings}`;
  useEffect(() => {
    if (!id) return;
    let active = true;
    const update = () => {
      void request("menuBar.previewWidget", { widget: id, settings: JSON.parse(settings) })
        .then((text) => {
          if (active) setPreview({ key, text });
        })
        .catch(() => {
          if (active) setPreview(null);
        });
    };
    update();
    const timer = setInterval(update, 1000);
    return () => {
      active = false;
      clearInterval(timer);
    };
  }, [id, settings, key]);
  return id && preview?.key === key ? preview.text : null;
}
