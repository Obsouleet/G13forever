# Build guide: from zero to a running app

You don't need to know how to program. You need a Mac with macOS 14 or newer,
a G13, an internet connection, and some patience for the Xcode download.
**It costs nothing, and you don't need an Apple developer membership.**

Don't want to build? There is a [finished download](README.md#download). It needs
only step 6 of this guide.

The commands below go into the app **Terminal** (press `cmd+space`, type
`Terminal`, press Return). Copy one gray box at a time, paste it with `cmd+v`,
press Return, and wait until it's done before the next one.

## Step 1: Install Xcode

Install [Xcode from the App Store](https://apps.apple.com/app/xcode/id497799835).
It's free, but several gigabytes in size. If the App Store says it doesn't run
on your macOS, get an older version from
[Apple's download page](https://developer.apple.com/download/all/); a normal,
free Apple Account is enough to sign in there.

The "Command Line Tools" alone are **not** enough. The build would stop with
errors such as `cannot find '$selectedKey' in scope`.

## Step 2: Open Xcode once

Start Xcode, accept the license and wait until it has finished installing its
components. The iOS simulators it offers are not needed. Then quit Xcode.

Tell macOS to use this Xcode. It asks for your Mac password; nothing appears
while you type, that's normal:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Check that it worked:

```sh
xcode-select -p
```

It must print `/Applications/Xcode.app/Contents/Developer`.

## Step 3: Get the source code

```sh
cd ~
```

```sh
git clone https://github.com/Obsouleet/G13forever.git
```

You now have a folder `G13forever` in your home folder.

## Step 4: Build the app

```sh
cd ~/G13forever
```

```sh
scripts/build-app.sh
```

This takes from several seconds to a few minutes. It worked if it ends with:

```
Done: build/G13forever.app
Start it with: open build/G13forever.app
```

The app is signed "ad hoc" on the way, which is macOS speak for "built on this
Mac". That needs no certificate and no account. Because you built it yourself,
you should not get an "unidentified developer" warning.

## Step 5: Install and start

```sh
rm -rf /Applications/G13forever.app
```

```sh
cp -R build/G13forever.app /Applications/
```

```sh
open /Applications/G13forever.app
```

There is no window and no Dock icon. Look for the **keyboard icon in the menu
bar** at the top right. Plug in the G13. The first line of the menu should say
**G13 connected** within a few seconds.

## Step 6: Allow key presses

On first launch, macOS asks whether G13forever may control your computer. The
app needs this to send key presses. Until it's allowed, the display and the
colors work, but the keys do nothing.

1. Open **System Settings > Privacy & Security > Accessibility**.
2. Switch on **G13forever**. If it's not in the list, click **+** and choose it
   from Applications.
3. The menu entry **Allow Key Presses (Accessibility)…** disappears within a few
   seconds. If not, quit and restart the app.

**Input Monitoring** is in the same place. You only need it
if the app menu shows a message with that word.

Done! Choose **Edit Profiles…** in the menu and set up your keys.

## Updating

Quit the app (menu: **Quit G13forever**), then:

```sh
cd ~/G13forever
```

```sh
git pull
```

```sh
scripts/build-app.sh
```

Then repeat step 5. Your profiles are kept. **After every update you must allow
key presses again**, because macOS treats an ad-hoc signed app as a new one
after each build: in step 6, select the old G13forever entry, remove it with
**−**, and add the app again.

### Optional: keep the permission across updates

Sign with your own free certificate, and macOS recognizes the app again:

1. Run `open -a "Keychain Access"`. In its menu, choose **Keychain Access >
   Certificate Assistant > Create a Certificate…**.
2. Name: `G13forever Local`, identity type: **Self-Signed Root**, certificate
   type: **Code Signing**. Create it.
3. From now on, build with this command instead. If macOS asks for access to
   the key, enter your Mac password and choose **Always Allow**:

```sh
SIGN_IDENTITY="G13forever Local" scripts/build-app.sh
```

You allow key presses one more time after the first build with it.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| `git` or `swift`: "command not found", or macOS offers to install developer tools | Xcode is not set up yet. Repeat steps 1 and 2. |
| "You have not agreed to the Xcode license" | `sudo xcodebuild -license accept` |
| `cannot find '$selectedKey' in scope` or `no such module 'XCTest'` | macOS is using the Command Line Tools. Run the `xcode-select` command from step 2, then `rm -rf .build` and build again. |
| `no such file or directory: scripts/build-app.sh` | You're in the wrong folder: `cd ~/G13forever` |
| `permission denied: scripts/build-app.sh` | `bash scripts/build-app.sh` |
| The build fails in some other way | `rm -rf .build`, then build again. Still broken? Open an issue with your macOS and Xcode versions (`xcodebuild -version`) and the **first** line containing `error:`. |
| macOS says Apple can't check the app, or it can't be opened | Normal for the [download](README.md#download): use **Open Anyway** as described there. For an app you built yourself it happens if the source code came from a browser (ZIP) or another Mac: use `git clone` and build on this Mac. |
| macOS says the app is damaged | The ZIP didn't arrive intact, or a program changed the app. Download it again, and unpack it by double-clicking it in the Finder. |
| No icon in the menu bar | On MacBooks it can be hidden behind the notch; quit some other menu bar apps. Otherwise start it again with `open /Applications/G13forever.app`. |
| Menu says **G13 not found** | Check the cable, plug the G13 straight into the Mac instead of a hub, and quit other G13 software. `swift run g13ctl info` shows whether the G13 is seen. |
| Menu shows a message about **Input Monitoring** | Allow G13forever under **Privacy & Security > Input Monitoring**, then quit and restart the app. |
| Display works, but the keys do nothing | Permission missing or left over from an older build. Remove G13forever from the Accessibility list with **−** and add it again (step 6). If that doesn't help: quit the app, run `tccutil reset Accessibility io.github.obsouleet.g13forever`, start it, and allow it again. |
| Launch at login doesn't work | Use the app from the Applications folder (step 5), not `swift run`. |

## Uninstalling

Switch off **Launch at Login** in the menu, quit the app, then:

```sh
rm -rf /Applications/G13forever.app
```

Your profiles are in `~/Library/Application Support/G13forever`. Delete that
folder too if you no longer need them, and the `~/G13forever` source folder.
