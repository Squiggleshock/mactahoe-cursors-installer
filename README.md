# macOS Tahoe cursors for Windows 11

This project includes all 17 cursors from the macOS Tahoe pack, including the Busy and Working in Background animations. The installer runs offline using Windows PowerShell 5.1, which ships with Windows. It is designed for x64 and Arm64 Windows 11 and installs for the signed-in account without administrator access. Windows in S mode and managed PCs that block scripts may require manual setup.

## Install and restore

1. Extract the entire ZIP to a folder of your choice.
2. In the extracted folder, double-click **Install.cmd** from the account that will use the cursors.
3. To return to the previous scheme, double-click **Restore.cmd**. It restores the original settings and removes the sign-in shortcut. The cursor files remain in `%LOCALAPPDATA%\TahoeCursors`.

The project can be moved to another folder or PC. After installation, Windows uses the copy in `%LOCALAPPDATA%\TahoeCursors`. Keep the ZIP if you want to reinstall later or need the restore launcher again.

## Reboots and Windows updates

**macOS Tahoe (Custom Cursors)** appears under **Mouse Properties > Pointers**. At sign-in, the **Restore Tahoe cursor scheme** Startup shortcut checks the active and saved scheme, then repairs settings Windows has reset. Running **Install.cmd** again also repairs the installation and keeps the original backup for **Restore.cmd**.

If the scheme stops sticking, open `shell:startup` from the Run dialog and check for **Restore Tahoe cursor scheme**. Check `%LOCALAPPDATA%\TahoeCursors\sign-in-error.txt` if present. Rerun **Install.cmd** if the shortcut or installed files are missing.

## Manual setup if scripts are blocked

Move the bundled `cursors` folder to a permanent location in your profile. In **Mouse Properties > Pointers**, select a pointer role and click **Browse** to assign its file. After assigning the roles, click **Save As** to name the scheme, then click **Apply**. Manual setup relies on Windows to retain the saved scheme and skips the sign-in repair.

| Pointer role | File |
| --- | --- |
| Normal Select | `arrow.cur` |
| Help Select | `help.cur` |
| Working in Background | `wait.ani` |
| Busy | `busy.ani` |
| Precision Select | `cross.cur` |
| Text Select | `beam.cur` |
| Handwriting | `pen.cur` |
| Unavailable | `no.cur` |
| Vertical Resize | `vsize.cur` |
| Horizontal Resize | `hsize.cur` |
| Diagonal Resize 1 | `dsize1.cur` |
| Diagonal Resize 2 | `dsize2.cur` |
| Move | `move.cur` |
| Alternate Select | `up.cur` |
| Link Select | `link.cur` |
| Location Select | `location.cur` |
| Person Select | `person.cur` |

## Installer choice

The project uses a double-click launcher and a per-user Windows PowerShell installer. This keeps the original settings available for restore and installs the sign-in repair in the same account. Microsoft requires a signed catalog for the classic INF installation route on Arm64 and in S mode. An unsigned `install.inf` would therefore add another install path with narrower compatibility. [Microsoft SetupAPI documentation](https://learn.microsoft.com/en-us/windows/win32/api/setupapi/nf-setupapi-installhinfsectiona)

## Credits

KANO GAMING created the macOS Tahoe Cursor Set and released it to the public domain. The original credits and cursor mapping are included in `cursors\readme.txt` and `cursors\macos-tahoe.crs`.
