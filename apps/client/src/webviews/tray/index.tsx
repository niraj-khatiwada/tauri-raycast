import { invoke } from "@tauri-apps/api/core";

export default function TrayWindow() {
  const handleTrayPopoverClose = () => {
    invoke("close_tray_popover");
  };

  const handleFocusMain = async () => {
    await invoke("focus_or_create_main_window");
  };

  const handleQuitApp = async () => {
    try {
      await invoke("quit_app");
    } catch (error) {
      console.error(
        "Failed to issue application process terminate sequence:",
        error,
      );
    }
  };
  return (
    <div className="p-4 w-screen h-screen">
      <div className="w-full flex items-center justify-center gap-2 text-white text-xs">
        <button
          onClick={handleFocusMain}
          className="bg-blue-600 px-4 py-1 rounded-md text-xs w-fit"
        >
          Open/Focus Main Window
        </button>
        <button
          onClick={handleTrayPopoverClose}
          className="bg-blue-600 px-4 py-1 rounded-md text-xs w-fit"
        >
          Close Tray Popover
        </button>
        <button
          onClick={handleQuitApp}
          className="bg-red-400 px-4 py-1 rounded-md text-xs w-fit absolute right-4 bottom-4"
        >
          Quit App
        </button>
      </div>
    </div>
  );
}
