# Milton Resources

Here you'll find a collection of resources for setting up hotplates and other hardware to work with Milton.

## Safety

You'll probably see safety mentioned more than once in this repo. A reflow hotplate is a potentially
dangerous device that could cause serious burns or pose a fire hazard if not built, maintained and used
carefully. Commercial devices in many markets are required to go through extensive testing to ensure that
they are inherently safe and mitigate most of the common fire and burn hazards. I am not an expert. I'm
just a guy on the internet giving you my best opinions about how I think you can mitigate some of these
risks. Ultimately, if you choose to build a solder reflow hotplate using mine or anyone else's designs,
you understand that you are responsible for ensuring that the device that you build is safe and operated
safely. While I have included advice on how I think some of these risks can be mitigated, it is entirely
possible that you follow everything I say to perfection and you could still burn yourself, others or your
house.

### Thermal Fuse

The thermal fuse is a soldered link incorporated into the heating element circuit that must be in place
for the heating element to work. Pay close attention to the setup instructions that describe how to set
up the thermal fuse if you want it to work reliably. The type of solder used as well as the size and
geometry of the link and the pads on which it is mounted factor into how reliably it *trips* at the
expected temperature. Under normal use, this component should never make a difference, but in the event of
a thermal fault, it provides a last line of defence that will prevent the hotplate from continuing to heat
past a useful limit. If set up well, the link should drop at or below about 240°C. An incorrectly set up
thermal fuse link may stay connected well above 280°C or higher. There are some common household materials
that can ignite at these temperatures.

### Power Connections

The recommended method of connecting power to the board involves using solid copper wire and screw terminals
to securely clamp the wire in place. Solid copper wire is used for its rigidity. In the event of a thermal
fault, the hotplate could potentially get hot enough to reflow the power connection solder joints. If floppy,
flexible wires have been used, these wires may drop away from the board and fall... who knows where? The
intention of using solid copper wire is that they are bent into shape so the wires are under neglible stress
and the screw terminals hold them firmly in place so that if the power connections reflow, the power connection
wires stay put and don't inadvertently fall onto anything which might create a hazard or other problem.

You may get the idea that the power connections themselves could be used as a safety device and disconnect
power during a thermal fault, however, this is not recommended for at least the following reasons.

1. Copper doesn't make a good spring and even if you can create sufficient strain in the wires during setup
to make them spring away to a safe position if the joints reflow, copper does not retain that strain well
and it will relax over the kinds of temperatures that the power connections may be exposed to. After some
number of reflow cycles, that strain may be all but gone and then the wires won't move much or at all in a
subsequent thermal fault.
1. Materials that are good at being springs and are likely to retain that springiness as the hotplate goes
through many reflow cycles (eg. Phosphor Bronze) have other challenges such as poor electrical conductivity
and poor solderability due to surface oxidation that may make them difficult to form high quality joints
with the hotplate PCB.
1. Even with a good spring material like phosphor bronze and a good solution for the conductivity and
solderability problems, the spring may still relax over time due to thermal cycling, so if this was to
be your primary safety device, you'd need to do periodic maintenance to check the spring strain and make
sure it's still sufficient and still moves the power connections to a safe position after some period of
time or number of reflow cycles (eg. maybe once per year or 100 reflow cycles)

Note that none of the above should be taken as a recommendation or advice on how to do this. I don't
recommend it and wanted to share some of my thought process as to why. If you decide to try to design
something like this, I'd love to hear how you go but that's your mission, not mine.

## Hotplate Layouts

A collection of off-the-shelf hotplate PCB layouts that should work well with Milton. There should be an
option here that should work for many common power supply specifications. See the table below for which
layout is recommended for your particular power supply. These were all generated using [Emmett](https://github.com/brettski74/Emmett),
so if none of these suit your needs, you can use Emmett to help design a layout that does.

Ideally, you want your hotplate to have maximum power available near the peark reflow temperatures. This is
assumed to be around 220°C, which is the typical peak reflow temperature for standard tin-lead solders. Since
the resistance of the heating element increases with temperature, this means that we want to design to achieve
the desired power into your hotplate when the heating element is hot. This does mean that for many power supplies
you may find that you are current-constrained at low temperatures and cannot achieve the design power, but this
is usually not necessary at lower temperatures. Worst case, for a severely limited power supply (eg. a 30V 3A supply)
you may find that it cannot keep up with the initial preheat ramp but that it catches up during the soak stage.
There is also the *slow-power* reflow which lengthens the time for each stage to allow for more power limited
setups to still follow a reasonable profile and get good results.

### Track Thickness

A 1 ounce copper layer *should* be 35 microns thick, so the *standard* calculations use this value for estimating
the resistance of the finished PCB. In practice, some manufacturers seem to produce slightly higher resistance
than the physics would predict. There are various possible explanations for this, including thinner than expected
copper layer, narrower than expected traces, impurities in the deposited copper and potentially more. Remember
that the PCB manufacturers are in the business of making circuit boards, not large, flat resistors to any degree
of precision. We use the track thickness parameter in [Emmett](https://github.com/brettski74/Emmett) to adjust for
observed manufacturing variances, but these may change over time. Therefore, it is entirely possible that you may
order a PCB using a particular layout and when the boards arrive, the resistance of the heating elements on those
boards is significantly different than expected. If your power supply has a lot of headroom, then it's usually not
a big deal, but if you're working within some tight power constraints such as a 30V 3A supply, it may present a
problem with getting the expected performance.

I've used two different manufacturers for aluminium hotplate PCBs - JLCPCB and PCBWay. I'm not sponsored by either
of them, they're just the ones I've used because I'm cheap and so are they. JLCPCB boards seems to come back with
resistances that are more consistent with a 29 micron thick copper layer, so if you're planning to order from JLCPCB
use the layouts in teh 29um directory. PCBWay seems to be more consistent with a 35 micron copper layer, so use the
35um directory if you're ordering from PCBWay. For any other manufacturers, I'd suggest starting with the 35um
layouts and see what you get. Also let me know how they are and I can add details here for the benefit of others.

### Hotplate Layout Recommendations

|Power Supply Description|Max Voltage|Max Current|Max Power|Recommended Hot Resistance|Examples|
|---|---|---|---|---|---|
|30V 3A Bench Supply|30V|3A|90W|10Ω|RD DPS3003, ELV DPS5315, etc|
|USB-PD Supply|20V|5A|100W|4Ω|Includes FNIRSI DPS-150|
|30V 5A Bench Supply|30V|5A|150W|6Ω|RD DPS3005, many others|
|Higher Voltage Bench Supply|40+V|5A|150+W|10Ω|RD DPS5005, DPS5015, DPS5020, etc|

## Bending Jig

To build a reliable thermal fuse, you need to bend some 10AWG or 6mm² copper wire into a U shape with dimensions
to land on a couple of relatively small pads. I've designed a small jig that you can 3D print that allows you to
bend these accurately and repeatably. It includes a length gauge on the side so you can cut the exact length of
wire required and a hole and groove in the top that you can use for bending the two ends. Due to a small amount
of relaxation in the metal after bending, you may have to tweak it slightly with pliers once you're done, but
that's fairly straightforward to do after the jig has done most of the work. The jig is available both as an STL
file and as the original OpenSCAD source that I used to create it.
