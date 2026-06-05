import { invoke } from "@tauri-apps/api/core";

export default function PanelWindow({ panelId }: { panelId: string }) {
  const handleClosePanel = () => {
    invoke("close_window_panel", {
      panelId,
    });
  };

  return (
    <>
      <div className="p-4 w-screen h-screen my-4">
        <h1 className="text-2xl text-center text-white">Pane id @{panelId}</h1>
        <p className="text-white">
          These panels are different than the normal Tauri transparent window.
          They do not lose focus of the main window.
        </p>

        <div className="m-5 flex flex-col items-center justify-center gap-2 text-white text-xs">
          {panelId === "apple-intelligence" ? (
            <p className="px-2 text-center rounded-2xl block text-xl bg-linear-to-r from-indigo-500 via-purple-500 to-pink-500 bg-clip-text text-transparent">
              The borderglow you see here is created using SwiftUI
            </p>
          ) : null}
          <button
            onClick={handleClosePanel}
            className="bg-blue-600 px-4 py-1 rounded-md text-xs w-fit"
          >
            Close Panel
          </button>
        </div>
      </div>
    </>
  );
}
