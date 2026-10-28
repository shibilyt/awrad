import { useId, type ReactElement, type ReactNode } from "react";
import { useTranslation } from "react-i18next";
import type { DhikrKind } from "@/shared/dhikr-catalog";
import { DHIKR_KINDS } from "@/shared/sync";
import { OptionRadioGroup, OptionRow } from "@/shared/ui/OptionRow";
import { TextField } from "@/shared/ui/TextField";

/**
 * A titled group of the editor's fields, with a message for the group as a whole (`title`
 * missing); `data-invalid` while it has one, so a failed save can jump to it.
 */
export function FieldGroup({
  title,
  hint,
  error,
  children,
}: {
  title: string;
  hint?: string;
  error?: string | undefined;
  children: ReactNode;
}): ReactElement {
  const heading = useId();
  return (
    <section
      aria-labelledby={heading}
      data-invalid={error === undefined ? undefined : true}
      className="flex flex-col gap-row-gap"
    >
      <div className="flex flex-col gap-xs">
        <h2 id={heading} className="text-section-title text-on-surface">
          {title}
        </h2>
        {hint !== undefined && <p className="text-caption text-on-surface-variant">{hint}</p>}
      </div>
      {children}
      {error !== undefined && (
        <p role="alert" className="text-caption text-error">
          {error}
        </p>
      )}
    </section>
  );
}

/** What kind of text it is (it decides how the detail shows it): one option row per kind. */
export function KindField({
  value,
  onChange,
  error,
}: {
  value: DhikrKind;
  onChange: (kind: DhikrKind) => void;
  error?: string | undefined;
}): ReactElement {
  const { t } = useTranslation();
  return (
    <FieldGroup title={t("library.editor.kind")} error={error}>
      <OptionRadioGroup
        aria-label={t("library.editor.kind")}
        value={value}
        onChange={(kind) => {
          const found = DHIKR_KINDS.find((candidate) => candidate === kind);
          if (found !== undefined) onChange(found);
        }}
      >
        {DHIKR_KINDS.map((kind) => (
          <OptionRow key={kind} value={kind} label={t(`library.kinds.${kind}`)} />
        ))}
      </OptionRadioGroup>
    </FieldGroup>
  );
}

/** The Arabic text, required: right to left in the Arabic font, growing with its lines. */
export function ArabicField({ value, onChange }: { value: string; onChange: (value: string) => void }): ReactElement {
  const { t } = useTranslation();
  return (
    <TextField
      name="arabic"
      label={t("library.editor.arabic")}
      description={t("library.editor.arabicHint")}
      isRequired
      multiline
      textLanguage="ar"
      value={value}
      onChange={onChange}
    />
  );
}

type Language = "en" | "ar" | "ml";

/**
 * One text in several languages (title, transliteration, translation): a field per language,
 * named `<group>.<language>` so a problem lands on its field. Arabic ones type right to left.
 */
export function LanguageFields<L extends Language>({
  group,
  languages,
  values,
  onChange,
  multiline = false,
}: {
  group: "title" | "transliteration" | "translation";
  languages: readonly L[];
  values: Record<L, string>;
  onChange: (language: L, value: string) => void;
  multiline?: boolean;
}): ReactElement {
  const { t } = useTranslation();
  return (
    <div className="flex flex-col gap-lg">
      {languages.map((language) => (
        <TextField
          key={language}
          name={`${group}.${language}`}
          label={t(`library.editor.inLanguage.${language}`)}
          multiline={multiline}
          {...(language === "ar" ? { textLanguage: "ar" as const } : {})}
          value={values[language]}
          onChange={(value) => {
            onChange(language, value);
          }}
        />
      ))}
    </div>
  );
}
