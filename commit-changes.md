#{id} clipboard: add user-defined clipboard actions with a runner popup

- Classify clipboard text as url/color/path/text in new Common/ClipboardContent.js
- Store per-group actions (filters + command) in settings under clipboardActions
- Add ClipboardActionsService to match actions and run them with argv-passed placeholders
- Add ClipboardActionsModal, a runner popup listing only the actions matching the current clipboard
- Expose the popup via `dms ipc call clipboard-actions open|close|toggle` and three new keybind actions
- Add a Clipboard Actions settings tab with URL, Color, Path & File and Text groups
