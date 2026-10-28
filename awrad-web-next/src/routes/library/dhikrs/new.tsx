import { createFileRoute } from "@tanstack/react-router";
import { NewDhikrPage } from "@/features/library/editor/EditorPage";

export const Route = createFileRoute("/library/dhikrs/new")({
  component: NewDhikrPage,
});
