import { createFileRoute } from "@tanstack/react-router";
import { YoursPage } from "@/features/library/custom/YoursPage";

export const Route = createFileRoute("/library/yours")({
  component: YoursPage,
});
