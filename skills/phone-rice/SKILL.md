---
name: phone-rice
description: Rice an Omarchy desktop and a linked Android phone (Hyprtile or Phosphor launcher) together. Use when the user asks for a new theme, colour scheme, palette or rice for Omarchy, Hyprland or their phone, or wants the phone to match the desktop. Needs the Phone Sync plugin on the bar and a paired phone.
---

# Rice the desktop and the phone together

Phone Sync keeps the Omarchy theme and the phone's theme in step, both ways.
So you never talk to the phone yourself. You write an Omarchy theme, switch to
it, and the plugin sends its colours to every paired phone. The phone builds
an exact copy called `omarchy-<name>`.

## 1. Check the link

Find the helper (where `omarchy plugin add` put it):

```
PS=$(find ~/.config ~/.local/share -path '*phonesync/bin/phonesync' 2>/dev/null | head -1)
python3 "$PS" peers
```

An empty list means no phone is paired. Tell the user to turn on link in the
launcher's link menu and pair from the phone icon on the bar, then stop. Do not
try to pair for them: pairing needs a six digit code checked on both screens.

## 2. Look before you design

- Current theme: `cat ~/.local/state/omarchy/current/theme.name`
- Its colours: `cat ~/.local/state/omarchy/current/theme/colors.toml`
- Built in themes: `ls ~/.local/share/omarchy/themes`
- User themes: `ls ~/.config/omarchy/themes`

If the user names an existing theme, just switch to it (step 4).

## 3. Write the theme

Make `~/.config/omarchy/themes/<name>/` with a lowercase name of letters,
digits and dashes. Copy a built in theme that is close to the goal first, so
every file Omarchy expects (neovim, btop, icons and so on) is there, then
rewrite its `colors.toml`. Every line is `key = "#rrggbb"`. These are the keys
the phone reads, so set all of them:

| key | used for |
| --- | --- |
| `background`, `foreground` | the base; the phone refuses a theme without them |
| `accent` | focus, cursor, highlights (falls back to `blue`) |
| `dark_background`, `darker_background`, `lighter_background` | panels, the wallpaper fade, surfaces |
| `dark_foreground`, `muted`, `selection` | dim text, inactive borders, selection |
| `bright_foreground` | the brightest text |
| `red`, `green`, `yellow`, `blue`, `magenta`, `cyan` | terminal colours 1 to 6 |
| `bright_red` ... `bright_cyan` | terminal colours 9 to 14 |
| `mode` | `"dark"` or `"light"`; a light theme also needs an empty `light.mode` file |
| `hyprland_active_border` | the window border, e.g. `"rgba(ff2a6dee) rgba(05d9e8ee) 45deg"`; two or more colours become the phone's gradient border |

Put a wallpaper in `backgrounds/`, e.g. `backgrounds/1-<name>.png`. Draw it at
3840x2160 or larger so it stays sharp on a 4K screen. The phone does not get
the image; it draws its own backdrop from the background colours and accent.

Keep text readable on both screens. Aim for 7:1 contrast between `foreground`
and `background`, and at least 4.5:1 for `dark_foreground` and `muted`. Check
it before you switch:

```
python3 -c 'import sys
def L(h):
    c=[int(h.lstrip("#")[i:i+2],16)/255 for i in (0,2,4)]
    c=[v/12.92 if v<=0.03928 else ((v+0.055)/1.055)**2.4 for v in c]
    return .2126*c[0]+.7152*c[1]+.0722*c[2]
a,b=sorted((L(sys.argv[1]),L(sys.argv[2])),reverse=True); print(round((a+.05)/(b+.05),2))' "#e0e0ff" "#0b0b1a"
```

## 4. Switch to it

```
omarchy-theme-set <name>
```

The plugin sees the change and sends the theme to the phone within a second
or two. To send it again, middle click the phone icon on the bar.

## 5. Check the result

- The bar widget shows a short note: "Sent <theme> to <phone>".
- On the phone, the theme is now `omarchy-<name>`.
- If nothing arrived, the widget says "No phone connected" on a middle click.
  Check that the phone is on the same wifi with link on. `python3 "$PS" peers`
  shows the address it last used.

## The other way round

When the user picks a theme on the phone, Omarchy follows by itself. A phone
theme with no Omarchy twin is written to `~/.config/omarchy/themes/<app>-<name>`
with a `phonesync.json` next to it. Do not edit those by hand, because the
next pick on the phone rewrites them. Copy one to a new name to make it yours.

## Rules

- Change only themes under `~/.config/omarchy/themes`. Never edit the built in
  ones under `~/.local/share/omarchy`; Omarchy updates replace them.
- Never touch `~/.config/zanolink`. It holds the pairing keys.
- Ask before you replace a theme the user already has.
