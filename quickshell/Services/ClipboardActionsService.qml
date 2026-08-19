pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services
import "../Common/ClipboardContent.js" as ClipboardContent

Singleton {
    id: root
    readonly property var log: Log.scoped("ClipboardActionsService")

    readonly property var groups: ["url", "color", "path", "text"]

    // Placeholder name -> shell positional index. Values are passed as argv so
    // clipboard content is never spliced into the script text.
    readonly property var placeholders: ({
            "clipboard": 1,
            "clipboardContent": 1,
            "content": 1,
            "clip": 1,
            "path": 2,
            "ext": 3,
            "basename": 4,
            "dirname": 5,
            "type": 6,
            "color": 7
        })

    readonly property var operators: [
        {
            value: "any",
            label: I18n.tr("Anything")
        },
        {
            value: "includes",
            label: I18n.tr("Includes")
        },
        {
            value: "excludes",
            label: I18n.tr("Excludes")
        },
        {
            value: "exact",
            label: I18n.tr("Exactly")
        },
        {
            value: "notexact",
            label: I18n.tr("Not exactly")
        },
        {
            value: "startsWith",
            label: I18n.tr("Starts with")
        },
        {
            value: "endsWith",
            label: I18n.tr("Ends with")
        },
        {
            value: "regex",
            label: I18n.tr("Matches regex")
        },
        {
            value: "notRegex",
            label: I18n.tr("Does not match regex")
        }
    ]

    function describe(text) {
        return ClipboardContent.describe(text);
    }

    // Reads the live clipboard as text. Errors for image-only clipboards, which
    // callers surface as an empty state.
    function fetchCurrent(callback) {
        if (!ClipboardService.clipboardAvailable) {
            callback(null, I18n.tr("Clipboard service is not available"));
            return;
        }
        DMSService.sendRequest("clipboard.paste", null, function (response) {
            if (response.error) {
                callback(null, response.error);
                return;
            }
            const text = response.result?.text ?? "";
            if (!text.trim()) {
                callback(null, I18n.tr("Clipboard has no text content"));
                return;
            }
            callback(root.describe(text), "");
        });
    }

    function _conditionMatches(condition, subject) {
        const op = condition?.op || "includes";
        if (op === "any")
            return true;

        const raw = (condition?.value ?? "").toString();
        const caseSensitive = condition?.caseSensitive === true;

        if (op === "regex" || op === "notRegex") {
            if (!raw)
                return op === "notRegex";
            let re;
            try {
                re = new RegExp(raw, caseSensitive ? "" : "i");
            } catch (e) {
                log.warn("Invalid regex in clipboard action condition:", raw);
                return false;
            }
            const hit = re.test(subject);
            return op === "regex" ? hit : !hit;
        }

        if (!raw)
            return true;

        const needle = caseSensitive ? raw : raw.toLowerCase();
        const hay = caseSensitive ? subject : subject.toLowerCase();

        switch (op) {
        case "includes":
            return hay.includes(needle);
        case "excludes":
            return !hay.includes(needle);
        case "exact":
            return hay === needle;
        case "notexact":
            return hay !== needle;
        case "startsWith":
            return hay.startsWith(needle);
        case "endsWith":
            return hay.endsWith(needle);
        }
        return false;
    }

    function _extensionMatches(action, detail) {
        const raw = (action?.extensions ?? "").toString().trim();
        if (!raw)
            return true;
        const wanted = raw.split(",").map(e => e.trim().replace(/^\./, "").toLowerCase()).filter(e => e.length > 0);
        if (wanted.length === 0)
            return true;
        return wanted.includes(detail.ext);
    }

    function matches(action, detail) {
        if (!action || !detail)
            return false;
        if (action.enabled === false)
            return false;
        if ((action.group || "text") !== detail.type)
            return false;
        if (detail.type === "path" && !_extensionMatches(action, detail))
            return false;

        const conditions = action.conditions || [];
        for (let i = 0; i < conditions.length; i++) {
            if (!_conditionMatches(conditions[i], detail.text))
                return false;
        }
        return true;
    }

    function actionsFor(detail) {
        if (!detail)
            return [];
        const all = SettingsData.clipboardActions || [];
        const result = [];
        for (let i = 0; i < all.length; i++) {
            if (matches(all[i], detail))
                result.push(all[i]);
        }
        return result;
    }

    function _values(detail) {
        return ["dms-clipboard-action", detail.text, detail.path, detail.ext, detail.basename, detail.dirname, detail.type, detail.color];
    }

    function _substitute(command, replacer) {
        return (command || "").toString().replace(/\$\{([A-Za-z]+)\}/g, function (match, name) {
            const slot = root.placeholders[name];
            if (slot === undefined)
                return match;
            return replacer(slot);
        });
    }

    function shellEscape(str) {
        return "'" + (str ?? "").toString().replace(/'/g, "'\\''") + "'";
    }

    // ["sh", "-c", script, "dms-clipboard-action", <clipboard>, <path>, ...]
    function resolveCommand(action, detail) {
        if (!action || !detail)
            return null;
        const script = _substitute(action.command, slot => '"$' + slot + '"');
        if (!script.trim())
            return null;
        return ["sh", "-c", script].concat(_values(detail));
    }

    // Display only - never executed.
    function preview(action, detail) {
        if (!action || !detail)
            return "";
        const values = _values(detail);
        return _substitute(action.command, slot => root.shellEscape(values[slot]));
    }

    function run(action, detail) {
        const command = resolveCommand(action, detail);
        if (!command) {
            ToastService.showError(I18n.tr("Clipboard action has no command"));
            return false;
        }
        log.debug("Running clipboard action:", action.name || action.command);
        Quickshell.execDetached({
            command: command
        });
        ToastService.showInfo(I18n.tr("Running: %1").arg(actionLabel(action)));
        return true;
    }

    function actionLabel(action) {
        const name = (action?.name ?? "").toString().trim();
        if (name)
            return name;
        return (action?.command ?? "").toString().trim() || I18n.tr("Untitled action");
    }

    function groupLabel(group) {
        switch (group) {
        case "url":
            return I18n.tr("URL");
        case "color":
            return I18n.tr("Color");
        case "path":
            return I18n.tr("Path & File");
        default:
            return I18n.tr("Text");
        }
    }

    function groupIcon(group) {
        switch (group) {
        case "url":
            return "link";
        case "color":
            return "palette";
        case "path":
            return "folder";
        default:
            return "text_fields";
        }
    }
}
