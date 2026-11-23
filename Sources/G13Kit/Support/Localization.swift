// Localization.swift
// Die Texte stehen auf Englisch im Code, Übersetzungen in Resources/<Sprache>.lproj.
// Sie gelten nur in der gebündelten App; `swift run`, g13ctl und Tests sind englisch.

#if !canImport(Darwin)
extension String {
    /// Ersatz für Foundations `String(localized:)`, das es außerhalb von Apple-Plattformen nicht gibt.
    init(localized text: String) { self = text }
}
#endif
