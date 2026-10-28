import { useState, type ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { REFERENCES_MAX } from "@/shared/sync";
import { BottomSheet } from "@/shared/ui/BottomSheet";
import { Button, TextButton } from "@/shared/ui/Button";
import { Card } from "@/shared/ui/Card";
import { AddIcon } from "@/shared/ui/icons.gen";
import { TextField } from "@/shared/ui/TextField";
import { REFERENCE_FIELDS, REFERENCE_TYPES, newReference, type ReferenceDraft, type ReferenceType } from "./form";
import { FieldGroup } from "./TextSections";

/** One reference in a card: its type, Remove, and a field for each of its type's members. */
function ReferenceCard({
  reference,
  index,
  error,
  onChange,
  onRemove,
}: {
  reference: ReferenceDraft;
  index: number;
  error: string | undefined;
  onChange: (reference: ReferenceDraft) => void;
  onRemove: () => void;
}): ReactElement {
  const { t } = useTranslation();
  const { required, optional } = REFERENCE_FIELDS[reference.type];
  const type = t(`library.editor.references.types.${reference.type}`);
  return (
    <Card shape="tile">
      <div className="flex flex-col gap-lg">
        <div className="flex items-center justify-between gap-md">
          <h3 className="text-row-title text-on-surface">{type}</h3>
          <TextButton aria-label={t("library.editor.references.removeLabel", { type })} onPress={onRemove}>
            {t("library.editor.references.remove")}
          </TextButton>
        </div>
        {[...required, ...optional].map((field) => (
          <TextField
            key={field}
            name={`references.${String(index)}.${field}`}
            label={t(`library.editor.references.fields.${field}`)}
            isRequired={required.includes(field)}
            {...(field === "surah" || field.startsWith("ayah") ? { inputMode: "numeric" as const } : {})}
            value={reference.fields[field] ?? ""}
            onChange={(value) => {
              onChange({ ...reference, fields: { ...reference.fields, [field]: value } });
            }}
          />
        ))}
        {error !== undefined && (
          <p role="alert" className="text-caption text-error">
            {error}
          </p>
        )}
      </div>
    </Card>
  );
}

/** Picks the type of a new reference: a bottom sheet with a button per type. */
function AddReference({
  onAdd,
  isDisabled,
}: {
  onAdd: (type: ReferenceType) => void;
  isDisabled: boolean;
}): ReactElement {
  const { t } = useTranslation();
  const [isOpen, setOpen] = useState(false);
  return (
    <>
      <Button
        variant="secondary"
        icon={AddIcon}
        isDisabled={isDisabled}
        onPress={() => {
          setOpen(true);
        }}
      >
        {t("library.editor.references.add")}
      </Button>
      <BottomSheet isOpen={isOpen} onOpenChange={setOpen} title={t("library.editor.references.addTitle")}>
        <div className="flex flex-col gap-sm">
          {REFERENCE_TYPES.map((type) => (
            <Button
              key={type}
              variant="secondary"
              onPress={() => {
                onAdd(type);
                setOpen(false);
              }}
            >
              {t(`library.editor.references.types.${type}`)}
            </Button>
          ))}
        </div>
      </BottomSheet>
    </>
  );
}

/**
 * "References": where the text comes from, each in the catalog's reference shape (Qur'an surah
 * and ayahs, a hadith, a book, a shaykh, or other), up to 20.
 */
export function ReferencesEditor({
  references,
  errors,
  onChange,
}: {
  references: readonly ReferenceDraft[];
  errors: Record<string, string>;
  onChange: (references: ReferenceDraft[]) => void;
}): ReactElement {
  const { t } = useTranslation();
  return (
    <FieldGroup title={t("library.editor.references.title")} error={errors["references"]}>
      {references.length === 0 && (
        <p className="text-caption text-on-surface-variant">{t("library.editor.references.none")}</p>
      )}
      {references.map((reference, index) => (
        <ReferenceCard
          key={reference.id}
          reference={reference}
          index={index}
          error={errors[`references.${String(index)}`]}
          onChange={(changed) => {
            onChange(references.map((other) => (other.id === reference.id ? changed : other)));
          }}
          onRemove={() => {
            onChange(references.filter((other) => other.id !== reference.id));
          }}
        />
      ))}
      <AddReference
        isDisabled={references.length >= REFERENCES_MAX}
        onAdd={(type) => {
          onChange([...references, newReference(type, references)]);
        }}
      />
    </FieldGroup>
  );
}
