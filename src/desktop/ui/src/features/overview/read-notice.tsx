import { Button } from "~/components/ui/button";
import { Notice } from "~/components/ui/notice";

export function ReadNotice({
  error,
  retry,
  busy,
}: {
  error: string | null;
  retry(): void;
  busy: boolean;
}) {
  return error ? (
    <Notice.Root variant="error">
      <Notice.Title>Could not complete that request</Notice.Title>
      <Notice.Description>{error}</Notice.Description>
      <Notice.Actions>
        <Button disabled={busy} onClick={retry}>
          Try again
        </Button>
      </Notice.Actions>
    </Notice.Root>
  ) : null;
}
