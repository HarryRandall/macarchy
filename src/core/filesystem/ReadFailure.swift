import Foundation

/// Words for a file that could not be opened, in place of Foundation's.
///
/// Foundation says "The file "skhdrc" couldn't be opened." with curly quotes
/// and no reason or remedy. These name the file, say why, and say what to do.
public enum ReadFailure {
    public static func describe(_ error: any Error, at url: URL) -> String {
        if let error = error as? ConfigurationError { return error.message }
        let file = Paths.display(url)
        let posix = posixCode(error)
        let cocoa = (error as NSError).domain == NSCocoaErrorDomain ? (error as NSError).code : nil
        switch (cocoa, posix) {
        case (_, EISDIR?):
            return "\(file) is a folder, so it cannot be read as a file. "
                + "Move the folder aside and restore the file."
        case (NSFileReadNoSuchFileError?, _), (_, ENOENT?):
            return "\(file) does not exist."
        case (NSFileReadNoPermissionError?, _), (_, EACCES?), (_, EPERM?):
            return "Macarchy does not have permission to read \(file). "
                + "Check its permissions in Finder's Get Info."
        case (NSFileReadInapplicableStringEncodingError?, _):
            return "\(file) is not plain UTF-8 text. Save it as UTF-8 and try again."
        default:
            return "\(file) could not be read: \(sentence(error.localizedDescription))"
        }
    }

    /// Foundation's punctuation with straight quotes and apostrophes, for
    /// text passed through from a system error.
    public static func plain(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
    }

    /// System text as the end of a sentence: straight quotes, one full stop.
    public static func sentence(_ text: String) -> String {
        let text = plain(text).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.hasSuffix(".") ? text : text + "."
    }

    private static func posixCode(_ error: any Error) -> Int32? {
        let error = error as NSError
        if error.domain == NSPOSIXErrorDomain { return Int32(error.code) }
        guard let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError else { return nil }
        return posixCode(underlying)
    }
}
