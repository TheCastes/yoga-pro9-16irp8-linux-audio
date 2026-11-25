# Linux audio on Lenovo Yoga Pro 9 16IRP8

Fixes and tuning for the built-in speakers of the **Lenovo Yoga Pro 9 16IRP8** Laptop
(`83BY`) on Linux.

| | |
|---|---|
| Codec | Realtek ALC287, codec subsystem `17aa:387e`, PCI subsystem `17aa:3835` |
| Speakers | 2 tweeters + 2 woofers, the woofers driven by 4 TI TAS2781 smart amplifiers over I2C |
| Amplifier firmware | `TAS2XXX387E.bin` + `TIAS2781RCA4.bin` (linux-firmware) |

This repo hosts two components:

1. **[Bass speakers](#fix)**: the fix. Without it the woofers
   play nothing or almost nothing.
2. **[Dolby tuning](#dolby-tuning-optional)** (optional): Lenovo's Windows
   speaker tuning, converted to an EasyEffects preset.

Using Linux on this Laptop since 2023, I found that most of the time only the tweeters play, with no low end, and I wanted to find why. 

I found that, even though the kernel binds the TAS2781 amplifiers and loads their firmware without errors, the amplifiers' DSP program is not applied on playback, for this reason turning on the ALSA control `Speaker Force Firmware Load` brings the woofers back at once.

### Fix

```sh
./bass/install.sh
```

This installs a systemd user service that turns the control on at login
(no root needed). The value survives suspend and resume. To check it:

```sh
amixer -c sofhdadsp cget "iface=CARD,name=Speaker Force Firmware Load"
```

To remove it: `./bass/install.sh --uninstall`.

### Dolby tuning (optional)

On Windows, Lenovo ships a Dolby Atmos speaker tuning made for this exact
model. [speaker-tuning-to-easyeffects](https://github.com/antoinecellerier/speaker-tuning-to-easyeffects)
converts it into EasyEffects presets.

### Requirements

The bass fix only needs `alsa-utils` and systemd. The Dolby part needs
**EasyEffects 8**.

#### Arch Linux

```sh
sudo pacman -S --needed easyeffects lsp-plugins-lv2 python-numpy python-scipy innoextract git curl alsa-utils
```

#### Fedora 44 or newer

```sh
sudo dnf install easyeffects lsp-plugins-lv2 python3-numpy python3-scipy innoextract git curl alsa-utils
```

#### Debian 14 (testing) or newer, Ubuntu 26.04 or newer

```sh
sudo apt install easyeffects lsp-plugins-lv2 python3-numpy python3-scipy innoextract git curl alsa-utils
```


### Install

```sh
./dolby/install.sh
```

### Use

```sh
easyeffects                              # open the window: effects, presets, bypass
easyeffects -b 1                         # Dolby off
easyeffects -b 2                         # Dolby on
easyeffects -l Dolby-Dynamic-Detailed    # load another preset
```

### Remove

```sh
./dolby/install.sh --uninstall
```

This stops and removes the EasyEffects service, moving the generated presets
to the trash.

## Credits

- [speaker-tuning-to-easyeffects](https://github.com/antoinecellerier/speaker-tuning-to-easyeffects)
  by Antoine Cellerier (MIT), which does the actual conversion.
- [innoextract](https://constexpr.org/innoextract/), to unpack the Lenovo
  installer.
