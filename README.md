# Phone Sync

An Omarchy shell plugin that keeps your phone's theme in step with your
desktop, both ways. It works with the Hyprtile and Phosphor launchers for
Android.

- Pick a theme in Omarchy and the phone follows, in the exact colours.
- Pick a theme on the phone and Omarchy follows. When Omarchy has a theme of
  the same name it uses that one; otherwise it writes a full Omarchy theme
  from the phone's colours, background included.
- When the two were apart, the newer pick wins once they meet again.

Nothing to install, no ports to open. The computer reaches out to the phone
over your wifi; the phone is found by itself through avahi, which Omarchy
already runs.

## Install

```
omarchy plugin add https://github.com/Zanoshky/omarchy-phonesync.git --enable
```

Then put "Phone Sync" on the bar from Setup > Plugins if it is not there yet.

## Pair a phone

1. On the phone, open the link menu in Hyprtile or Phosphor and turn link on.
2. Click the phone icon in the bar. The phone shows up under the computer's
   name; click it to pair.
3. Both screens show a six digit code. If they match, say pair on both.

If the phone does not show up (some networks block discovery), click
"Pair by address" and type the address the phone's link menu shows.

From then on the theme follows on its own. A middle click on the bar icon
sends the current theme to the phone right away.

## How it works

`bin/phonesync` is a small Python script (standard library only) that the
widget runs while it is on the bar. It holds one line open to each paired
phone and speaks the launchers' link protocol:

- Pairing is an X25519 key exchange with a commitment and a six digit code
  compared on both screens.
- Every theme message after that is signed with the pair key and a
  timestamp, so nobody else on the network can change your theme, and an
  old message cannot be played again.

Themes it writes for a phone live in `~/.config/omarchy/themes/<app>-<name>`
with a `phonesync.json` that says where they came from. The pairing keys are
in `~/.config/zanolink`, shared with the launchers' `zanolink.py` tool.

You can also use the script from a terminal:

```
bin/phonesync pair 192.168.1.20     pair with the phone at that address
bin/phonesync peers                 list paired phones
```

## Privacy

Everything stays on your local network. The plugin sends theme names and
colours to phones you paired, and nothing anywhere else.

## License

MIT
