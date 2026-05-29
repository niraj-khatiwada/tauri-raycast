use rand::RngExt;
use serde_json::Number;
use std::time::{SystemTime, UNIX_EPOCH};
use tauri::window::{Effect, EffectsBuilder};
use tauri::Manager;
use tauri::{LogicalPosition, LogicalSize, PhysicalSize, WebviewUrl, WebviewWindowBuilder}; // Removed unused Window, Added PhysicalSize // Import the Rng trait

const MIN_WEBVIEW_WIDTH: f64 = 400.0;
const MIN_WEBVIEW_HEIGHT: f64 = 400.0;
const DEFAULT_WINDOW_WIDTH_PHYSICAL: u32 = 1200; // Default physical width
const DEFAULT_WINDOW_HEIGHT_PHYSICAL: u32 = 900; // Default physical height
const DEFAULT_SCALE_FACTOR: f64 = 1.0;

#[derive(serde::Serialize)]
pub struct WebviewDetails {
    id: String,
    label: String,
    url: String,
    bounds: String,
    position_x: Number,
    position_y: Number,
    size_width: Number,
    size_height: Number,
}

#[tauri::command]
pub fn add_webview(app_handle: tauri::AppHandle, url: &str) -> String {
    let main_window = app_handle
        .get_window("main")
        .expect("main window not found");

    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_millis();

    let label = format!("webview_{}", timestamp);

    let mut rng = rand::rng();

    // Get main window's scale factor and inner size (physical)

    let scale_factor = main_window.scale_factor().unwrap_or(DEFAULT_SCALE_FACTOR);

    let physical_size = main_window.inner_size().unwrap_or_else(|_| {
        PhysicalSize::new(
            DEFAULT_WINDOW_WIDTH_PHYSICAL,
            DEFAULT_WINDOW_HEIGHT_PHYSICAL,
        )
    });

    // Convert physical window size to logical window size

    let window_logical_width = physical_size.width as f64 / scale_factor;
    let window_logical_height = physical_size.height as f64 / scale_factor;

    // Generate random size (logical)

    // Ensure webview_width and webview_height are at least MIN_WEBVIEW_WIDTH/HEIGHT

    // and not larger than the window itself.

    let random_width_addition = if window_logical_width > MIN_WEBVIEW_WIDTH {
        rng.random_range(0.0..=(window_logical_width - MIN_WEBVIEW_WIDTH) * 0.35)
    // Allow it to take up to 75% of remaining space
    } else {
        0.0
    };

    let webview_width = (MIN_WEBVIEW_WIDTH + random_width_addition).min(window_logical_width);

    let random_height_addition = if window_logical_height > MIN_WEBVIEW_HEIGHT {
        rng.random_range(0.0..=(window_logical_height - MIN_WEBVIEW_HEIGHT) * 0.35)
    } else {
        0.0
    };

    let webview_height = (MIN_WEBVIEW_HEIGHT + random_height_addition).min(window_logical_height);

    // Generate random position (logical), ensuring the webview is within the main window

    let max_x = if window_logical_width > webview_width {
        window_logical_width - webview_width
    } else {
        0.0 // Should not happen if webview_width is capped by window_logical_width
    };

    let max_y = if window_logical_height > webview_height {
        window_logical_height - webview_height
    } else {
        0.0 // Should not happen
    };

    let random_x = rng.random_range(0.0..=max_x);
    let random_y = rng.random_range(0.0..=max_y);

    let webview_builder = tauri::webview::WebviewBuilder::new(
        // Changed to webview_builder
        label.clone(),
        WebviewUrl::External(url.parse().unwrap()),
    )
    .auto_resize();

    match main_window.add_child(
        webview_builder, // Use the builder directly
        LogicalPosition::new(1000., 1000.),
        LogicalSize::new(webview_width, webview_height),
    ) {
        Ok(_) => format!(
            "Webview '{}' added with URL: {} at logical ({:.1}, {:.1}) size logical ({:.1}, {:.1})",
            label, url, random_x, random_y, webview_width, webview_height
        ),

        Err(e) => format!("Error adding webview '{}': {:?}", label, e),
    }
}

#[tauri::command]
pub fn list_webviews(app_handle: tauri::AppHandle) -> Vec<WebviewDetails> {
    println!("Listing all webviews...");
    let main_window = app_handle
        .get_window("main")
        .expect("main window not found");

    println!(
        "Found {} webviews in main window.",
        main_window.webviews().len()
    );

    // Send all webviews except those whose URL starts with tauri://
    main_window
        .webviews()
        .iter()
        .filter(|webview| {
            match webview.url() {
                Ok(url) => !url.as_str().starts_with("tauri://"),
                _ => {
                    false // Include webviews without a URL
                }
            }
        })
        .map(|webview| {
            let id_str = webview.label().to_string();
            let label_str = webview.label().to_string();
            let url_str = webview.url().unwrap().to_string(); // webview.url() returns &url::Url
            let bounds_str = format!("{:?}", webview.bounds()); // Assuming webview.bounds() is a valid method in your context
            let position_x = webview.position().unwrap().x.into();
            let position_y = webview.position().unwrap().y.into();
            let size_width = webview.size().unwrap().width.into();
            let size_height = webview.size().unwrap().height.into();

            WebviewDetails {
                id: id_str,
                label: label_str,
                url: url_str, // Using the requested 'Url' casing
                bounds: bounds_str,
                position_x: position_x,
                position_y: position_y,
                size_width: size_width,
                size_height: size_height,
            }
        })
        .collect()
}

#[tauri::command]
pub fn close_webview(app_handle: tauri::AppHandle, webviewlabel: &str) -> String {
    println!("Request to close webview with label: {}", webviewlabel);
    let main_window = app_handle
        .get_window("main")
        .expect("main window not found");

    let webview = main_window
        .webviews()
        .into_iter()
        .find(|w| w.label() == webviewlabel);
    if let Some(webview) = webview {
        webview.close().unwrap();
        format!("Webview '{}' closed successfully.", webviewlabel)
    } else {
        format!("Webview '{}' not found.", webviewlabel)
    }
}

#[tauri::command]
pub fn open_floating_popover(app: tauri::AppHandle, x: f64, y: f64, width: f64, height: f64) {
    if let Some(window) = app.get_webview_window("popover_window") {
        println!("popover_window already exists. closing & creating a new one...");
        window.close().unwrap();
    } else {
        if let Some(main_window) = app.get_webview_window("main") {
            let position = main_window.outer_position().unwrap();
            let logical_position = position.to_logical::<f64>(main_window.scale_factor().unwrap());
            let mut popover_url = if let Some(main_win) = app.get_webview_window("main") {
                main_win.url().unwrap()
            } else {
                // Fallback safety string if main window is missing
                "https://tauri.localhost/index.html"
                    .parse::<tauri::Url>()
                    .unwrap()
            };

            popover_url.set_fragment(Some("popover"));
            let popover = WebviewWindowBuilder::new(
                &app,
                "popover_window",
                WebviewUrl::CustomProtocol(popover_url),
            )
            .parent(&main_window)
            .expect("Main parent window not found")
            .decorations(false)
            .transparent(true)
            .always_on_top(true)
            .skip_taskbar(true)
            .resizable(false)
            .maximizable(false)
            .minimizable(false)
            .focused(true)
            .effects(
                EffectsBuilder::new()
                    .effect(Effect::Menu)
                    .state(tauri::window::EffectState::Active)
                    .radius(20.0)
                    .build(),
            )
            .inner_size(width, height)
            .position(logical_position.x as f64 + x, logical_position.y as f64 + y)
            .build()
            .unwrap();

            let popover_clone = popover.clone();
            let main_window_clone = main_window.clone();

            popover.on_window_event(move |event| match event {
                tauri::WindowEvent::Focused(false) => {
                    let _ = popover_clone.close();
                    let _ = main_window_clone.set_focus();
                }
                _ => {}
            });

            let main_window_clone = main_window.clone();
            let popover_main_clone = popover.clone();
            main_window.on_window_event(move |event| match event {
                tauri::WindowEvent::Destroyed | tauri::WindowEvent::Moved(..) => {
                    if let Some(pop_win) = popover_main_clone
                        .app_handle()
                        .get_webview_window("popover_window")
                    {
                        let _ = pop_win.close();
                        let _ = main_window_clone.set_focus();
                    }
                }

                _ => {}
            });
        }
    }
}

// New command to close any window dynamically by its string identifier
#[tauri::command]
pub fn close_floating_popover(app: tauri::AppHandle, label: String) -> Result<(), String> {
    if let Some(window) = app.get_webview_window(&label) {
        window.close().map_err(|e| e.to_string())?;
        Ok(())
    } else {
        Err(format!("Window with label '{}' not found", label))
    }
}
