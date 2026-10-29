import { useState, type ReactElement } from "react";
import { Form } from "react-aria-components";
import { useTranslation } from "react-i18next";
import { useLanguage } from "@/shared/i18n";
import type { CustomDhikrDocument, Entity, SyncState } from "@/shared/sync";
import { Button } from "@/shared/ui/Button";
import { FormAlert } from "@/shared/ui/FormAlert";
import { OptionCheckboxGroup, OptionRow } from "@/shared/ui/OptionRow";
import { TextLink } from "@/shared/ui/TextLink";
import { ConflictDialog, RefusedDialog } from "../custom/ConflictDialog";
import { sortedTags, tagIdsOf } from "../custom/data";
import { AudioField } from "./AudioField";
import { useFocusFirstError } from "./focusFirstError";
import { EMPTY_VALUES, valuesFrom, type EditorValues } from "./form";
import { ReferencesEditor } from "./ReferencesEditor";
import { ArabicField, FieldGroup, KindField, LanguageFields } from "./TextSections";
import { useAudioUpload } from "./useAudioUpload";
import { useSaveDhikr } from "./useSaveDhikr";

const MAX_TAGS = 20;

/** The dhikr's tags: a checkbox row per tag of the account, up to 20, and a link to manage them. */
function TagsField({
  state,
  value,
  onChange,
}: {
  state: SyncState;
  value: readonly string[];
  onChange: (tagIds: string[]) => void;
}): ReactElement {
  const { t } = useTranslation();
  const language = useLanguage();
  const tags = sortedTags(state, language);
  return (
    <FieldGroup title={t("library.detail.tags")} hint={t("library.tags.hint", { max: MAX_TAGS })}>
      {tags.length === 0 ? (
        <p className="text-caption text-on-surface-variant">{t("library.tags.none")}</p>
      ) : (
        <OptionCheckboxGroup aria-label={t("library.detail.tags")} value={[...value]} onChange={onChange}>
          {tags.map((tag) => (
            <OptionRow
              key={tag.id}
              value={tag.id}
              label={tag.document.name}
              isDisabled={value.length >= MAX_TAGS && !value.includes(tag.id)}
            />
          ))}
        </OptionCheckboxGroup>
      )}
      <TextLink to="/library/tags">{t("library.tags.manage")}</TextLink>
    </FieldGroup>
  );
}

type TextKey = "title" | "transliteration" | "translation";

/** The title (at least one language), the transliteration (en, ml) and the translation (en, ar, ml). */
function TranslatedTexts({
  values,
  titleError,
  onChange,
}: {
  values: EditorValues;
  titleError: string | undefined;
  onChange: <K extends TextKey>(key: K, value: EditorValues[K]) => void;
}): ReactElement {
  const { t } = useTranslation();
  return (
    <>
      <FieldGroup title={t("library.editor.title")} hint={t("library.editor.titleHint")} error={titleError}>
        <LanguageFields
          group="title"
          languages={["en", "ar", "ml"] as const}
          values={values.title}
          onChange={(language, text) => {
            onChange("title", { ...values.title, [language]: text });
          }}
        />
      </FieldGroup>
      <FieldGroup title={t("library.detail.transliteration")}>
        <LanguageFields
          group="transliteration"
          languages={["en", "ml"] as const}
          values={values.transliteration}
          multiline
          onChange={(language, text) => {
            onChange("transliteration", { ...values.transliteration, [language]: text });
          }}
        />
      </FieldGroup>
      <FieldGroup title={t("library.detail.translation")}>
        <LanguageFields
          group="translation"
          languages={["en", "ar", "ml"] as const}
          values={values.translation}
          multiline
          onChange={(language, text) => {
            onChange("translation", { ...values.translation, [language]: text });
          }}
        />
      </FieldGroup>
    </>
  );
}

/**
 * The custom dhikr editor (slices 3b and 3c): kind, the Arabic (required), a title in at least
 * one language, transliteration and translation per language, references, tags, and its
 * recording, uploaded from here or kept as a phone left it. Save waits while a recording uploads.
 */
export function DhikrEditor({
  accountId,
  state,
  existing,
}: {
  accountId: string;
  state: SyncState;
  existing: Entity<CustomDhikrDocument> | null;
}): ReactElement {
  const { t } = useTranslation();
  const [values, setValues] = useState<EditorValues>(() =>
    existing === null ? EMPTY_VALUES : valuesFrom(existing.document, tagIdsOf(state, existing.id)),
  );
  const { save, errors, alert, isPending, conflict, refused, fieldFailures } = useSaveDhikr(accountId, state, existing);
  const set = <K extends keyof EditorValues>(key: K, value: EditorValues[K]) => {
    setValues((previous) => ({ ...previous, [key]: value }));
  };
  const audioUpload = useAudioUpload(accountId, (audio) => {
    set("audio", audio);
  });
  const form = useFocusFirstError(fieldFailures, refused !== null);

  return (
    <Form
      ref={form}
      validationBehavior="aria"
      validationErrors={errors}
      onSubmit={(event) => {
        event.preventDefault();
        void save(values);
      }}
      className="flex flex-col gap-section-gap"
    >
      <KindField
        value={values.kind}
        onChange={(kind) => {
          set("kind", kind);
        }}
        error={errors["kind"]}
      />
      <ArabicField
        value={values.arabic}
        onChange={(arabic) => {
          set("arabic", arabic);
        }}
      />
      <TranslatedTexts values={values} titleError={errors["title"]} onChange={set} />
      <ReferencesEditor
        references={values.references}
        errors={errors}
        onChange={(refs) => {
          set("references", refs);
        }}
      />
      <TagsField
        state={state}
        value={values.tagIds}
        onChange={(tagIds) => {
          set("tagIds", tagIds);
        }}
      />
      <AudioField
        audio={values.audio}
        uploader={audioUpload}
        errors={errors}
        onRemove={() => {
          set("audio", null);
        }}
      />
      <FormAlert message={alert} />
      <Button type="submit" isPending={isPending} isDisabled={audioUpload.state.status === "uploading"}>
        {t("library.editor.save")}
      </Button>
      <ConflictDialog conflict={conflict} state={state} isPending={isPending} />
      <RefusedDialog refused={refused} />
    </Form>
  );
}
