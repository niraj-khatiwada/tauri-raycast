import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/popover/")({
  component: RouteComponent,
});

function RouteComponent() {
  return <h1 className="text-white font-3xl">Hello "/popover/"!</h1>;
}
