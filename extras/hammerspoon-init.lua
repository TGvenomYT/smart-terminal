-- Smart Terminal — Hammerspoon Hotkeys
-- Add this to your ~/.hammerspoon/init.lua
--
-- Ctrl+Shift+E → OCR Explain (screenshot → OCR → AI explanation)
-- Ctrl+Shift+A → Ask (prompt for natural language → run command)

-- OCR Explain: screenshot selection → OCR → explain in notification
hs.hotkey.bind({"ctrl", "shift"}, "E", function()
    hs.alert.show("Select region to explain...")
    -- Small delay to let alert show
    hs.timer.doAfter(0.3, function()
        local task = hs.task.new("/bin/bash", function(exitCode, stdout, stderr)
            if exitCode == 0 and stdout and stdout ~= "" then
                hs.alert.show(stdout:sub(1, 500), 10)
            elseif stderr and stderr ~= "" then
                hs.alert.show("Error: " .. stderr:sub(1, 200), 5)
            end
        end, {"-c", os.getenv("HOME") .. "/.smart-terminal/bin/ocr-explain 2>/dev/null | head -20"})
        task:start()
    end)
end)

-- Ask: prompt for natural language command
hs.hotkey.bind({"ctrl", "shift"}, "A", function()
    local button, query = hs.dialog.textPrompt("Smart Terminal", "What do you want to do?", "", "Run", "Cancel")
    if button == "Run" and query and query ~= "" then
        local task = hs.task.new("/bin/bash", function(exitCode, stdout, stderr)
            if stdout and stdout ~= "" then
                hs.alert.show("→ " .. stdout:sub(1, 200), 5)
            end
        end, {"-c", "source " .. os.getenv("HOME") .. "/.smart-terminal/commands.zsh && _st_lookup_command '" .. query .. "'"})
        task:start()
    end
end)
