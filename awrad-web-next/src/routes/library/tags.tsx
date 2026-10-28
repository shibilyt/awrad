import { createFileRoute } from "@tanstack/react-router";
import { TagsPage } from "@/features/library/tags/TagsPage";

export const Route = createFileRoute("/library/tags")({
  component: TagsPage,
});
