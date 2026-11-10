/// Arabic glyphs come from IBM Plex Sans Arabic; Latin
/// text keeps each style's own family. Every TextStyle that sets its own
/// `fontFamily` must also set this fallback, because such a style replaces
/// the inherited one (for example in app bar titles).
const arabicFontFallback = <String>['IBMPlexSansArabic'];
