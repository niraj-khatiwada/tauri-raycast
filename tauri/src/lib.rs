use tauri::Manager;

mod commands;
mod macos;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![
            commands::add_webview,
            commands::list_webviews,
            commands::close_webview,
            commands::open_floating_popover,
            commands::close_floating_popover
        ])
        .setup(|app_handle| {
            if let Some(main_window) = app_handle.get_webview_window("main") {
                let main_window_clone = main_window.clone();
                macos::hide_traffic_light_buttons(&main_window_clone);
                #[cfg(not(debug_assertions))]
                main_window.on_window_event(move |event| match event {
                    tauri::WindowEvent::Focused(is_focused) => {
                        if !is_focused && main_window_clone.webview_windows().len() == 1 {
                            main_window_clone.close().unwrap();
                        }
                    }
                    _ => {}
                });
            }
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
