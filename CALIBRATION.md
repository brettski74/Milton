# Calibration and Tuning

## Overview

All sensors require calibration. If you're using a commercially produced sensor, they are usually calibrated or at least validated by the manufacturer to perform within certain specifications, obviating the need for you to do your own calibration. For Milton, we will mostly be relying on custom RTDs to perform temperature measurements, so we will need to do our own calibration of these devices to ensure that we get accurate temperature measurements from our hotplate. Calibration is merely the practice of making one or more measurements from our sensor against accepted measurement standards and recording those measurements so that we can estimate the state of the system (ie. it's temperature in this case) based on measurements we record from our sensor at a later time. The main calibration that we will need to do is calibrating the RTD used to measure the hotplate temperature. This RTD is probably also your heating element on your hotplate.

Tuning is similar to calibration, but refers to the practice of observing the operation of the system and altering some of its operational parameters to make the system behave in a more desirable way.

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

Measuring temperature is a tricky thing. Temperature measurement devices don't measure the temperature of your hotplate.
They measure the temperature of their sensing element (probably a thermocouple hot junction, thermistor or RTD). To get good measurements, you need to ensure that you get that temperature sensing element to a temperature that is as close as possible to the temperature of the thing you want to measure - typically your hotplate. Where I mention that you should use **thermal compound**, I really mean you should use a commercial product specifically designed and marketed for use
as a thermal compound. If you are considering substituting a good, or even a cheap thermal compound with household
products like vegetable oil, lubricating grease, glue, wax, solder flux, solder paste, foams, powders or other materials
not specifically designed to be a thermal interface material, don't. Best case scenario, you'll end up with
significantly lower temperature readings than are really there - readings 20 celsius degrees or more lower are typical.
You'll end up calibrating your hotplate to run significantly hotter than it should and blow your thermal fuse on your
first reflow cycle. Some of those materials have additional bad side effects that you will want to avoid as well. For
example, solder flux is corrosive, especially when you heat it up.

Liquid metals are also likely a bad idea. These often contain gallium which does not play well with aluminium. So long as
you keep the aluminium oxide layer intact between them, nothin bad happens and gallium has much higher thermal
conductivity than non-metallic thermal grease, but the tiniest crack in that aluminium oxide coating and you expose the
virgin aluminium metal to the metallic gallium and they will quickly alloy together into a brittle, crumbly mess and
before you know it, your hotplate is no more. Mercury is another liquid metal that reacts badly with aluminium. Keep it away from anything aluminium.

Trust me, thermal compound is cheap and effective and really a necessity for any multi-point calibration process
described below that mentions it. Trying to get by without it is likely to end up in frustration, confusion, tears or
worse. **YOU HAVE BEEN WARNED!!!**

## Quick Start For Those Who Hate Reading

Most users building a hotplate similar to that described in my [Setup](resources/HotplateSetup.md) and [Assembly](resources/HotplateAssembly.md) probably only need to calibrate the hotplate resistance to temperature mapping. The existing tuning for temperature prediction and control should be good enough to
work for any similar assembly and most power supplies. Note that, even without calibration, so long as you start with the hotplate at room temperature and your default room temperature is close to real, your hotplate should do pretty well on temperature already - probably within +/-5°C, but this can be unreliable. If you start your hotplate while it's still warm, the automatic calibration will assume the starting temperature of your hotplate is room temperature, measure the temperature of the hotplate far lower than it really is and as a result, run the hotplate far too hot. Recording some calibration data in your configuration files will address that.

### Absolute Fastest 1-point Calibration

Make sure your hotplate is cold (ie. at room temperature). The best way to do this is to have it set up, plugged in and not touch it, breath on it or do anything to it for a while. Maybe go and take in your favourite movie about time-travelling cars or something. Have a thermometer in the room near tht hotplate this whole time as well. If you want to be really fancy, maybe even place the probe of your thermometer on the hotplate. We want that thermometer to also be at room temperature when we come back. After seeing your hero help his parents fall in love and make it back home, head back into your lab. Record room temperature as measured by your thermometer. Now run a comman - any command - on your hotplate. A good option would be constant power at a low power level for a short time - maybe 4 watts for 10 seconds. (From the command line this would be `psc power --duration 10 4`)

Look in the console output for a couple of lines that look like:

```
[8:36:50 p.m.] Auto-adding calibration point at T=27, R=5.83583583583584
[8:36:50 p.m.] Auto-adding calibration point at T=20, R=5.67959030650391
```

Ignore the second one that says T=20. That one is just extrapolated from the first point and the known properties of copper. The first one contains a real resistance measurement taken by your power supply connected to your hotplate at the current room temperature. Let's say your room temperature measurement was 25.6°C. At the shell prompt, run:

```
mledit controller/hotplate-resistance.yaml
```

For a new installation, the file will be blank. Put the data into the file like shown below and save it:

```
temperatures:
  - temperature: 25.6
    resistance: 5.83583583583584
```

Of course replace the 25.6 with the room temperature measurement you actually took and the 5.83583583583584 with the resistance measurement for that first line in the console output. Again , ignore the T=20 line. That's extrapolated data and will be inaccurate for calibration purposes.

This will give you as good of a temperature-resistance calibration as the actual hotplate calibration routine provided in the GUI.

### More Accurate 2-4 Point Calibration

This kind of calibration can produce much better accuracy in your temperature measurements, but it will take longer and require more manual effort on your part. Expect to spend up to a couple of hours doing this kind of calibration. You can strive for more or less precision by how many data points you decide to capture. 2 points is good. 4 points is probably better. More than 4 points is probably overkill and not worth the time investment.

For this kind of calibration, you'll want some kind of digital thermometer with a probe that can be thermally coupled reasonably well to the top-centre surface of your hotplate. A multimeter with a K-type thermocouple is an idea choice. Failing that, you could also use a fairly cheap, digital kitchen thermometer or you could build a temperature sensing rig using a commercial thermistor in a voltage divider and a prototyping board like an Arduino Nano or STM32 Blue Pill. I typically use my 121GW multimeter and a K-type thermocouple. I put a small blob of thermal compound in the centre of my hotplate, push the thermocouple hot junction down into it and tape it firmly to the hotplate with some kapton tape. I also typically use a goosneck clamp to hold the thermocouple cable to help ensure it doesn't come loose during calibration. If your temperature sensing device is integrated with Milton (eg. a 121GW thermometer), consider including that in your command as it makes the data capture easier and more accurate.

If you do a lot of temperature measurement, you start to realize that there is no such thing as "the temperature" of a system. Various parts of the system will be at different temperatures at different times depending on where the heat is coming from, where it's going and how it's flowing from place to place as the system goes through whatever process it's going through. In out hotplate, the temperature at the surface of the hotplate can be different form the temperature of the heating element, which may be different from the temperature of your hotplate load (the PCB to be reflow or heat sink to be tested or whatever). The resistance we measure for the heating element is telling us about the temperature of the heating element, but it's difficult to really measure the temperature of the heating element directly. The temperature we measure on the surface of the hotplate will often be different than that of the heating element. When we're actively heating the hotplate, the difference could be several celsius degrees. However, when the hotplate temperature is
held steady for a reasonable period of time, the temperature of the hotplate and the temperature of the heating element can become very close indeed. So the goal for this calibration will be to bring the hotplate to several different temperatures and attempt to keep the temperature steady for a few minutes while we record the resistance of the hotplate as measured by your power supply. The best way to do this is with the constant power command. In theory, you can also use the constant temperature command, but constant power tends to produce much steadier results which is more important than the speed advantage you can get with constant temperature. I recommand up to 4 runs, in the following order. If you're happy enough with the results, you can stop after 2 or 3 points if you don't want to spend the time for all four suggested calibration points.

1. 4W
1. 60W
1. 40W
1. 20W

This is for a hotplate that is 100x100mm. If your hotplate is larger or smaller than this, I would suggest scaling those values in proportion to the area of your hotplate versus mine.

We will run a constant power command for 900 seconds for each successive power level. (`psc power --duration 900 <power level>`) Look in the console output for lines that look like:

```
[9:14:48 p.m.] resistance: 5.88542371567465, temperature: 0, power: 5.948008, counts: [ 10, 0, 10 ]
[9:15:03 p.m.] resistance: 5.91385606020301, temperature: 0, power: 3.993948, counts: [ 10, 0, 10 ]
[9:15:18 p.m.] resistance: 5.94048177400063, temperature: 0, power: 3.992426, counts: [ 10, 0, 10 ]
```

If you're using an integrated calibration device, then the temperature values will be recorded automatically from your device and averaged to give you an oversampled temperature reading that corresponds with the resistance measurement. If you're lucky enough to have a supported device for this, that is the best way to do this and you can mostly just copy and paste the resistance and temperature readings into `controller/hotplate-resistanceyaml` directly. You'll only be copying one resistance-temperature pair per run and it should be one from near the end of your cycle when the temperature has been fairly steady for several minutes. Recording these early values while the hotplate is still heating up and far from its equilibrium temperature will lead to inaccuracies, so don't do that.

If you don't have an integrated temperature sensor, then you'll need to read the record off your thermometer and look for the resistance measurement that was produced at around the same time. Again, use a resistance and temperature measurement taken from near the end of the 15 minute cycle when the temperature has been fairly stable for several minutes. If you do this for all four points, you may end up with a controller/hotplate-resistance.yaml file that looks something like this:

```
temperatures:
  - resistance: 2.74416666666667
    temperature: 42.84
  - resistance: 3.26373943675687
    temperature: 95.93
  - resistance: 3.7671570992258
    temperature: 145.42
  - resistance: 4.16422212507384
    temperature: 181.54
```

## Tuning the Models

If you have a hotplate that is substantially different than the 100x100mm hotplate assembly that the default release was based on, you may need to tune the system for your hotplate. Maybe it's larger or smaller. Maybe it is mounted in a different way that alters airflow or other characteristics of the hotplate. Or maybe you're just not happy with the performance and accuracy of your hotplate and want to see if re-tuning the models can help it do better.

Tuning is highly recommended to be done via the web UI. It is technically possible to do from the command line, but the command can be a little more complicated and the web UI takes out some of the guesswork and just makes it easier to run. You will need an integrated temperature sensing device for this, such as an EEVBlog 121GW multimeter. We need to be able to accurately measure the hotplate temperature during the calibration cycle. This will vary from the heating element temperature by varying amounts through the calibration. It's not possible to measure this using the heating element resistance. In fact, the tuning is intentionally measuring the difference between these two temperatures in order to tune the models to better characterize how heat flows from your heating element into your hotplate during active heating and passive cooling of the hotplate. If you don't have an integrated temperature sensing device, you'll need to either acquire one or make do with whatever tuning you can obtain from others that maybe have something more similar to your setup.

The setup of your hotplate for the tuning is much the same as for calibration above. You want the probe of your temperature sensor firmly secured to the centre of the hotplate with a little thermal compound to ensure a good thermal coupling between the temperature probe and the hotplate surface. In the web UI, select the *Calibrate a new hotplate PCB* command. The reflow profile should automatically default to *calibration*, which is the profile you need to use. Select your calibration device (eg. 121gw). The command should also default the values for the name of the file where the RTD calibration data will be written and where the predictor tuning will be written as well. If either of these fields is set to blank, that part of teh calibration command is omitted. If you have already calibrated your resistance-temperature mapping using the process described above, then it is a good idea to blank the field for the RTD calibration data so that doesn't get overwritten. If you are happy to do a 1 point calibration only, you can leave the default value in there and this command will automatically do the 1-ponit calibration for you and write the results into the `controller/hotplate-resistance.yaml` file for you. If you forget to blank out the field and end up replacing your nice, 4-point calibration with a quick and dirty 1-point calibration from this command, don't fret! The previous version of the file will be backed up with a timestamp appended to the filename. You can manually go into $HOME/.config/milton/controller and restore the old file.

The calibration cycle takes about 15 minutes to run. You should see the temperature going up and down several times at different rates and different temperatures. Once it's complete, it will use all of the data collected to tune the models. This can take a while, depending on your hardware. On my lab PC that runs on a Celeron J6413 processor, the tuning doesn't take more than a minute or three, but if you're running on something slower like a Raspberry Pi 3B or an older Celeron or similar processor, expect it to take longer. The tuning does run several processes in parallel, so you can take advantage of extra cores if you have them in order to complete the tuning faster. The default configuration leaves this blank and tries to determine the number of floating point capable cores and creates a corresponding number of parallel processes, but if you want to set it explicitly, you can set by editing the tuning.parallel parameter using the following command:

```
mledit command/defaults.yaml
```
