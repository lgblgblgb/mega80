# My own CP/M programs

Beware: some/all of them only works with MEGA/80 as it uses the special
MEGA65 gateway calls, to interact with the native code side of MEGA/80.

## SHUTDOWN.COM

After a confirmation question shuts down the system to get you at the
MEGA65 BASIC prompt without the need of RESETing the a computer.

## CPMVER.COM

Gives information about the CP/M system and MEGA/80.

## MEGASH.COM

The `MEGA65 SHELL`, or `MEGASH`.

This is the main show, allows interaction with the host system (aka the
MEGA65). It presents a command line interface (with `#` being the prompt).

CP/M uses its own file system, but `MEGASH` allows you to transfer files
from the SD card of MEGA65 to native CP/M world, with some other functionality,
like attaching/detatching CP/M disk images and such.
