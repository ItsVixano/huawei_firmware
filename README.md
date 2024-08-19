# huawei_firmware

A minimal fastboot package creator to update the base firmware of your Huawei devices.

> [!WARNING]
> I am not responsible if your device gets bricked by using this script. You have been warned!

## Requirements
- A device with `FBLOCK` unlocked.
- A valid `UPDATE.APP` (file or zip) from [`Huawei Firm Finder`](https://professorjtj.github.io/).

## Usage

```bash
# Example with STF 9.1.0.231 (zip)
$ ./huawei-firmware.sh --device STF --fw-base 9.1.0.231 --zip update_full_base.zip
# Example with STF 9.1.0.231 (file)
$ ./huawei-firmware.sh --device STF --fw-base 9.1.0.231 --update-app UPDATE.APP
```

## Todo
- Implement v(ab) support.

## Credits
- [`R0rt1z2/hisi-playground`](https://github.com/R0rt1z2/hisi-playground)
- [`Huawei Firm Finder`](https://professorjtj.github.io/)
