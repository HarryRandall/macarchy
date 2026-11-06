import { type RefObject, useLayoutEffect, useState } from "react";

import { observeResize } from "./observe-resize";

/** The element's rendered size, kept current before each paint. */
export function useElementSize(ref: RefObject<HTMLElement | null>) {
  const [size, setSize] = useState({ width: 0, height: 0 });
  useLayoutEffect(() => {
    const element = ref.current;
    if (!element) return;
    const measure = () => {
      const { width, height } = element.getBoundingClientRect();
      setSize((current) =>
        current.width === width && current.height === height ? current : { width, height },
      );
    };
    measure();
    return observeResize(element, measure);
  }, [ref]);
  return size;
}
