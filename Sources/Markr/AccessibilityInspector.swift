import AppKit
import ApplicationServices

struct SelectionInspection {
    let selectedText: String?
    let isEditable: Bool
    let primaryRole: String
    let origin: ClipOrigin
}

final class AccessibilityInspector {
    static let shared = AccessibilityInspector()

    private let systemWideElement = AXUIElementCreateSystemWide()
    private var warmedUpPids = Set<pid_t>()

    private init() {}

    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    func requestPermissionPrompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func warmUpApplicationIfNeeded(pid: pid_t) {
        guard isTrusted else { return }
        if !warmedUpPids.contains(pid) {
            let appElement = AXUIElementCreateApplication(pid)
            AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, kCFBooleanTrue)
            AXUIElementSetAttributeValue(appElement, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
            warmedUpPids.insert(pid)
        }
    }

    func isPointInEditableElement(screenPoint: CGPoint, pid: pid_t?) -> Bool {
        guard isTrusted else { return false }
        if let pid = pid {
            let appElement = AXUIElementCreateApplication(pid)
            if let focused = copyElementAttribute(appElement, attribute: kAXFocusedUIElementAttribute),
               isElementOrAncestorsEditable(focused) {
                return true
            }
        }
        if let hitElement = elementAtScreenPoint(screenPoint),
           isElementOrAncestorsEditable(hitElement) {
            return true
        }
        return false
    }

    /// Captures origin metadata (App Name, Window Title, Browser URL) for the current frontmost application
    func captureCurrentOrigin(referenceElements: [AXUIElement] = []) -> ClipOrigin {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return ClipOrigin(appName: "macOS", bundleId: nil, windowTitle: nil, sourceURL: nil)
        }

        let pid = frontApp.processIdentifier
        let appName = frontApp.localizedName ?? "App"
        let bundleId = frontApp.bundleIdentifier

        guard isTrusted else {
            return ClipOrigin(appName: appName, bundleId: bundleId, windowTitle: nil, sourceURL: nil)
        }

        warmUpApplicationIfNeeded(pid: pid)
        let appElement = AXUIElementCreateApplication(pid)

        var candidates = referenceElements
        if let focused = copyElementAttribute(appElement, attribute: kAXFocusedUIElementAttribute) {
            candidates.append(focused)
        }
        let focusedWindow = copyElementAttribute(appElement, attribute: kAXFocusedWindowAttribute)
        if let win = focusedWindow {
            candidates.append(win)
        }

        let windowTitle = focusedWindow.flatMap { stringAttribute($0, attribute: kAXTitleAttribute) }

        var detectedURL: String? = nil
        for candidate in candidates {
            if let urlStr = extractURL(from: candidate) {
                detectedURL = urlStr
                break
            }
        }

        return ClipOrigin(
            appName: appName,
            bundleId: bundleId,
            windowTitle: windowTitle,
            sourceURL: detectedURL
        )
    }

    /// Full inspection on mouse-up after a MarkGesture
    func inspectSelection(mouseDownScreenPoint: CGPoint, mouseUpScreenPoint: CGPoint) -> SelectionInspection? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = frontApp.processIdentifier
        let appName = frontApp.localizedName ?? "App"
        let bundleId = frontApp.bundleIdentifier

        guard isTrusted else {
            return SelectionInspection(
                selectedText: nil,
                isEditable: false,
                primaryRole: "Sem Permissão AX",
                origin: ClipOrigin(appName: appName, bundleId: bundleId, windowTitle: nil, sourceURL: nil)
            )
        }

        warmUpApplicationIfNeeded(pid: pid)
        let appElement = AXUIElementCreateApplication(pid)

        let focusedElement = copyElementAttribute(appElement, attribute: kAXFocusedUIElementAttribute)
            ?? copyElementAttribute(systemWideElement, attribute: kAXFocusedUIElementAttribute)
        let mouseUpElement = elementAtScreenPoint(mouseUpScreenPoint)
        let mouseDownElement = elementAtScreenPoint(mouseDownScreenPoint)

        let primaryRole = (mouseUpElement.flatMap { stringAttribute($0, attribute: kAXRoleAttribute) })
            ?? (focusedElement.flatMap { stringAttribute($0, attribute: kAXRoleAttribute) })
            ?? "AXUnknown"

        // EditableGuard: check focused, mouseUp, and mouseDown elements + ancestors
        let focusedEditable = focusedElement.map { isElementOrAncestorsEditable($0) } ?? false
        let upEditable = mouseUpElement.map { isElementOrAncestorsEditable($0) } ?? false
        let downEditable = mouseDownElement.map { isElementOrAncestorsEditable($0) } ?? false
        let isEditable = focusedEditable || upEditable || downEditable

        var candidates: [AXUIElement] = []
        if let focusedElement = focusedElement { candidates.append(focusedElement) }
        if let mouseUpElement = mouseUpElement { candidates.append(mouseUpElement) }
        if let mouseDownElement = mouseDownElement { candidates.append(mouseDownElement) }
        candidates.append(appElement)

        var selectedText: String? = nil
        for candidate in candidates {
            if let text = extractSelectedText(from: candidate), !text.isEmpty {
                selectedText = text
                break
            }
        }

        let origin = captureCurrentOrigin(referenceElements: candidates)

        return SelectionInspection(
            selectedText: selectedText,
            isEditable: isEditable,
            primaryRole: primaryRole,
            origin: origin
        )
    }

    // MARK: - Private AX Tree Traversal

    private func elementAtScreenPoint(_ point: CGPoint) -> AXUIElement? {
        var element: AXUIElement?
        let err = AXUIElementCopyElementAtPosition(systemWideElement, Float(point.x), Float(point.y), &element)
        guard err == .success else { return nil }
        return element
    }

    private func isElementOrAncestorsEditable(_ startElement: AXUIElement) -> Bool {
        var current: AXUIElement? = startElement
        var depth = 0

        let editableRoles: Set<String> = [
            kAXTextFieldRole as String,
            kAXTextAreaRole as String,
            kAXComboBoxRole as String,
            "AXSearchField"
        ]

        let editableSubroles: Set<String> = [
            kAXSearchFieldSubrole as String,
            kAXSecureTextFieldSubrole as String,
            "AXTextInput"
        ]

        while let element = current, depth < 40 {
            if let editable = boolAttribute(element, attribute: "AXEditable"), editable == true {
                return true
            }

            let role = stringAttribute(element, attribute: kAXRoleAttribute) ?? ""
            let subrole = stringAttribute(element, attribute: kAXSubroleAttribute) ?? ""

            if editableSubroles.contains(subrole) {
                return true
            }

            if editableRoles.contains(role) {
                if let explicitEditable = boolAttribute(element, attribute: "AXEditable"), explicitEditable == false {
                    // Explicitly marked non-editable
                } else {
                    return true
                }
            }

            if role == "AXWebArea" || role == (kAXWindowRole as String) || role == (kAXApplicationRole as String) {
                break
            }

            let containerRoles: Set<String> = [
                "AXGroup",
                kAXScrollAreaRole as String,
                kAXSplitGroupRole as String,
                kAXListRole as String,
                kAXTableRole as String,
                kAXOutlineRole as String,
                kAXRowRole as String,
                "AXGenericElement",
                "AXSection"
            ]
            if !containerRoles.contains(role) {
                var isValueSettable = DarwinBoolean(false)
                if AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &isValueSettable) == .success,
                   isValueSettable.boolValue {
                    let nonTextControlRoles: Set<String> = [
                        kAXScrollBarRole as String,
                        kAXSliderRole as String,
                        kAXCheckBoxRole as String,
                        kAXRadioButtonRole as String,
                        kAXPopUpButtonRole as String,
                        kAXButtonRole as String,
                        kAXTabGroupRole as String
                    ]
                    if !nonTextControlRoles.contains(role) {
                        return true
                    }
                }
            }

            current = copyElementAttribute(element, attribute: kAXParentAttribute)
            depth += 1
        }

        return false
    }

    private func extractSelectedText(from startElement: AXUIElement) -> String? {
        var current: AXUIElement? = startElement
        var depth = 0

        while let element = current, depth < 40 {
            if let rawText = stringAttribute(element, attribute: kAXSelectedTextAttribute) {
                let cleaned = Self.cleanExtractedText(rawText)
                if !cleaned.isEmpty {
                    return cleaned
                }
            }

            if let markerRange = rawAttribute(element, attribute: "AXSelectedTextMarkerRange") {
                var extracted: CFTypeRef?
                let err = AXUIElementCopyParameterizedAttributeValue(
                    element,
                    "AXStringForTextMarkerRange" as CFString,
                    markerRange,
                    &extracted
                )
                if err == .success, let rawStr = extracted as? String {
                    let cleaned = Self.cleanExtractedText(rawStr)
                    if !cleaned.isEmpty {
                        return cleaned
                    }
                }
            }

            let role = stringAttribute(element, attribute: kAXRoleAttribute) ?? ""
            if role == (kAXWindowRole as String) || role == (kAXApplicationRole as String) {
                break
            }

            current = copyElementAttribute(element, attribute: kAXParentAttribute)
            depth += 1
        }

        return nil
    }

    private static func cleanExtractedText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{FFFC}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractURL(from startElement: AXUIElement) -> String? {
        var current: AXUIElement? = startElement
        var depth = 0

        while let element = current, depth < 40 {
            if let urlStr = urlOrStringAttribute(element, attribute: kAXURLAttribute),
               urlStr.hasPrefix("http://") || urlStr.hasPrefix("https://") {
                return urlStr
            }

            if let docStr = urlOrStringAttribute(element, attribute: kAXDocumentAttribute),
               docStr.hasPrefix("http://") || docStr.hasPrefix("https://") {
                return docStr
            }

            let role = stringAttribute(element, attribute: kAXRoleAttribute) ?? ""
            if role == (kAXApplicationRole as String) {
                break
            }

            current = copyElementAttribute(element, attribute: kAXParentAttribute)
            depth += 1
        }

        return nil
    }

    private func copyElementAttribute(_ element: AXUIElement, attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard err == .success, let unwrapped = value else { return nil }
        guard CFGetTypeID(unwrapped) == AXUIElementGetTypeID() else { return nil }
        return (unwrapped as! AXUIElement)
    }

    private func rawAttribute(_ element: AXUIElement, attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard err == .success else { return nil }
        return value
    }

    private func stringAttribute(_ element: AXUIElement, attribute: String) -> String? {
        guard let val = rawAttribute(element, attribute: attribute) else { return nil }
        return val as? String
    }

    private func urlOrStringAttribute(_ element: AXUIElement, attribute: String) -> String? {
        guard let val = rawAttribute(element, attribute: attribute) else { return nil }
        if let str = val as? String {
            return str
        }
        if CFGetTypeID(val) == CFURLGetTypeID() {
            let cfURL = val as! CFURL
            return (cfURL as URL).absoluteString
        }
        return nil
    }

    private func boolAttribute(_ element: AXUIElement, attribute: String) -> Bool? {
        guard let val = rawAttribute(element, attribute: attribute) else { return nil }
        if CFGetTypeID(val) == CFBooleanGetTypeID() {
            return CFBooleanGetValue((val as! CFBoolean))
        }
        if let num = val as? NSNumber {
            return num.boolValue
        }
        return nil
    }
}
