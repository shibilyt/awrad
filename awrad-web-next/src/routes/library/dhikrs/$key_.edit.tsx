import { createFileRoute } from "@tanstack/react-router";
import { EditDhikrPage } from "@/features/library/editor/EditorPage";

// `$key_`: the URL is /library/dhikrs/<id>/edit, but the editor isn't nested inside the dhikr page.
export const Route = createFileRoute("/library/dhikrs/$key_/edit")({
  component: EditDhikrPage,
});
