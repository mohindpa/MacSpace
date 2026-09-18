[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)


# MacSpace


Turn your iPad Pro into a keyboard, trackpad and remote control for your Mac.
You design the layout, the colours and the buttons; what you tap on the iPad
lands on the Mac as real keystrokes, cursor movement and clicks.

## Requirements

- A Mac with the Xcode Command Line Tools installed.
- An iPad using Safari, connected to the same trusted Wi-Fi or local network as the Mac.
- macOS Accessibility permission enabled for MacSpace.
- A network that allows devices on the LAN to reach one another; guest Wi-Fi and some VPNs can block the connection.


```
iPad (Safari / Home Screen app)  --Wi-Fi-->  Mac (Swift helper)  -->  real input events
        your custom layout                       plain HTTP + token, LAN only
```


MacSpace's keyboard, mouse, clipboard, and application-control traffic stays on your local network. The optional Buy Me a Coffee button loads from a third-party CDN. No MacSpace account or cloud service is required.


![MacSpace on an iPad](preview.png)


---




## Security and privacy


MacSpace is a local-network HTTP bridge. It can inject keyboard and mouse events, read and write the Mac clipboard, list running applications, and focus applications when requested. Use it only on a trusted network; do not expose port `8787` to the internet. The access token in the URL should be treated like a password.


See [SECURITY.md](SECURITY.md) and [PRIVACY.md](PRIVACY.md) for details.


## 1. Start it on the Mac


```bash
git clone https://github.com/mohindpa/MacSpace.git
cd MacSpace
./build.sh      # compile (one time, ~10s)
./run.sh        # start it, prints the URL for the iPad
```


`run.sh` prints something like:


```
Open in Safari on your iPad:  http://<your-mac-ip>:8787/?t=<token>
```


Stop it with `./stop.sh`.


> **Why run.sh stages a copy:** this project lives inside `Documents`, which macOS
> protects with TCC. An app launched by LaunchServices that touches `Documents`
> stops on a consent dialog, and MacSpace reads its token at startup — so it would
> hang before serving anything. `run.sh` therefore copies `web/` and the token into
> `~/Library/Application Support/MacSpace/` and runs from there. Edit the source
> here, then re-run `./run.sh` to publish the change.


## 2. One-time: let the Mac accept the input


macOS only lets an app type on your behalf if you allow it:


**System Settings → Privacy & Security → Accessibility → enable “MacSpace”**


`./grant-accessibility.sh` opens that exact pane for you. MacSpace already asks
for it on first launch; the checkmark stays off until you tick it.


You can always see the current state at `http://<mac-ip>:8787/health` (`"ax": true`
means typing will work), and the iPad shows a red banner if it is off.


## 3. Open it on the iPad


Type the URL from step 1 into Safari on the iPad, then:


**Share → Add to Home Screen** → it opens fullscreen like a real app, no Safari bars.


---


## Using it


| Action | How |
|---|---|
| Type a key | tap it — it types on press, like a real keyboard |
| **Hold a key** | hold any character, digit, space, ⏎, arrow or ⌫ → it **repeats** (420 ms delay, then ~18/s, like macOS). Holding ⌫ deletes continuously; holding ← walks the cursor |
| Sticky modifier | tap ⇧ ⌥ ⌃ ⌘ once → it lights up, applies to the next key |
