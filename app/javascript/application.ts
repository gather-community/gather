// Entry point for the build script in your package.json
import "@hotwired/turbo-rails";
import "./controllers"

// Disable turbo drive by default
Turbo.session.drive = false
