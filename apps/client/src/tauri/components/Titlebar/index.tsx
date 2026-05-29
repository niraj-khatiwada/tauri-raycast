import { getCurrentWindow } from "@tauri-apps/api/window";
import { useEffect, useRef } from "react";

const appWindow = getCurrentWindow();

function Titlebar() {
  const titlebarRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    function handleMouseDown(evt: MouseEvent) {
      if (evt.buttons === 1) {
        if (evt.detail === 2) {
          // appWindow.toggleMaximize();
        } else {
          appWindow.startDragging();
        }
      }
    }
    if (titlebarRef.current) {
      titlebarRef.current.addEventListener("mousedown", handleMouseDown);
      // titlebarRef.current.addEventListener(
      //   "dblclick",
      //   appWindow.toggleMaximize,
      // );
    }
    return () => {
      titlebarRef.current?.removeEventListener("mousedown", handleMouseDown);
      // titlebarRef.current?.removeEventListener(
      //   "dblclick",
      //   appWindow.toggleMaximize,
      // );
    };
  }, []);

  return (
    <div
      ref={titlebarRef}
      id="titlebar"
      className="fixed top-0 left-0 right-0 bottom-0 w-full h-5 bg-transparent"
    />
  );
}

export default Titlebar;
