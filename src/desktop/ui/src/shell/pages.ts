import { advancedPage } from "~/features/advanced/page";
import { layoutPage } from "~/features/layout/page";

import type { RegisteredPage } from "./page";

/**
 * Every pane React draws. A pane not listed here opens the classic window.
 * To migrate a page, add its definition here and its pane to `Pane.migrated`
 * in Swift.
 */
export const pages: RegisteredPage[] = [layoutPage, advancedPage];
