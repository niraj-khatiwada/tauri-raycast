import { createRouter, RouterProvider } from "@tanstack/react-router";

import ReactDOM from "react-dom/client";
import "./styles.css";

import { routeTree } from "./routeTree.gen";
import PopoverWindow from "./window/popover";

// See `vite.config.ts` for all defined values.
window.__appVersion = __appVersion;
window.__envMode = __envMode;

const hash = window.location.hash as "#popover" | undefined;
let isAppWindow = true;
if (hash === "#popover") {
  const rootElement = document.getElementById("popover")!;
  if (!rootElement.innerHTML) {
    const root = ReactDOM.createRoot(rootElement);
    root.render(<PopoverWindow />);
    isAppWindow = false;
  }
}

const router = createRouter({
  routeTree,
  defaultPreload: "intent",
});

declare module "@tanstack/react-router" {
  interface Register {
    router: typeof router;
  }
}

if (isAppWindow) {
  const rootElement = document.getElementById("app")!;
  if (!rootElement.innerHTML) {
    const root = ReactDOM.createRoot(rootElement);
    root.render(<RouterProvider router={router} />);
  }
}
