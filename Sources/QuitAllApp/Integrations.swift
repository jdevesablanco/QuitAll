import AppKit
import ServiceManagement
import QuitAllCore

/// Todo lo que engancha la app con macOS: inicio de sesión y la acción «Cerrar todo» del menú Servicios.
enum Integrations {
    static var bundleID: String { Bundle.main.bundleIdentifier ?? Protection.selfBundleID }

    // MARK: Servicio «QuitAll: cerrar todo» (menú Servicios de cualquier app; se le puede poner atajo en Ajustes del Sistema)

    static var serviceTitle: String { tr("QuitAll: cerrar todo", "QuitAll: Quit all") }
    static var workflowURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Services/\(serviceTitle).workflow", isDirectory: true)
    }
    static var serviceInstalled: Bool {
        ["QuitAll: cerrar todo", "QuitAll: Quit all"].contains {
            FileManager.default.fileExists(atPath: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Services/\($0).workflow").path)
        }
    }

    static func installService() throws {
        removeService()
        let fm = FileManager.default
        let contents = workflowURL.appendingPathComponent("Contents", isDirectory: true)
        try fm.createDirectory(at: contents, withIntermediateDirectories: true)
        let info: [String: Any] = [
            "NSServices": [[
                "NSMenuItem": ["default": serviceTitle],
                "NSMessage": "runWorkflowAsService",
            ]]
        ]
        let script = "/usr/bin/open -g 'quitall://quit'"
        let action: [String: Any] = [
            "AMAccepts": ["Container": "List", "Optional": true, "Types": ["com.apple.cocoa.string"]],
            "AMActionVersion": "2.0.3",
            "AMApplication": ["Automator"],
            "AMParameterProperties": ["COMMAND_STRING": [:], "CheckedForUserDefaultShell": [:], "inputMethod": [:], "shell": [:], "source": [:]],
            "AMProvides": ["Container": "List", "Types": ["com.apple.cocoa.string"]],
            "ActionBundlePath": "/System/Library/Automator/Run Shell Script.action",
            "ActionName": "Run Shell Script",
            "ActionParameters": ["COMMAND_STRING": script, "CheckedForUserDefaultShell": true, "inputMethod": 0, "shell": "/bin/zsh", "source": ""],
            "BundleIdentifier": "com.apple.RunShellScript",
            "CFBundleVersion": "2.0.3",
            "CanShowSelectedItemsWhenRun": false,
            "CanShowWhenRun": true,
            "Category": ["AMCategoryUtilities"],
            "Class Name": "RunShellScriptAction",
            "InputUUID": UUID().uuidString,
            "Keywords": ["Shell", "Script", "Command", "Run", "Unix"],
            "OutputUUID": UUID().uuidString,
            "UUID": UUID().uuidString,
            "UnlocalizedApplications": ["Automator"],
            "arguments": [String: Any](),
            "isViewVisible": 1,
            "location": "309.000000:305.000000",
            "nibPath": "/System/Library/Automator/Run Shell Script.action/Contents/Resources/Base.lproj/main.nib",
        ]
        let wflow: [String: Any] = [
            "AMApplicationBuild": "523",
            "AMApplicationVersion": "2.10",
            "AMDocumentVersion": "2",
            "actions": [["action": action, "isViewVisible": 1]],
            "connectors": [String: Any](),
            "workflowMetaData": [
                "applicationBundleIDsByPath": [String: Any](),
                "applicationPaths": [String](),
                "inputTypeIdentifier": "com.apple.Automator.nothing",
                "outputTypeIdentifier": "com.apple.Automator.nothing",
                "presentationMode": 11,
                "processesInput": 0,
                "serviceInputTypeIdentifier": "com.apple.Automator.nothing",
                "serviceOutputTypeIdentifier": "com.apple.Automator.nothing",
                "serviceProcessesInput": 0,
                "systemImageName": "NSActionTemplate",
                "useAutomaticInputType": 0,
                "workflowTypeIdentifier": "com.apple.Automator.servicesMenu",
            ],
        ]
        try write(plist: info, to: contents.appendingPathComponent("Info.plist"))
        try write(plist: wflow, to: contents.appendingPathComponent("document.wflow"))
        enableService()
    }

    /// Las acciones nuevas llegan desactivadas: escribimos la misma entrada que crea el interruptor de Ajustes del Sistema.
    static func enableService() {
        let key = "(null) - \(serviceTitle) - runWorkflowAsService"
        let domain = "pbs" as CFString
        var all = (CFPreferencesCopyAppValue("NSServicesStatus" as CFString, domain) as? [String: Any]) ?? [:]
        all[key] = ["presentation_modes": ["ContextMenu": 1, "FinderPreview": 1, "ServicesMenu": 1, "TouchBar": 0]]
        CFPreferencesSetAppValue("NSServicesStatus" as CFString, all as CFDictionary, domain)
        CFPreferencesAppSynchronize(domain)
        refreshServices()
    }

    static func removeService() {
        for t in ["QuitAll: cerrar todo", "QuitAll: Quit all"] {
            try? FileManager.default.removeItem(at: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Services/\(t).workflow"))
        }
        refreshServices()
    }

    private static func write(plist: [String: Any], to url: URL) throws {
        let d = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try d.write(to: url)
    }

    static func refreshServices() {
        NSUpdateDynamicServices()
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/System/Library/CoreServices/pbs")
        p.arguments = ["-update"]
        try? p.run()
    }

    // MARK: inicio de sesión

    static func setLaunchAtLogin(_ on: Bool) -> String? {
        do {
            if on { if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() } }
            else { try SMAppService.mainApp.unregister() }
            return nil
        } catch { return error.localizedDescription }
    }
}
