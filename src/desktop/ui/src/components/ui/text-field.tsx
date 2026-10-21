import { Field as FieldPrimitive } from "@base-ui/react/field";
import { Input as InputPrimitive } from "@base-ui/react/input";
import { cva, type VariantProps } from "class-variance-authority";
import { type ComponentProps, type ReactNode, useId } from "react";

import { cn } from "~/lib/cn";

const inputVariants = cva(
  [
    "w-full min-w-0 rounded-control border border-hairline bg-well text-fg outline-none placeholder:text-fg-secondary",
    // Focus thickens the border to a 2 pt accent ring, as macOS draws it.
    "transition-[border-color,box-shadow] focus:border-accent-stroke focus:shadow-[0_0_0_1px_var(--accent-stroke)] focus-visible:outline-none",
    "disabled:opacity-45 aria-invalid:border-danger data-invalid:border-danger",
    "aria-invalid:focus:shadow-[0_0_0_1px_var(--status-danger)] data-invalid:focus:shadow-[0_0_0_1px_var(--status-danger)]",
  ],
  {
    variants: {
      variant: {
        default: "text-row-title",
        /** Paths, commands, patterns and hex values: anything read character by character. */
        mono: "font-mono text-[12px]",
      },
      size: {
        default: "h-7 px-2",
        sm: "h-6 px-1.5",
      },
    },
    defaultVariants: { variant: "default", size: "default" },
  },
);

type InputProps = Omit<InputPrimitive.Props, "size" | "className"> &
  VariantProps<typeof inputVariants> & { className?: string };

/**
 * A single-line text box. Inside `Field.Root` it is labelled, described and
 * marked invalid automatically; alone, give it an `aria-label` or an `id` a
 * row title points at.
 */
function Input({ className, variant, size, spellCheck, ...props }: InputProps) {
  return (
    <InputPrimitive
      data-slot="input"
      // Names and commands are not prose; WebKit's red squiggles only distract.
      spellCheck={spellCheck ?? (variant === "mono" ? false : undefined)}
      autoCapitalize="off"
      autoCorrect="off"
      className={cn(inputVariants({ variant, size }), className)}
      {...props}
    />
  );
}

type TextareaProps = Omit<ComponentProps<"textarea">, "className"> &
  Pick<VariantProps<typeof inputVariants>, "variant"> & { className?: string };

/**
 * Several lines, such as a problem description. A native textarea: label it
 * with `aria-label`, or use `TextareaField`.
 */
function Textarea({ className, variant, ...props }: TextareaProps) {
  return (
    <textarea
      data-slot="textarea"
      className={cn(
        inputVariants({ variant }),
        "min-h-[90px] resize-y px-2 py-1.5 leading-[18px]",
        className,
      )}
      {...props}
    />
  );
}

/** Ties a label, a description and an error to the control inside it. */
function Root({
  className,
  ...props
}: Omit<FieldPrimitive.Root.Props, "className"> & { className?: string }) {
  return (
    <FieldPrimitive.Root
      data-slot="field"
      className={cn("flex min-w-0 flex-col gap-1.5", className)}
      {...props}
    />
  );
}

function Label({
  className,
  ...props
}: Omit<FieldPrimitive.Label.Props, "className"> & { className?: string }) {
  return (
    <FieldPrimitive.Label
      data-slot="field-label"
      className={cn("text-meta font-medium text-fg-secondary", className)}
      {...props}
    />
  );
}

/** Help that stays visible: the format expected, an example. */
function Description({
  className,
  ...props
}: Omit<FieldPrimitive.Description.Props, "className"> & { className?: string }) {
  return (
    <FieldPrimitive.Description
      data-slot="field-description"
      className={cn("text-row-detail text-fg-secondary", className)}
      {...props}
    />
  );
}

/** Shown while the field is invalid. Write what to change, not only what is wrong. */
function ErrorText({
  className,
  ...props
}: Omit<FieldPrimitive.Error.Props, "className"> & { className?: string }) {
  return (
    <FieldPrimitive.Error
      data-slot="field-error"
      className={cn("text-row-detail text-danger select-text", className)}
      {...props}
    />
  );
}

const Field = { Root, Label, Description, Error: ErrorText };

type TextFieldProps = InputProps & {
  label: string;
  /** Visually hidden but still the accessible name, for a field a row title already labels. */
  hideLabel?: boolean;
  description?: ReactNode;
  /** A validation or save error from the page. Marks the field invalid while set. */
  error?: ReactNode;
  /** Classes for the field's wrapper; `className` styles the input. */
  fieldClassName?: string;
};

/** A labelled input with optional description and error, the common case of `Field`. */
function TextField({
  label,
  hideLabel = false,
  description,
  error,
  fieldClassName,
  ...props
}: TextFieldProps) {
  return (
    <Field.Root invalid={Boolean(error)} className={fieldClassName}>
      <Field.Label className={hideLabel ? "sr-only" : undefined}>{label}</Field.Label>
      <Input {...props} />
      {description ? <Field.Description>{description}</Field.Description> : null}
      {error ? <Field.Error match>{error}</Field.Error> : null}
    </Field.Root>
  );
}

/** `TextField` for several lines, with the same label, description and error slots. */
function TextareaField({
  label,
  hideLabel = false,
  description,
  error,
  fieldClassName,
  id,
  ...props
}: TextareaProps & Omit<TextFieldProps, keyof InputProps>) {
  const fallbackId = useId();
  const controlId = id ?? fallbackId;
  const descriptionId = `${controlId}-description`;
  const errorId = `${controlId}-error`;
  const describedBy = [description && descriptionId, error && errorId].filter(Boolean).join(" ");
  return (
    <div data-slot="field" className={cn("flex min-w-0 flex-col gap-1.5", fieldClassName)}>
      <label
        htmlFor={controlId}
        className={cn("text-meta font-medium text-fg-secondary", hideLabel && "sr-only")}
      >
        {label}
      </label>
      <Textarea
        id={controlId}
        aria-invalid={error ? true : undefined}
        aria-describedby={describedBy || undefined}
        {...props}
      />
      {description ? (
        <p id={descriptionId} className="text-row-detail text-fg-secondary">
          {description}
        </p>
      ) : null}
      {error ? (
        <p id={errorId} className="text-row-detail text-danger select-text">
          {error}
        </p>
      ) : null}
    </div>
  );
}

export { Field, Input, inputVariants, Textarea, TextareaField, TextField };
