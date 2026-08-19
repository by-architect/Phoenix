.pragma library

// Classification of clipboard text into the four action groups.
// Kept as a plain library so both ClipboardActionsService and the settings
// tab can use it without pulling in a singleton.

const GROUPS = ["url", "color", "path", "text"];

const PATH_RE = /^(\/|~\/|\.\.?\/)[^\n\r]*$/;
const HEX_RE = /^#([0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/;
const FUNC_COLOR_RE = /^(rgb|rgba|hsl|hsla)\(\s*[^()\n]*\)$/i;
const SCHEME_URL_RE = /^[a-zA-Z][a-zA-Z0-9+.\-]*:\/\/\S+$/;
const BARE_WWW_RE = /^www\.\S+\.\S+$/;
const MAIL_MAGNET_RE = /^(mailto|magnet):\S+$/i;

function decodeFileUri(uri) {
    var raw = uri.replace(/^file:\/\//, "");
    var hash = raw.indexOf("#");
    if (hash >= 0)
        raw = raw.substring(0, hash);
    try {
        return decodeURIComponent(raw);
    } catch (e) {
        return raw;
    }
}

function pathParts(path) {
    var slash = path.lastIndexOf("/");
    var basename = slash >= 0 ? path.substring(slash + 1) : path;
    var dirname = slash > 0 ? path.substring(0, slash) : (slash === 0 ? "/" : "");
    var dot = basename.lastIndexOf(".");
    var ext = (dot > 0 && dot < basename.length - 1) ? basename.substring(dot + 1).toLowerCase() : "";
    return {
        path: path,
        basename: basename,
        dirname: dirname,
        ext: ext
    };
}

function normalizeHex(value) {
    var hex = value.substring(1);
    if (hex.length === 3 || hex.length === 4) {
        var expanded = "";
        for (var i = 0; i < hex.length; i++)
            expanded += hex[i] + hex[i];
        hex = expanded;
    }
    return "#" + hex.toLowerCase();
}

function classify(text) {
    if (!text)
        return "text";

    if (/^file:\/\//i.test(text) || PATH_RE.test(text))
        return "path";

    if (HEX_RE.test(text) || FUNC_COLOR_RE.test(text))
        return "color";

    if (SCHEME_URL_RE.test(text) || BARE_WWW_RE.test(text) || MAIL_MAGNET_RE.test(text))
        return "url";

    return "text";
}

// Returns a descriptor used both for matching and for placeholder substitution.
function describe(raw) {
    var text = (raw || "").toString().trim();
    var detail = {
        type: classify(text),
        text: text,
        path: "",
        basename: "",
        dirname: "",
        ext: "",
        color: ""
    };

    if (detail.type === "path") {
        var path = /^file:\/\//i.test(text) ? decodeFileUri(text) : text;
        var parts = pathParts(path);
        detail.path = parts.path;
        detail.basename = parts.basename;
        detail.dirname = parts.dirname;
        detail.ext = parts.ext;
    } else if (detail.type === "color") {
        detail.color = HEX_RE.test(text) ? normalizeHex(text) : text;
    }

    return detail;
}
