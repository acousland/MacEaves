import Foundation
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

    /// The "bubblegum" asset catalog color resource.
    static let bubblegum = DeveloperToolsSupport.ColorResource(name: "bubblegum", bundle: resourceBundle)

    /// The "buttercup" asset catalog color resource.
    static let buttercup = DeveloperToolsSupport.ColorResource(name: "buttercup", bundle: resourceBundle)

    /// The "indigo" asset catalog color resource.
    static let indigo = DeveloperToolsSupport.ColorResource(name: "indigo", bundle: resourceBundle)

    /// The "lavender" asset catalog color resource.
    static let lavender = DeveloperToolsSupport.ColorResource(name: "lavender", bundle: resourceBundle)

    /// The "magenta" asset catalog color resource.
    static let magenta = DeveloperToolsSupport.ColorResource(name: "magenta", bundle: resourceBundle)

    /// The "navy" asset catalog color resource.
    static let navy = DeveloperToolsSupport.ColorResource(name: "navy", bundle: resourceBundle)

    /// The "orange" asset catalog color resource.
    static let orange = DeveloperToolsSupport.ColorResource(name: "orange", bundle: resourceBundle)

    /// The "oxblood" asset catalog color resource.
    static let oxblood = DeveloperToolsSupport.ColorResource(name: "oxblood", bundle: resourceBundle)

    /// The "periwinkle" asset catalog color resource.
    static let periwinkle = DeveloperToolsSupport.ColorResource(name: "periwinkle", bundle: resourceBundle)

    /// The "poppy" asset catalog color resource.
    static let poppy = DeveloperToolsSupport.ColorResource(name: "poppy", bundle: resourceBundle)

    /// The "purple" asset catalog color resource.
    static let purple = DeveloperToolsSupport.ColorResource(name: "purple", bundle: resourceBundle)

    /// The "seafoam" asset catalog color resource.
    static let seafoam = DeveloperToolsSupport.ColorResource(name: "seafoam", bundle: resourceBundle)

    /// The "sky" asset catalog color resource.
    static let sky = DeveloperToolsSupport.ColorResource(name: "sky", bundle: resourceBundle)

    /// The "tan" asset catalog color resource.
    static let tan = DeveloperToolsSupport.ColorResource(name: "tan", bundle: resourceBundle)

    /// The "teal" asset catalog color resource.
    static let teal = DeveloperToolsSupport.ColorResource(name: "teal", bundle: resourceBundle)

    /// The "yellow" asset catalog color resource.
    static let yellow = DeveloperToolsSupport.ColorResource(name: "yellow", bundle: resourceBundle)

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

}

