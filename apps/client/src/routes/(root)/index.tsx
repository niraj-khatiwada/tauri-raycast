import { createFileRoute } from "@tanstack/react-router";
import { invoke } from "@tauri-apps/api/core";
import {
  getCurrentWindow,
  LogicalSize,
  PhysicalSize,
} from "@tauri-apps/api/window";

export const Route = createFileRoute("/(root)/")({
  component: App,
});

const appWindow = getCurrentWindow();

function App() {
  const handleNewWindow = async (evt: any) => {
    const rect = evt.target.getBoundingClientRect();
    invoke("open_floating_popover", {
      x: rect.left,
      y: rect.bottom,
      width: 350,
      height: 250,
    });
  };
  return (
    <>
      <div className="h-screen w-screen flex items-center justify-center flex-col">
        Hello
        <br />
        Hello
        <br />
        Hello
        <br />
        Hello
        <br />
        Hello
        <br />
        Hello
        <br />
        Hello
        <br />
        Hello
        <br />
        <button onClick={handleNewWindow}>Click</button>
      </div>
    </>
  );
}
