/* global Zotero, Services, ChromeUtils, Components, Cc, Ci, IOUtils, PathUtils, APP_SHUTDOWN */

var windows = new Map();
var trayProcess;
var ipcDirectory;
var timer;
var trayReady = false;
var stopped = false;
var polling = false;

function install() {}
function uninstall() {}

function restoreWindows(showAll = false) {
  for (let [win, state] of windows) {
    if (state.hidden || showAll) {
      win.docShell.treeOwner.QueryInterface(Ci.nsIBaseWindow).visibility = true;
      if (win.windowState === win.STATE_MINIMIZED) win.restore();
      win.focus();
      state.hidden = false;
    }
  }
}

function onMainWindowLoad({ window: win }) {
  if (!Zotero.isWin || stopped || windows.has(win)) return;

  let state = { hidden: false };
  state.onClose = event => {
    // Ignore close events from child dialogs and embedded content.
    if (event.target !== win && event.target !== win.document) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    if (trayReady && trayProcess.isRunning) {
      win.docShell.treeOwner.QueryInterface(Ci.nsIBaseWindow).visibility = false;
      state.hidden = true;
    }
    else {
      win.minimize();
    }
  };
  // Native title-bar close and script/menu window.close() use different events.
  win.addEventListener("close", state.onClose, true);
  win.addEventListener("DOMWindowClose", state.onClose, true);
  windows.set(win, state);
}

function onMainWindowUnload({ window: win }) {
  let state = windows.get(win);
  if (!state) return;
  win.removeEventListener("close", state.onClose, true);
  win.removeEventListener("DOMWindowClose", state.onClose, true);
  windows.delete(win);
}

async function startup({ rootURI }) {
  if (!Zotero.isWin) return;
  stopped = false;
  for (let win of Zotero.getMainWindows()) onMainWindowLoad({ window: win });

  try {
    ipcDirectory = PathUtils.join(PathUtils.tempDir,
      `zotero-close-to-tray-${Services.appinfo.processID}-${Date.now()}`);
    await IOUtils.makeDirectory(ipcDirectory);
    let script = await Zotero.File.getResourceAsync(rootURI + "tray.ps1");
    if (stopped) {
      await IOUtils.remove(ipcDirectory, { recursive: true });
      return;
    }
    let scriptPath = PathUtils.join(ipcDirectory, "tray.ps1");
    // Windows PowerShell 5.1 requires a BOM for UTF-8 Chinese text.
    await IOUtils.writeUTF8(scriptPath, "\uFEFF" + script);
    let { NetUtil } = ChromeUtils.importESModule("resource://gre/modules/NetUtil.sys.mjs");
    let iconBytes = await new Promise((resolve, reject) => {
      NetUtil.asyncFetch({ uri: rootURI + "icons/icon.ico", loadUsingSystemPrincipal: true },
        (stream, status) => {
          if (!Components.isSuccessCode(status)) {
            reject(new Error("Unable to read tray icon: " + status));
            return;
          }
          let input = Cc["@mozilla.org/binaryinputstream;1"].createInstance(Ci.nsIBinaryInputStream);
          input.setInputStream(stream);
          resolve(new Uint8Array(input.readByteArray(input.available())));
        });
    });
    let iconPath = PathUtils.join(ipcDirectory, "icon.ico");
    await IOUtils.write(iconPath, iconBytes);
    if (stopped) {
      await IOUtils.remove(ipcDirectory, { recursive: true });
      return;
    }
    let executable = Cc["@mozilla.org/file/local;1"].createInstance(Ci.nsIFile);
    executable.initWithPath(PathUtils.join(
      Services.dirsvc.get("WinD", Ci.nsIFile).path,
      "System32", "WindowsPowerShell", "v1.0", "powershell.exe"));
    trayProcess = Cc["@mozilla.org/process/util;1"].createInstance(Ci.nsIProcess);
    trayProcess.init(executable);
    trayProcess.startHidden = true;
    let args = ["-NoProfile", "-NonInteractive", "-STA", "-WindowStyle", "Hidden",
      "-ExecutionPolicy", "Bypass", "-File", scriptPath,
      "-IpcDirectory", ipcDirectory,
      "-OwnerProcessId", String(Services.appinfo.processID),
      "-IconPath", iconPath];
    trayProcess.runwAsync(args, args.length, {
      async observe() {
        trayReady = false;
        if (timer) timer.cancel();
        if (!stopped) restoreWindows();
        await IOUtils.remove(ipcDirectory, { recursive: true, ignoreAbsent: true });
      }
    });

    timer = Cc["@mozilla.org/timer;1"].createInstance(Ci.nsITimer);
    timer.initWithCallback(async () => {
      if (polling || stopped) return;
      polling = true;
      try {
        let ready = await IOUtils.exists(PathUtils.join(ipcDirectory, "ready"));
        trayReady = !stopped && trayProcess.isRunning && ready;
        for (let action of ["restore", "quit"]) {
          let actionPath = PathUtils.join(ipcDirectory, action);
          if (!await IOUtils.exists(actionPath)) continue;
          await IOUtils.remove(actionPath);
          if (stopped) return;
          restoreWindows(true);
          if (action === "quit") Zotero.getMainWindows()[0]?.goQuitApplication({});
        }
      }
      catch (error) {
        trayReady = false;
        restoreWindows();
        Zotero.logError(error);
      }
      finally {
        polling = false;
      }
    }, 250, Ci.nsITimer.TYPE_REPEATING_SLACK);
  }
  catch (error) {
    Zotero.logError(error);
    if (ipcDirectory && !trayProcess?.isRunning) {
      await IOUtils.remove(ipcDirectory, { recursive: true, ignoreAbsent: true });
    }
  }
}

async function shutdown(data, reason) {
  stopped = true;
  trayReady = false;
  if (timer) timer.cancel();
  if (reason !== APP_SHUTDOWN) restoreWindows();
  for (let win of [...windows.keys()]) onMainWindowUnload({ window: win });
  if (trayProcess?.isRunning) {
    await IOUtils.writeUTF8(PathUtils.join(ipcDirectory, "stop"), "");
  }
}
