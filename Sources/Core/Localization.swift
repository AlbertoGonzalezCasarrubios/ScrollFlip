import Foundation

enum Language: String, CaseIterable, Identifiable {
    case system
    case spanish = "es"
    case english = "en"

    var id: String { rawValue }

    /// Concrete language to use (resolves "system" from the user's preferences).
    var resolved: Language {
        guard self == .system else { return self }
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("es") ? .spanish : .english
    }
}

/// All user-facing strings. Adding a language = adding one column here.
enum L: CaseIterable {
    // Menu
    case statusActive, statusPaused, statusNoPermission
    case menuSettings, menuOpenAccessibility, enabled, invertVertical, invertHorizontal
    case launchAtLogin, about, aboutTagline, quit
    // Window: tabs and banners
    case tabGeneral, tabTry, tabLanguage
    case permissionBanner, openSettings, pausedBanner, enable
    // General tab
    case sectionWheel, speed, speedDefault, reset, speedNote, sectionStartup, loginError
    // Try tab
    case tryTitle, tryIntro, mouse, trackpad, noMovement, cardCaption
    case badgeInverted, badgeSpeed, badgeUnchanged, row, scrollHere, privacyNote
    // Side buttons
    case sectionButtons, sideButtonsToggle, swapButtons, sideButtonsNote, sideButtonsPrivacy
    case tryButtonsTitle, tryButtonsIntro, tryBack, tryForward, countdown, tryButtonsDisabled
    // Language tab
    case languageTitle, languageSystem, languageNote

    func text(_ language: Language) -> String {
        let (es, en) = pair
        return language == .english ? en : es
    }

    private var pair: (String, String) {
        switch self {
        case .statusActive: return ("Ratón invertido · trackpad intacto", "Mouse reversed · trackpad untouched")
        case .statusPaused: return ("En pausa", "Paused")
        case .statusNoPermission: return ("Falta permiso de Accesibilidad", "Accessibility permission needed")
        case .menuSettings: return ("Ajustes y demo…", "Settings & demo…")
        case .menuOpenAccessibility: return ("Dar permiso de Accesibilidad…", "Grant Accessibility permission…")
        case .enabled: return ("Activado", "Enabled")
        case .invertVertical: return ("Invertir vertical", "Reverse vertical")
        case .invertHorizontal: return ("Invertir horizontal", "Reverse horizontal")
        case .launchAtLogin: return ("Abrir al iniciar sesión", "Open at login")
        case .about: return ("Acerca de ScrollFlip", "About ScrollFlip")
        case .aboutTagline: return ("Invierte la rueda del ratón sin tocar el trackpad.",
                                    "Reverses the mouse wheel without touching the trackpad.")
        case .quit: return ("Salir de ScrollFlip", "Quit ScrollFlip")

        case .tabGeneral: return ("General", "General")
        case .tabTry: return ("Probar", "Try it")
        case .tabLanguage: return ("Idioma", "Language")
        case .permissionBanner:
            return ("Falta el permiso de Accesibilidad. Sin él, ScrollFlip no puede modificar la rueda.",
                    "Accessibility permission is missing. Without it ScrollFlip cannot modify the wheel.")
        case .openSettings: return ("Abrir ajustes", "Open Settings")
        case .pausedBanner: return ("ScrollFlip está en pausa: ahora no modifica nada.",
                                    "ScrollFlip is paused: it is not changing anything.")
        case .enable: return ("Activar", "Enable")

        case .sectionWheel: return ("Rueda del ratón", "Mouse wheel")
        case .speed: return ("Velocidad", "Speed")
        case .speedDefault: return ("predeterminada", "default")
        case .reset: return ("Restablecer", "Reset")
        case .speedNote: return ("Solo afecta al ratón. El trackpad mantiene la velocidad del sistema.",
                                 "Only affects the mouse. The trackpad keeps the system speed.")
        case .sectionStartup: return ("Inicio", "Startup")
        case .loginError: return ("No se pudo cambiar. Mueve la app a /Applications e inténtalo de nuevo.",
                                  "Could not change it. Move the app to /Applications and try again.")

        case .tryTitle: return ("Cómo funciona ScrollFlip", "How ScrollFlip works")
        case .tryIntro:
            return ("Invierte la rueda del ratón y deja el trackpad como está. Desplázate en el recuadro con cada uno y mira qué hace la app con el evento.",
                    "It reverses the mouse wheel and leaves the trackpad alone. Scroll in the box with each one and watch what the app does to the event.")
        case .mouse: return ("Ratón", "Mouse")
        case .trackpad: return ("Trackpad / Magic Mouse", "Trackpad / Magic Mouse")
        case .noMovement: return ("Aún sin movimiento", "No movement yet")
        case .cardCaption: return ("Evento original → lo que reciben las apps", "Original event → what apps receive")
        case .badgeInverted: return ("Invertido", "Reversed")
        case .badgeSpeed: return ("Velocidad", "Speed")
        case .badgeUnchanged: return ("Sin cambios", "Unchanged")
        case .row: return ("Fila", "Row")
        case .scrollHere: return ("Desplázate aquí ↓", "Scroll here ↓")
        case .privacyNote:
            return ("Los eventos solo se muestran mientras esta ventana está abierta. No se guardan y no salen de tu Mac.",
                    "Events are only shown while this window is open. They are not stored and never leave your Mac.")

        case .sectionButtons: return ("Botones laterales", "Side buttons")
        case .sideButtonsToggle: return ("Botones 4 y 5: Atrás / Adelante", "Buttons 4 and 5: Back / Forward")
        case .swapButtons: return ("Intercambiar botones", "Swap buttons")
        case .sideButtonsNote:
            return ("En Safari, Finder y otras apps de Apple se simula el gesto de deslizar entre páginas. Chrome, VS Code y similares ya entienden estos botones, así que los reciben tal cual.",
                    "In Safari, Finder and other Apple apps the swipe-between-pages gesture is simulated. Chrome, VS Code and similar apps already understand these buttons, so they receive them unchanged.")
        case .sideButtonsPrivacy:
            return ("Al activarlo, ScrollFlip también recibe los clics de los botones extra del ratón (nunca el izquierdo ni el derecho).",
                    "When on, ScrollFlip also receives clicks from the extra mouse buttons (never left or right clicks).")
        case .tryButtonsTitle: return ("Atrás / Adelante sin botones laterales", "Back / Forward without side buttons")
        case .tryButtonsIntro:
            return ("Pulsa un botón y cambia a Safari o Finder antes de 3 segundos: se simulará un clic del botón lateral.",
                    "Click a button and switch to Safari or Finder within 3 seconds: a side-button click will be simulated.")
        case .tryBack: return ("Atrás", "Back")
        case .tryForward: return ("Adelante", "Forward")
        case .countdown: return ("Cambia de app…", "Switch apps…")
        case .tryButtonsDisabled: return ("Activa «Botones 4 y 5» en General para probarlo.",
                                          "Turn on “Buttons 4 and 5” in General to try it.")
        case .languageTitle: return ("Idioma de la app", "App language")
        case .languageSystem: return ("Igual que el sistema", "Same as system")
        case .languageNote: return ("El cambio se aplica al instante en el menú y en esta ventana.",
                                    "The change applies instantly to the menu and this window.")
        }
    }
}
