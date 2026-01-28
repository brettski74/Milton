# Calibration and Tuning

## Overview

All sensors require calibration. If you're using a commercially produced sensor, they are usually calibrated or at
least validated by the manufacturer to perform within certain specifications, obviating the need for you to do your
own calibration. For Milton, we will mostly be relying on custom RTDs to perform temperature measurements, so we
will need to do our own calibration of these devices to ensure that we get accurate temperature measurements from
our hotplate. When it comes to calibration, there are two key concepts that you need to understand: *precision* and
*accuracy*. I won't bore you with defining these terms here. There are plenty of resources on the internet that
describe what these words mean in the context of science, physics and metrology. We assume that our power supply
and heating element are reasonably precise. Calibration involves taking some measurements in order to convert the
resistance measurements we can get from them into reasonably accurate measurements of the temperature of the
hotplate.

Tuning is similar to calibration, but refers to the practice of observing the operation of the system and altering
some of its operational parameters to make the system behave in a more desirable way. In our case, *desirable*
generally refers to having the system respond sufficiently quickly to changes in set-point or load while minimizing
offset errors and oscillations. In reality, there is usually some amount of trade-off between those behaviours so a
good tuning algorithm tries to strike a balance between fast response time and avoiding overshoot and oscillation.

## Keep It Simple, Stupid!

Good calibration improves the accuracy of your instruments and generally speaking, more accuracy is usually good.
However, bad calibration can make your instruments less accurate and cause serious problems. If your hotplate is
working well, you don't need to calibrate. If you don't **NEED** to calibrate, don't. If you plan to do any
calibration of your hotplate:

1. Make sure you have a good reason to calibrate or re-calibrate - such as:
1.1. A newly built hotplate PCB.
1.1. A newly rebuilt or repaired hotplate PCB.
1.1. The hotplate you are using appears to be inaccurate.
1. Make sure your calibration process is good.

Measuring temperature is a tricky thing. Good calibration relies on getting good measurements of the heating element
temperature. This is not going to be the same as the temperature of your calibration sensor unless you carefully
control the environment in which those measurements are made. For the most practical methods of measuring the
temperature of your hotplate, the measurement from your calibration sensor will be lower than the heating element
temperature. If you're not willing to invest in some thermal compound, some reasonable means of securing the sensor
in contact with the hotplate and being very careful to eliminate all drafts in the room (this includes avoiding fast
movements) it's probably best that you stick with the 1-point calibration. Without careful attention to detail and
control of the calibration environment, your measurements can be off by a surprising amount.

Don't think you can save a few bucks and substitute something else for a proper thermal interface compound. This is
the same goop that you buy to put between a CPU and a CPU cooler. Products like vegetable oil, lubricating grease,
glue, wax, solder flux, solder paste, foams, powders or anything else not specifically designed for use as a thermal
interface compound will make a significant difference. Offset errors as large as 20°C or more are likely. Even a
cheap thermal interface compound will vastly outperform any of these and with appropriate setup should enable offset
errors as low as 2-3°C or better possible. A suggested minimal setup probably includes thermal compound, kapton tape
and one or more gooseneck clamps to hold the sensor and/or leads in place.

Liquid metals are also a bad idea here. While their thermal conductivity is almost certainly far superior to most
non-conductive thermal interface compounds, they do not mix well with aluminium. Small amounts of gallium or mercury
can quickly destroy aluminium metal if they manage to breach the oxide layer on the surface. It may only take a small
scratch on the surface of your hotplate and it's all over. This is not worth the risk.

## Quick Start For Those Who Hate Reading

Most users building a hotplate similar to that described in my [Setup](resources/HotplateSetup.md) and
[Assembly](resources/HotplateAssembly.md) probably only need to calibrate the hotplate resistance to temperature
mapping. The existing tuning for temperature prediction and control should be good enough to work for any similar
assembly and most power supplies. Just do the [Absolute Fastest 1-point Calibration](#absolute-fastest-1-point-calibration)
and move on with your life.

## Absolute Fastest 1-point Calibration

Make sure your hotplate is cold (ie. at room temperature). The best way to do this is to have it set
up, plugged in and not touch it, breath on it or do anything to it for a while. Maybe go and take in
your favourite movie about time-travelling cars or something. Have a thermometer (the reference
sensor)in the room near the hotplate this whole time as well - preferably with the sensor touching
the hotplate or as close as practical to touching the hotplate. The goal here is for the temperature
of both the hotplate and your reference sensor to be the same as the surrounding ambient air
temperature to within a very small margin of error. After seeing your hero help his parents fall in
love and make it back home, head back into your lab.

### Using the Web Interface

If you're using the web interface - which I highly recommend - select the *One-point calibration*
command.

If your reference sensor is integrated with Milton (eg. you have a supported multimeter with a serial
or bluetooth communications interface), you can simply select the appropriate calibration device
from the list in the calibration device field.

If you wish, you can take a reading from your thermometer and enter that value into the ambient
temperature field.

Alternatively, you can just be lazy and hit execute and you will be prompted to provide the ambient
temperature when it's needed in a few seconds or so.

### Using the Command-Line Interface

While all the options available in the web interface are also available here, to keep this process
simple, we'll just focus on one way to run this from the command line. Run the following command:

```
psc power 2 --duration 10 --onepointcal
```

Once it has connected to your power supply, it should prompt you to provide the ambient temperature.
Enter the temperature reading from your thermometer in celsius. You should see a few more lines of
output before the command shuts down the power supply output and exits.

### Finishing Up

It's a good idea to check the output to verify that it worked and the results make sense. In the
web interface, you can check this information in the console output pane. You should see three
lines similar to the following in your output:

```
Auto-adding calibration point at T=24.3, R=5.78578578578579 (name: ambient)
Auto-adding calibration point at T=20, R=5.68963661660183 (name: interpolated)
Writing one-point calibration data to /home/yourusername/.config/milton/controller/hotplate-resistance.yaml
```

The resistance values should be reasonably close to the expected cold resistance of your heating
element. If you're using one of my layouts, the expected value should be printed on the PCB. Note
that the resistance won't be exactly as specified, but will probably be within about +/-5% of the
expected value. If not, then verify that the hotplate was actually at room temperature and if so,
maybe check the resistance of the heating element using a multimeter.

Note that the calibration process does send some power into the hotplate in order to measure its
resistance. If for some reason you mess up the calibration, it is recommended to give the hotplate
time to cool. Without knowing your specific setup it's difficult to day how much error could be
introduced by redoing the calibration multiple times in short succession. It's important to get
the calibration right, so if in doubt, give the hotplate time to cool and equilibrate before retrying
the calibration.

### For Those Willing To Read A Little More...

Note that even with an uncalibrated hotplate, Milton will ***probably*** produce reasonably good results provided that you
start every time with the hotplate at ambient temperature. Don't let this lull you into a false sense of security and
thinking that calibration is only for paranoid losers who don't have anything better to do. Calibration is a hedge against
that one day somwhere in the future where you have multiple boards to reflow and you forget to let the hotplate completely
cool between jobs and so Milton starts out thinking that your hotplate is at 27°C when it's actually at 87°C and promptly
proceeds to overheat everything. If you have a thermal fuse on your board, this may just cause the annoyance of having to
rebuild your hotplate. If you don't have a thermal fuse, then the fallout could be worse - scorched board, damaged
components, irreparably damaged hotplate PCB, fire, homelessness, insurance adjusters and even awkward questions from your
local fire marshall! Taking a few minutes to calibrate your hotplate when it is new or newly rebuilt helps ensure we have a
reliable baseline resistance and temperature measurement so that when that day comes, Milton knows that the hotplate is
starting out warm and still measures the hotplate temperature accurately anyway.

## Want More Accuracy?

I used to have information here for a suggested process to create a multi-point calibration curve for your heating element's
double life as an RTD. Based on further experience with this process and the results that it can produce, I no longer
recommend this process. The results appear to be too variable and in general, lower than reality. After a few unintended
trips of thermal fuses on boards calibrated in this way, I've realized that the variability of metallurgy is almost
certainly lower than that of the makeshift measurements practices of a hobbyist. I strongly recommend sticking with the
simple, quick 1-point calibration and depending on the well known physics of copper to extrapolate out from there. This
has proven more reliable in my experience so far.

## Tuning the Models

If you have a hotplate that is substantially different than the 100x100mm hotplate assembly that the default release was
based on, you may need to tune the system for your hotplate. Maybe it's larger or smaller. Maybe it is mounted in a
different way that alters airflow or other characteristics of the hotplate. Or maybe you're just not happy with the
performance and accuracy of your hotplate and want to see if re-tuning the models can help it do better.

Tuning is highly recommended to be done via the web UI. It is technically possible to do from the command line, but the
command can be a little more complicated and the web UI takes out some of the guesswork and just makes it easier to run.
You will need an integrated temperature sensing device for this, such as an EEVBlog 121GW multimeter. We need to be able
to accurately measure the hotplate temperature during the calibration cycle. This will vary from the heating element
temperature by varying amounts through the calibration. It's not possible to measure this using the heating element
resistance. In fact, the tuning is intentionally measuring the difference between these two temperatures in order to
tune the models to better characterize how heat flows from your heating element into your hotplate and subsequently into
your load during active heating and passive cooling of the hotplate. If you don't have an integrated temperature sensing
device, you'll need to either acquire one or make do with whatever tuning you can obtain from others that maybe have
something more similar to your setup.

To setup for the calibration cycle you want to ensure that your reference temperature sensor is in excellent thermal
contact with the hotplate surface. The recommended setup would be using a K-type thermocouple secured in place on the
hotplate surface with some kapton tape, with a small amount of thermal interface compound to ensure good heat transfer
from the hotplate to the reference sensor and a gooseneck clamp to hold the thermocouple lead to further ensure that the
sensor does not move off the hotplate mid-cycle. There are likely other equally suitable setups. The main elements to
aim for are:

1. Some light pressure pressing the reference sensor's probe against the hotplate.
1. Some thermal interface compound to ensure efficient heat transfer
1. Protecting the sensor probe from drafts that may form as the hotplate heats up.
1. Protection from sensor movement across or off the hotplate.

In the web UI, select the *Calibrate a new hotplate PCB* command. The reflow profile should automatically default to
*calibration*. This is the profile you need to use. Select your calibration device (eg. 121gw). The command should also
default the values for the name of the file where the RTD calibration data will be written and where the predictor
tuning will be written as well. Note that the RTD calibration is effectively the same as the 1-point calibration
described above. If you are planning to run this tuning cyclem you can skip a separate one-point calibration and just
do it as part of this command. It should default to the current path to the configuration file where the RTD calibration
was loaded from. If you want to recalibrate the RTD, you should probably just leave it as the default value. If you
don't need/want to redo the RTD calibration, set that filename blank and no RTD calibration data will be written by this
command.

The predictor calibration is the primary output of this calibration cycle. This field should default to the current
configuration file path from which the current predictor calibration was loaded from. You should probably leave this
at the default value. You can set it to a different file name if you want to redo the calibration without making it
effective. You can even set it to nothing and that will disable the tuning calculations at the end of the calibration
cycle and prevent it from writing out new predictor calibration. However, this command is rather pointless without
doing this, so it's probably best to just leave it at the default value. Note that any previously existing predictor
calibration data will be backed up in a timestamped file prior to writing out the new calibration data.

Note that this command takes a while to run. Just running through the calibration profile alone takes almost 15
minutes. Once that's done, there is a lot of number crunching to do to find an optimal set of parameters based on
the data collected. How long this takes will depend on how powerful your computer is. For most modern x86 based CPUs,
it should be pretty quick. The optimization processing is written to take advantage of multiple processor cores and
should probably only take 10s of seconds to maybe a few minutes for slower Celeron/Atom or similar processors. If
running on a Raspberry Pi or similar low-power ARM based hardware, expect several minutes or more to complete the
optimization processing and write out the predictor calibration data. The default configuration does not specify how
many parallel processes to run for this processing. This allows Milton to attempt to detect the number of CPU cores
you have and start up that many processes to process the data in parallel. If this is not working well, you can
manually set the value in the command/defaults.yaml file under `tuning.parallel`. You can edit this from the command
line with the following command:

```
mledit command/defaults.yaml
```
