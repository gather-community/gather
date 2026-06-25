// Entry point for the build script in your package.json
import "@hotwired/turbo-rails";
import "./utils/i18n";
import "./utils/modal"; // Sets window.Modal for the legacy/Backbone bundle
import "./controllers";

// Disable turbo drive by default
Turbo.session.drive = false;
